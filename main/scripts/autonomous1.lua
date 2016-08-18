
-- debugging purposes only
local util = require("main/scripts/util")
local waypoint = require("main/scripts/waypoint")

local M = {}

-- All created vehicles are put in this table
-- That way, they can easily avoid each other
M.vehicles = {}

-- Creates an instance
function M.create(parameters)
	vehicle = {
	    id = parameters.id,
	    
		position = parameters.position,
		maxspeed = parameters.maxspeed,
		radius = parameters.radius,
		mass = 1,
		oneovermass = 1 / 1,
		
		-- internal variables
		speed = 0,
		velocity = vmath.vector3(0,0,0),
		direction = vmath.vector3(0,1,0),
		accumulated_force = vmath.vector3(0,0,0),
		
		waypoints = nil,
		waypointindex = 0,
		waypointindexprev = 0,
		
		curve_point = nil,
		curve_point2 = nil,
		
		num_segments_visited = 0,
		
		pause = false,
		trainer = 0,
		
		-- car properties
		max_force = 250, --125,
        max_speed = 250,
        min_speed = 50,
		
		trackradius = 3 * 32 * 0.5 - 10,
		targetlookaheaddist = 128,--24,
		curve_lookahead = 160
	}
	
	M.vehicles[vehicle.id] = vehicle
	return vehicle
end

function M.destroy(vehicle)
    table.remove(M.vehicles, vehicle.id)
end


local function check_understeer(position, direction, curve_pos1, curve_pos2)
	local diff1 = vmath.normalize(curve_pos1 - position)
	local diff2 = vmath.normalize(curve_pos2 - position)
	-- use the curve point 1 as the middle line
	local normal = vmath.vector3(-diff1.y, diff1.x, 0)
	local dot0 = vmath.dot(normal, direction)
	local dot2 = vmath.dot(normal, diff2)

	if util.sign(dot0) == util.sign(dot2) then
		return vmath.dot(direction, diff1)
	end
	return 1
end


function M.init(vehicle, waypoints, waypoint_index)
	vehicle.waypoints = waypoints
	vehicle.waypointindex = waypoint_index
	vehicle.waypointindexprev = waypoint.wrap_index(waypoints, waypoint_index-1)
	
	vehicle.curve_point = waypoint.get_curve_point(vehicle.position, vehicle.waypointindex, vehicle.waypoints, vehicle.curve_lookahead )
    vehicle.curve_point2 = waypoint.get_curve_point(vehicle.position, vehicle.waypointindex, vehicle.waypoints, vehicle.curve_lookahead * 2.0 )
end

function M.update(vehicle, dt)
    M.update_waypoint_index(vehicle)
	local valid_state = M.update_target(vehicle, dt)
	if vehicle.trainer == 1 then
		if not valid_state then
		   return false
		end
    end
    M.separate(vehicle)
    	
	if not vehicle.pause then
		local acceleration = vehicle.accumulated_force * vehicle.oneovermass
		
        vehicle.velocity = vehicle.velocity + acceleration * dt
        
        vehicle.speed = vmath.length(vehicle.velocity)
        if vehicle.speed > 0.001 then
            vehicle.direction = vehicle.velocity * (1 / vehicle.speed)
        end
        
        if vehicle.speed > vehicle.max_speed then
            vehicle.speed = vehicle.max_speed
            vehicle.velocity = vehicle.direction * vehicle.max_speed
        end
        
		vehicle.position = vehicle.position + vehicle.velocity * dt
	end
	vehicle.accumulated_force = vmath.vector3(0,0,0)
	
	return true
end

function M.add_force(vehicle, force)
	vehicle.accumulated_force = vehicle.accumulated_force + force
end


local function get_curviness(waypoints, index, distance)
	local pos = waypoints[index].pos
	local curve_point = get_curve_point(pos, index, waypoints, distance)
	local segment = vmath.normalize(pos - waypoints[waypoint.wrap_index(waypoints, index-1)].pos)
	local dir = curve_point - pos
	local normal = vmath.vector3(-segment.y, segment.x, 0)
	local dot = vmath.dot(segment, vmath.normalize(dir))

	if vmath.dot(normal, dir) >= 0 then
		return math.acos(dot)
	else
		return -math.acos(dot)
	end
end

function M.get_projected_position(vehicle)
    local wp1 = vehicle.waypoints[vehicle.waypointindexprev]
    local wp2 = vehicle.waypoints[vehicle.waypointindex]
    return util.project_point_to_line_segment(vehicle.position, wp1.pos, wp2.pos)
end


function get_projected_position(position, waypoints, waypointindex, waypointcount)
	local closest = 1000000
	local projected = nil

	for i = waypointindex, waypointindex+waypointcount do
		local index = waypoint.wrap_index(waypoints, i)
		local previndex = waypoint.wrap_index(waypoints, index-1)
		local projected_candidate = util.project_point_to_line_segment(position, waypoints[previndex].pos, waypoints[index].pos)
		local diff = position - projected_candidate
		local dist = vmath.length(diff)
		if dist < closest then
			projected = projected_candidate
			closest = dist
		end
	end
    return projected
end

function M.update_waypoint_index(vehicle)
    local closestdist = 100000
    local newindex = 0
    local newprevindex = 0
    
    for i = vehicle.waypointindex, vehicle.waypointindex+1 do
        local index = i
        if index > #vehicle.waypoints then
            index = 1
        end
        local previndex = waypoint.wrap_index(vehicle.waypoints, index-1)

        local projected = util.project_point_to_line_segment(vehicle.position, vehicle.waypoints[previndex].pos, vehicle.waypoints[index].pos)
        local distance_from_segment = vmath.length_sqr(projected - vehicle.position)
        
        if distance_from_segment < closestdist then
            closestdist = distance_from_segment 
            
            newindex = index
            newindexprev = previndex
        end
    end
    
    if vehicle.waypointindex ~= newindex then
        vehicle.num_segments_visited = vehicle.num_segments_visited + 1
    end
    
    vehicle.waypointindex = newindex
    vehicle.waypointindexprev = newindexprev
end


local function get_predicted_distance_scale(vehicle)

	local predicted_pos = vehicle.position + vehicle.direction * vehicle.targetlookaheaddist
	
	local predicted_distance = vmath.length( predicted_pos - vehicle.position )
	local curve_pos_prediction = waypoint.get_curve_point(vehicle.position, vehicle.waypointindex, vehicle.waypoints, predicted_distance )
	local prediction_pos_to_curve_pos = curve_pos_prediction - predicted_pos
	local predicted_distance_from_curve = vmath.length(prediction_pos_to_curve_pos)
	
	--msg.post("@render:", "draw_line", {start_point = predicted_pos, end_point = curve_pos_prediction, color = vmath.vector4(1,0,1,1)})

	local scale = predicted_distance_from_curve / vehicle.trackradius - 1
	return math.max(0, scale)
end

local function get_curve_dot_scale(vehicle)
	local v1 = vmath.normalize(vehicle.curve_point - vehicle.position)
	local v2 = vmath.normalize(vehicle.curve_point2 - vehicle.curve_point)
	local curve_dot = vmath.dot( vmath.normalize(vehicle.curve_point - vehicle.position), vmath.normalize(vehicle.curve_point2 - vehicle.curve_point) )
	curve_dot = util.scale(curve_dot, 0, 1, -1, 1)
	return curve_dot
end

local function get_vehicle_position_scale(vehicle)
    local projected_position = M.get_projected_position(vehicle)
    local distance_from_segment = vmath.length( projected_position - vehicle.position )
	local scale = distance_from_segment / vehicle.trackradius - 1
	return math.max(0, scale)
end


function M.update_target(vehicle, dt)	
	local speed_scale = vehicle.speed / vehicle.maxspeed
	local predicted_pos_scale = math.max(0, 5 - get_predicted_distance_scale(vehicle)) / 5
	local curve_scale = get_curve_dot_scale(vehicle)
	local lookahead_scale = speed_scale * predicted_pos_scale * curve_scale
    local lookahead_slide = 0.15 + 0.85 * math.min(1, lookahead_scale)
    
    local projected_position = M.get_projected_position(vehicle)
    
	vehicle.curve_point = waypoint.get_curve_point(projected_position, vehicle.waypointindex, vehicle.waypoints, vehicle.curve_lookahead * lookahead_slide )
    vehicle.curve_point2 = waypoint.get_curve_point(projected_position, vehicle.waypointindex, vehicle.waypoints, vehicle.curve_lookahead * 2.0 * lookahead_slide )

    local understeer_scale = check_understeer(vehicle.position, vehicle.direction, vehicle.curve_point, vehicle.curve_point2)
    --print("understeer_scale", understeer_scale)
    
	local distance_from_segment = vmath.length( projected_position - vehicle.position ) / vehicle.trackradius
	if vehicle.trainer == 1 then
	    if distance_from_segment > 1 then
	        return false
	    end
	end
    
    local sliding_curve_point = vehicle.curve_point2
	local sliding_curve_point_scale = (understeer_scale*understeer_scale*understeer_scale)
    sliding_curve_point = vehicle.curve_point2 + (vehicle.curve_point - vehicle.curve_point2) * (1 - sliding_curve_point_scale)
    vehicle.target = sliding_curve_point


    local desired = vehicle.target - vehicle.position
        
    local desired_length = vmath.length(desired)
    desired = desired * (1 / desired_length) * vehicle.maxspeed
    
    local steer = desired - vehicle.velocity
    local steerlen = vmath.length(steer)

    if steerlen > vehicle.max_force then
        steer = steer * (1 / steerlen) * vehicle.max_force
    end
    
    M.add_force(vehicle, steer)
    
    
    -- Adjust the speed to the recommended speed at each waypoint
    local wp = vehicle.waypoints[vehicle.waypointindex]
    local recommended_speed = wp.speed == 0 and vehicle.max_speed or wp.speed
    recommended_speed = math.max(vehicle.min_speed, recommended_speed)
    local velscale = ((recommended_speed - vehicle.min_speed) / (vehicle.max_speed - vehicle.min_speed))
    local targetradius = vehicle.trackradius * 2 * (1 + (1 - velscale))
util.draw_circle(wp.pos + wp.offset, targetradius, vmath.vector4(1,1,0,1))
    
    local diff = vehicle.waypoints[vehicle.waypointindex].pos - vehicle.position
    local distance = vmath.length(diff)
    local unit = 1
    local targetspeed = vehicle.max_speed
    if distance < targetradius then
        unit = distance / targetradius
        targetspeed = recommended_speed + math.max(0, vmath.length(vehicle.velocity) - recommended_speed) * unit
    end

    M.update_recommended_speed(vehicle, unit, targetspeed, dt)
	
	return true
end

function M.update_recommended_speed(vehicle, unit, targetspeed, dt)    
    if vehicle.speed < 0.01 then
        return
    end
    if vehicle.speed < targetspeed then
        return
    end
    if unit > 1 then
        return
    end

    local delta_speed = (vehicle.speed - targetspeed)
    local brake = -vehicle.mass * (delta_speed / dt) * (unit * unit)
    --print("brake", brake, unit)

    msg.post("@render:", "draw_line", {start_point = vehicle.position, end_point = vehicle.position + brake * vehicle.direction, color = vmath.vector4(1,0,0.5,1)})
    
    M.add_force(vehicle, brake * vehicle.direction)
end

function M.separate(vehicle)
    local radius = 80
    local total = vmath.vector3(0,0,0)
    for k, other in pairs(M.vehicles) do
        if k ~= vehicle.id then
            local diff = other.position - vehicle.position
            local dot = vmath.dot(diff, vehicle.direction)
            if dot > 0 then -- only consider vehicles in front of us

                local distance = vmath.length(diff)
                if distance > 0 and distance < radius then
                    local unit = distance / radius
                    local dir = diff * (-1 / distance) * (1 / (unit*unit))
                    total = total + dir
                end
            end
        end
    end
    
    M.add_force(vehicle, total)
    --msg.post("@render:", "draw_line", {start_point = vehicle.position, end_point = vehicle.position + total, color = vmath.vector4(0,1,0,1)})
end

function M.debug(vehicle)

	msg.post("@render:", "draw_line", {start_point = vehicle.position, end_point = vehicle.position + vehicle.accumulated_force, color = vmath.vector4(0,1,0,1)})
	

    msg.post("@render:", "draw_line", {start_point = vehicle.position, end_point = vehicle.target, color = vmath.vector4(0.5,0.5,0.5,1)})
    
	msg.post("@render:", "draw_line", {start_point = vehicle.position, end_point = vehicle.position + vehicle.velocity, color = vmath.vector4(1,1,1,1)})
	
	-- What segment is the car currently in?
	--msg.post("@render:", "draw_line", {start_point = vehicle.waypoints[vehicle.waypointindex].pos + vmath.vector3(2,2,0), end_point = vehicle.waypoints[vehicle.waypointindexprev].pos + vmath.vector3(-2,-2,0), color = vmath.vector4(0, 1,1,1)})
	
	msg.post("@render:", "draw_line", {start_point = vehicle.curve_point, end_point = vehicle.curve_point + vmath.vector3(7, 10, 0), color = vmath.vector4(1, 1,1,1)})
    msg.post("@render:", "draw_line", {start_point = vehicle.curve_point2, end_point = vehicle.curve_point2 + vmath.vector3(7, 10, 0), color = vmath.vector4(1, 1,1,1)})	
end



return M
