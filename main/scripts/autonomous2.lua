
-- debugging purposes only
local util = require("main/scripts/util")
local waypoint = require("main/scripts/waypoint")

local M = {}

-- Creates an instance
function M.create(parameters)
	return {
		position = parameters.position,
		maxspeed = parameters.maxspeed,
		radius = parameters.radius,
        mass = 1,
		oneovermass = 1 / 1,
		
		-- internal variables
		projected_position = parameters.position,
		
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
		
		-- car properties
		maxforce = 250,
		
		max_force = 125,
        max_speed = 250,
        min_speed = 50,
        current_max_speed = 250,
		
		trackradius = 3 * 32 * 0.5 - 10,
		targetlookaheaddist = 128,--24,
		curve_lookahead = 80
	}
end

local function get_previous_index(waypoints, index)
	local index = index - 1
	if index < 1 then
		index = #waypoints
	end
	return index
end

local function get_next_index(waypoints, index)
	local index = index + 1
	if index > #waypoints then
		index = 1
	end
	return index
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

-- gets a point on the path, given a distance, relative to the start position (which should be on the path)
local function get_curve_point(startposition, startindex, waypoints, distance)
    while distance > 0 do
        local segment = waypoints[startindex].pos + waypoints[startindex].offset - startposition
        --local segment = waypoints[startindex].pos - startposition
        local segmentlength = vmath.length(segment)
        
        if segmentlength > distance then
            segment = segment * (1 / segmentlength)
            return startposition + segment * distance
        end
        
        distance = distance - segmentlength
        startposition = waypoints[startindex].pos
        startindex = get_next_index(waypoints, startindex)
    end
    return startposition
end


function M.init(vehicle, waypoints, waypoint_index)
	vehicle.waypoints = waypoints
	vehicle.waypointindex = waypoint_index
	vehicle.waypointindexprev = waypoint.get_previous_index(vehicle.waypoints, waypoint_index)
	vehicle.num_segments_visited = 1
	
	vehicle.targetindex = waypoint_index
	vehicle.curve_point = waypoint.get_curve_point(vehicle.position, vehicle.waypointindex, vehicle.waypoints, vehicle.curve_lookahead )
end

function M.update(vehicle, dt)
    M.update_waypoint_index(vehicle)
    M.update_target_index(vehicle)
    --M.update_seek_target(vehicle)
    M.update_arrive_target(vehicle)
    	
	if not vehicle.pause then
	    if vmath.length(vehicle.accumulated_force) > vehicle.max_force then
	       --vehicle.accumulated_force = vmath.normalize(vehicle.accumulated_force) * vehicle.max_force
        end
        local acceleration = vehicle.accumulated_force * vehicle.oneovermass
		
		vehicle.velocity = vehicle.velocity + acceleration * dt
        if vmath.length(vehicle.velocity) > vehicle.max_speed then
           vehicle.velocity = vmath.normalize(vehicle.velocity) * vehicle.max_speed
        end
        
		vehicle.position = vehicle.position + vehicle.velocity * dt
		
		local length = vmath.length(vehicle.velocity)
        if length > 0.001 then
            vehicle.direction = vehicle.velocity * (1 / length)
        end
        
        vehicle.projected_position = waypoint.get_projected_position(vehicle.position, vehicle.waypoints, vehicle.waypointindexprev, 2)
	end
	vehicle.accumulated_force = vmath.vector3(0,0,0)
	
	local valid_state = M.check_state(vehicle)
    if not valid_state then
       return false
    end
	
	return true
end

function M.check_state(vehicle)
    local distance_from_segment = vmath.length( vehicle.projected_position - vehicle.position ) / vehicle.trackradius
    if distance_from_segment > 1 then
        return false
    end
    return true
end

function M.add_force(vehicle, force)
	vehicle.accumulated_force = vehicle.accumulated_force + force * vehicle.oneovermass
end


function M.update_seek_target(vehicle)
    vehicle.curve_point = waypoint.get_curve_point(vehicle.projected_position, vehicle.targetindex, vehicle.waypoints, vehicle.curve_lookahead )
    
    vehicle.target = vehicle.curve_point
    --local wp = vehicle.waypoints[vehicle.targetindex]
    --vehicle.target = wp.pos + wp.offset
    
    local acceleration = vmath.normalize(vehicle.target - vehicle.position) * vehicle.max_force
    M.add_force(vehicle, acceleration)
end

function M.update_arrive_target(vehicle)
    --vehicle.target = waypoint.get_curve_point(projected_position, vehicle.targetindex, vehicle.waypoints, vehicle.curve_lookahead )
    vehicle.target = waypoint.get_curve_point(vehicle.projected_position, vehicle.waypointindex, vehicle.waypoints, vehicle.curve_lookahead )
    --vehicle.target = vehicle.waypoints[vehicle.targetindex].pos + vehicle.waypoints[vehicle.targetindex].offset
    local diff = vmath.normalize(vehicle.target - vehicle.position)
    --local wp = vehicle.waypoints[vehicle.targetindex]
    
    local distance = vmath.length(diff)
    local wp = vehicle.waypoints[vehicle.waypointindex]
    
    local recommended_speed = wp.speed == 0 and vehicle.max_speed or wp.speed
    recommended_speed = math.max(vehicle.min_speed, recommended_speed)
    local velscale = ((recommended_speed - vehicle.min_speed) / (vehicle.max_speed - vehicle.min_speed))
    local targetradius = vehicle.trackradius * 2 * (1 + velscale)
    
    local distance = vmath.length( wp.pos + wp.offset - vehicle.position )
    
util.draw_circle(wp.pos + wp.offset, targetradius, vmath.vector4(1,1,0,1))

    --[[
    local curviness = math.deg(waypoint.get_curviness(vehicle.waypoints, vehicle.waypointindex, vehicle.curve_lookahead*1.5))
    local segment1 = waypoint.get_segment(vehicle.waypoints, vehicle.waypointindex-1, vehicle.waypointindex)
    local segment2 = waypoint.get_segment(vehicle.waypoints, vehicle.waypointindex, vehicle.waypointindex+1)
    local length1 = vmath.length(segment1)
    local length2 = vmath.length(segment2)
    local entering_curve = length2 < length1 and math.abs(curviness) > 45
    local exiting_curve = length2 > length1 and math.abs(curviness) > 45
    print("length1/length2", length1, length2)
    print("segment1", segment1)
    print("segment2", segment2)
    print("curviness", curviness)
    print("entering_curve", entering_curve)
    print("exiting_curve", exiting_curve)
    --]]

    
    local targetspeed = vehicle.max_speed
    local unit = 1
    if distance < targetradius then
        unit = distance / targetradius
        targetspeed = recommended_speed + math.max(0, vmath.length(vehicle.velocity) - recommended_speed) * unit
    end
    
    --print("distance/targetradius", distance, targetradius)
    --print("unit/targetspeed", unit, targetspeed)
    
    local dt = 1 / 60
    local targetvelocity = diff * targetspeed
    local desired = (targetvelocity - vehicle.velocity)
    
    --msg.post("@render:", "draw_line", {start_point = vehicle.position, end_point = vehicle.position + targetvelocity, color = vmath.vector4(0.5,1,0.5,1)})
    
    M.add_force(vehicle, desired)
    
    M.update_recommended_speed(vehicle, unit, targetspeed, dt)
end


function M.update_recommended_speed(vehicle, unit, targetspeed, dt)
    local speed = vmath.length(vehicle.velocity)
    
    --print("speed/targetspeed", speed, targetspeed)
    
    if speed < 0.01 then
        return
    end
    if speed < targetspeed then
        return
    end
        
    local dir = vehicle.velocity * (1 / speed)
    local delta_speed = (speed - targetspeed)
    local brake = -vehicle.mass * (delta_speed / dt) * unit
    --print("brake", brake)
    
    -- Brake distance: d = (1/2) m v^2 / F
    --local brake = -(vehicle.mass * speed*speed) / 2

    msg.post("@render:", "draw_line", {start_point = vehicle.position, end_point = vehicle.position + brake * dir, color = vmath.vector4(1,0,0.5,1)})
    
    M.add_force(vehicle, brake * dir)
end


function M.update_target_index(vehicle)
    local threshold_distance = 60
    
    if vehicle.targetindex < vehicle.waypointindex then
        vehicle.targetindex = vehicle.waypointindex
    end
    local nextwpindex = vehicle.targetindex
    
    for i = vehicle.targetindex, vehicle.targetindex+2 do
        local index = waypoint.wrap_index(vehicle.waypoints, i)
        
        
        local diff = vehicle.position - vehicle.waypoints[index].pos
        if vmath.length(diff) < threshold_distance then
            nextwpindex = waypoint.wrap_index(vehicle.waypoints, index + 1)
        end
    end
    
    if vehicle.targetindex ~= nextwpindex then
	    vehicle.targetindex = nextwpindex
    end
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
        local previndex = get_previous_index(vehicle.waypoints, index)

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


function M.debug(vehicle)

	msg.post("@render:", "draw_line", {start_point = vehicle.position, end_point = vehicle.position + vehicle.accumulated_force, color = vmath.vector4(0,1,0,1)})
	

    msg.post("@render:", "draw_line", {start_point = vehicle.position, end_point = vehicle.target, color = vmath.vector4(0.5,0.5,0.5,1)})
    
	msg.post("@render:", "draw_line", {start_point = vehicle.position, end_point = vehicle.position + vehicle.velocity, color = vmath.vector4(1,1,1,1)})
	
	msg.post("@render:", "draw_line", {start_point = vehicle.waypoints[vehicle.waypointindex].pos + vmath.vector3(2,2,0), end_point = vehicle.waypoints[vehicle.waypointindexprev].pos + vmath.vector3(-2,-2,0), color = vmath.vector4(0, 1,1,1)})
	
	msg.post("@render:", "draw_line", {start_point = vehicle.curve_point, end_point = vehicle.curve_point + vmath.vector3(7, 10, 0), color = vmath.vector4(1, 1,1,1)})
    --msg.post("@render:", "draw_line", {start_point = vehicle.curve_point2, end_point = vehicle.curve_point2 + vmath.vector3(7, 10, 0), color = vmath.vector4(1, 1,1,1)})	
end



return M
