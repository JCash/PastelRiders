
-- debugging purposes only
local util = require("main/scripts/util")

local M = {}

-- Creates an instance
function M.create(parameters)
	return {
		position = parameters.position,
		maxspeed = parameters.maxspeed,
		radius = parameters.radius,
		oneovermass = 1 / 1,
		
		-- internal variables
		velocity = vmath.vector3(0,0,0),
		direction = vmath.vector3(0,1,0),
		accumulated_force = vmath.vector3(0,0,0),
		maxforce = 100000,
		
		waypoints = nil,
		waypointindex = 0,
		
		trackradius = 3 * 32 * 0.5 - 10, --3 * 32 * 0.5,
		targetlookaheaddist = 128,--24,
		
		curve_point = nil,
		
		curve_lookahead = 128,
		
		pause = false
	}
end


function M.update(vehicle, dt)
    M.update_waypoint_index(vehicle)
	M.update_target(vehicle)
	
	if not vehicle.pause then
		local acceleration = vehicle.accumulated_force * vehicle.oneovermass
		vehicle.velocity = vehicle.velocity + acceleration * dt
		vehicle.position = vehicle.position + vehicle.velocity * dt
		
		local length = vmath.length(vehicle.velocity)
        if length > 0.001 then
            vehicle.direction = vehicle.velocity * (1 / length)
        end
	end
	vehicle.accumulated_force = vmath.vector3(0,0,0)
end

function M.add_force(vehicle, force)
	vehicle.accumulated_force = vehicle.accumulated_force + force
end

function M.set_waypoints(vehicle, waypoints, startindex)
	vehicle.waypoints = waypoints
	vehicle.waypointindex = startindex
	vehicle.waypointindexprev = vehicle.waypointindex - 1
	if vehicle.waypointindexprev < 1 then
		vehicle.waypointindexprev = #vehicle.waypoints
	end
	vehicle.waypoint = vehicle.waypoints[vehicle.waypointindex]
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

-- gets a point on the path, given a distance, relative to the start position (which should be on the path)
local function get_curve_point(startposition, startindex, waypoints, distance)
    while distance > 0 do
        local segment = waypoints[startindex] - startposition
        local segmentlength = vmath.length(segment)
        
        if segmentlength > distance then
            segment = segment * (1 / segmentlength)
            return startposition + segment * distance
        end
        
        distance = distance - segmentlength
        startposition = waypoints[startindex]
        startindex = get_next_index(waypoints, startindex)
    end
    return startposition
end

local function get_curviness(waypoints, index, distance)
	local pos = waypoints[index]
	local curve_point = get_curve_point(pos, index, waypoints, distance)
	local segment = vmath.normalize(pos - waypoints[get_previous_index(waypoints, index)])
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
    return util.project_point_to_line_segment(vehicle.position, vehicle.waypoints[vehicle.waypointindexprev], vehicle.waypoints[vehicle.waypointindex])
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

        local projected = util.project_point_to_line_segment(vehicle.position, vehicle.waypoints[previndex], vehicle.waypoints[index])
        local distance_from_segment = vmath.length_sqr(projected - vehicle.position)
        
        if distance_from_segment < closestdist then
            closestdist = distance_from_segment 
            
            newindex = index
            newindexprev = previndex
        end
    end
    
    vehicle.waypointindex = newindex
    vehicle.waypointindexprev = newindexprev
end

local function get_predicted_distance_scale(vehicle)

	local predicted_pos = vehicle.position + vehicle.direction * vehicle.targetlookaheaddist
	
	local predicted_distance = vmath.length( predicted_pos - vehicle.position )
	local curve_pos_prediction = get_curve_point(vehicle.position, vehicle.waypointindex, vehicle.waypoints, predicted_distance )
	local prediction_pos_to_curve_pos = curve_pos_prediction - predicted_pos
	local predicted_distance_from_curve = vmath.length(prediction_pos_to_curve_pos)
	
	--msg.post("@render:", "draw_line", {start_point = predicted_pos, end_point = curve_pos_prediction, color = vmath.vector4(1,0,1,1)})

	local scale = predicted_distance_from_curve / vehicle.trackradius - 1
	return math.max(0, scale)

--[[
	-- this happens frequently	
	if false and predicted_distance_from_curve > vehicle.trackradius then
		local scale = predicted_distance_from_curve / vehicle.trackradius - 1
		print("scale", scale)
		
		msg.post("@render:", "draw_line", {start_point = vehicle.target, end_point = vehicle.target + prediction_pos_to_curve_pos * scale, color = vmath.vector4(1,0,1,1)})
		
		vehicle.target = vehicle.target + prediction_pos_to_curve_pos * scale
		
		scale = math.min(1, scale)
		local brake = vehicle.velocity * -(1 - scale*scale*scale)
		
		-- fairly good to keep car on track
		--msg.post("@render:", "draw_line", {start_point = vehicle.position, end_point = vehicle.position + brake, color = vmath.vector4(1,0,0,1)})
		--M.add_force(vehicle, brake)
	end
--]]

end

function M.update_target(vehicle)
	local speed = vmath.length(vehicle.velocity)
	
	local speed_scale = speed / vehicle.maxspeed
	local predicted_pos_scale = 1 --math.min(3, 3 - get_predicted_distance_scale(vehicle)) / 3
	local lookahead_scale = speed_scale * predicted_pos_scale
	
    local lookahead_slide = 0.15 + 0.85 * math.min(1, lookahead_scale)
    
    local projected_position = M.get_projected_position(vehicle)
    
	vehicle.curve_point = get_curve_point(projected_position, vehicle.waypointindex, vehicle.waypoints, vehicle.curve_lookahead * lookahead_slide )
    vehicle.curve_point2 = get_curve_point(projected_position, vehicle.waypointindex, vehicle.waypoints, vehicle.curve_lookahead * 2.0 * lookahead_slide )
    
    local distance_from_segment = vmath.length( projected_position - vehicle.position ) / vehicle.trackradius
    
    local sliding_curve_point = vehicle.curve_point2
    if distance_from_segment > 1 then        
        local scale = math.min(distance_from_segment, 2) - 1
        sliding_curve_point = vehicle.curve_point2 + (vehicle.curve_point - vehicle.curve_point2) * scale
    end
    
    local turn_radius = 200
    local waypoint_curviness1 = get_curviness(vehicle.waypoints, vehicle.waypointindexprev, turn_radius)
    local waypoint_curviness2 = get_curviness(vehicle.waypoints, vehicle.waypointindex, turn_radius)
    local waypoint_segment = vehicle.waypoints[vehicle.waypointindex] - vehicle.waypoints[vehicle.waypointindexprev]
    local waypoint_segment_length = vmath.length(waypoint_segment)
    local waypoint_normal = waypoint_segment * (1 / waypoint_segment_length)
    waypoint_normal = vmath.vector3(-waypoint_normal.y, waypoint_normal.x, 0)
    
    local curviness_limit = math.pi
    --waypoint_curviness = util.scale(waypoint_curviness, -math.pi/4, math.pi/4, -1, 1)
    waypoint_curviness1 = util.clamp(-curviness_limit, curviness_limit, waypoint_curviness1) / curviness_limit
    waypoint_curviness2 = util.clamp(-curviness_limit, curviness_limit, waypoint_curviness2) / curviness_limit
    
	--print("waypoint_curviness1", waypoint_curviness1, math.deg(waypoint_curviness1))
	--print("waypoint_curviness2", waypoint_curviness2, math.deg(waypoint_curviness2))
	
    local target_offset = 1 - util.clamp(0, 1, (waypoint_segment_length / turn_radius)) * waypoint_curviness1
    --print("target_offset", target_offset)
    
	
    -- the further outside, take the offset inwards the center of the road
    --local target_offset_scale = math.max(1, distance_from_segment) / 1.5
    --print("target_offset_scale", target_offset_scale)
    vehicle.target = sliding_curve_point -- - waypoint_normal * target_offset * vehicle.trackradius

    
	local vel_curve_dot = 1
	if speed > 0 then
		local dir = vehicle.velocity * (1/speed)
		local curvepoint_dir = sliding_curve_point - vehicle.position
		local ccurvepoint_dirlength = vmath.length(curvepoint_dir)
		if ccurvepoint_dirlength > 0 then
			--print("dir", dir)
			--print("cpdir", cpdir)
			--print("vehicle.curve_point", vehicle.curve_point)
			--print("vehicle.position", vehicle.position)
			vel_curve_dot = vmath.dot(dir, curvepoint_dir * (1/ccurvepoint_dirlength))
			if vel_curve_dot < 0 then
				vel_curve_dot = 0
			end
		end
	end

	local v1 = vmath.normalize(vehicle.curve_point - vehicle.position)
	local v2 = vmath.normalize(vehicle.curve_point2 - vehicle.curve_point)
	local curve_dot = vmath.dot( vmath.normalize(vehicle.curve_point - vehicle.position), vmath.normalize(vehicle.curve_point2 - vehicle.curve_point) )
	curve_dot = util.scale(curve_dot, 0, 1, -1, 1)
	curve_dot = util.clamp(-1, 1, curve_dot)

	if speed > 0 and curve_dot > 0 then
		local brake = vehicle.velocity * -(1 - curve_dot*curve_dot*curve_dot)
		
		msg.post("@render:", "draw_line", {start_point = vehicle.position, end_point = vehicle.position + brake, color = vmath.vector4(1,0,0,1)})
		
		M.add_force(vehicle, brake)
	end


	local desired = vehicle.target - vehicle.position
		
	local desired_length = vmath.length(desired)
	desired = desired * (1 / desired_length) * vehicle.maxspeed
	
	local steer = desired - vehicle.velocity
	local len = vmath.length(steer)
	if len > vehicle.maxforce then
		steer = steer * (1 / len) * vehicle.maxforce
	end
	
	M.add_force(vehicle, steer)
end

function M.debug(vehicle)

	msg.post("@render:", "draw_line", {start_point = vehicle.position, end_point = vehicle.position + vehicle.accumulated_force, color = vmath.vector4(0,1,0,1)})
	

    msg.post("@render:", "draw_line", {start_point = vehicle.position, end_point = vehicle.target, color = vmath.vector4(0.5,0.5,0.5,1)})
    
	msg.post("@render:", "draw_line", {start_point = vehicle.position, end_point = vehicle.position + vehicle.velocity, color = vmath.vector4(1,1,1,1)})
	
	msg.post("@render:", "draw_line", {start_point = vehicle.waypoints[vehicle.waypointindex] + vmath.vector3(2,2,0), end_point = vehicle.waypoints[vehicle.waypointindexprev] + vmath.vector3(-2,-2,0), color = vmath.vector4(0, 1,1,1)})
	
	msg.post("@render:", "draw_line", {start_point = vehicle.curve_point, end_point = vehicle.curve_point + vmath.vector3(7, 10, 0), color = vmath.vector4(1, 1,1,1)})
    msg.post("@render:", "draw_line", {start_point = vehicle.curve_point2, end_point = vehicle.curve_point2 + vmath.vector3(7, 10, 0), color = vmath.vector4(1, 1,1,1)})	
end



return M
