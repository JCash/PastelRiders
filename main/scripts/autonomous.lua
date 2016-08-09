
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
		
		waypoints = nil,
		waypointindex = 0,
		waypointindexprev = 0,
		
		
		curve_point = nil,
		
		pause = false,
		
		-- car properties
		maxforce = 100000,
		
		trackradius = 3 * 32 * 0.5 - 10,
		targetlookaheaddist = 128,--24,
		curve_lookahead = 160
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
	vehicle.waypointindexprev = get_previous_index(vehicle, waypoint_index)
	
	vehicle.curve_point = get_curve_point(vehicle.position, vehicle.waypointindex, vehicle.waypoints, vehicle.curve_lookahead )
    vehicle.curve_point2 = get_curve_point(vehicle.position, vehicle.waypointindex, vehicle.waypoints, vehicle.curve_lookahead * 2.0 )
end

function M.update(vehicle, dt)
    M.update_waypoint_index(vehicle)
	local valid_state = M.update_target(vehicle)
	if not valid_state then
	   return false
	end
	
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
	
	return true
end

function M.add_force(vehicle, force)
	vehicle.accumulated_force = vehicle.accumulated_force + force
end


local function get_curviness(waypoints, index, distance)
	local pos = waypoints[index].pos
	local curve_point = get_curve_point(pos, index, waypoints, distance)
	local segment = vmath.normalize(pos - waypoints[get_previous_index(waypoints, index)].pos)
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
    return util.project_point_to_line_segment(vehicle.position, vehicle.waypoints[vehicle.waypointindexprev].pos, vehicle.waypoints[vehicle.waypointindex].pos)
end


function get_projected_position(position, waypoints, waypointindex, waypointcount)
	local closest = 1000000
	local projected = nil

	for i = waypointindex, waypointindex+waypointcount do
		local index = i
        if index > #waypoints then
            index = 1
        end
		local previndex = get_previous_index(waypoints, index)
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
        local previndex = get_previous_index(vehicle.waypoints, index)

        local projected = util.project_point_to_line_segment(vehicle.position, vehicle.waypoints[previndex].pos, vehicle.waypoints[index].pos)
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

function M.find_apex(vehicle)
	local diff = vehicle.curve_point2 - vehicle.position
	local halfpoint = vehicle.position + diff * 0.5
	local projected_point = get_projected_position(halfpoint, vehicle.waypoints, vehicle.waypointindex, 4)
	local apex_normal = halfpoint - projected_point
	local length = vmath.length(apex_normal)
	local apex = nil
	if length > vehicle.trackradius then
		--apex = projected_point + apex_normal * (1 / length) * vehicle.trackradius
		apex = projected_point + apex_normal
		
		msg.post("@render:", "draw_line", {start_point = apex, end_point = projected_point, color = vmath.vector4(1,0,0,1)})
	else
		apex = projected_point + apex_normal
		
		msg.post("@render:", "draw_line", {start_point = apex, end_point = projected_point, color = vmath.vector4(0,1,0,1)})
	end

	msg.post("@render:", "draw_line", {start_point = projected_point, end_point = projected_point + vmath.vector3(10,7,0), color = vmath.vector4(1,1,0,1)})
	--msg.post("@render:", "draw_line", {start_point = apex, end_point = projected_point, color = vmath.vector4(0,1,0,1)})
	
	return apex, apex_normal
end

function M.update_target(vehicle)
	local speed = vmath.length(vehicle.velocity)
	
	local speed_scale = speed / vehicle.maxspeed
	local predicted_pos_scale = math.max(0, 5 - get_predicted_distance_scale(vehicle)) / 5
	local curve_scale = get_curve_dot_scale(vehicle)
	local lookahead_scale = speed_scale * predicted_pos_scale * curve_scale
    local lookahead_slide = 0.15 + 0.85 * math.min(1, lookahead_scale)
    
    local projected_position = M.get_projected_position(vehicle)
    
	vehicle.curve_point = get_curve_point(projected_position, vehicle.waypointindex, vehicle.waypoints, vehicle.curve_lookahead * lookahead_slide )
    vehicle.curve_point2 = get_curve_point(projected_position, vehicle.waypointindex, vehicle.waypoints, vehicle.curve_lookahead * 2.0 * lookahead_slide )

    local understeer_scale = check_understeer(vehicle.position, vehicle.direction, vehicle.curve_point, vehicle.curve_point2)
    --print("understeer_scale", understeer_scale)
    
	local distance_from_segment = vmath.length( projected_position - vehicle.position ) / vehicle.trackradius
    local sliding_curve_point = vehicle.curve_point2
    local distance_from_segment_scale = 1
    if distance_from_segment > 1 then
        distance_from_segment_scale = math.min(distance_from_segment, 1)
        return false
    end

	local sliding_curve_point_scale = distance_from_segment_scale * (understeer_scale*understeer_scale*understeer_scale)
	--print("sliding_curve_point_scale", sliding_curve_point_scale)
    sliding_curve_point = vehicle.curve_point2 + (vehicle.curve_point - vehicle.curve_point2) * (1 - sliding_curve_point_scale)
    
    local turn_radius = 200
    local waypoint_curviness1 = get_curviness(vehicle.waypoints, vehicle.waypointindexprev, turn_radius)
    local waypoint_curviness2 = get_curviness(vehicle.waypoints, vehicle.waypointindex, turn_radius)
    local waypoint_segment = vehicle.waypoints[vehicle.waypointindex].pos - vehicle.waypoints[vehicle.waypointindexprev].pos
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
    
    
    --local apex, apex_normal = M.find_apex(vehicle)
	
    -- the further outside of the track, take the offset inwards the center of the road
    local target_offset_scale = 1 - curve_scale
    --print("target_offset_scale", target_offset_scale)
    --vehicle.target = sliding_curve_point - waypoint_normal * target_offset_scale * vehicle.trackradius
    vehicle.target = sliding_curve_point -- - waypoint_normal * target_offset_scale * vehicle.trackradius

	local recommended_speed = vehicle.waypoints[vehicle.waypointindex].speed
	if recommended_speed ~= 0 and recommended_speed < speed then
		local amount = speed - recommended_speed
		local brake = vehicle.direction * -amount
		--print("brake", amount)
	
		msg.post("@render:", "draw_line", {start_point = vehicle.position, end_point = vehicle.position + brake, color = vmath.vector4(1,0,1,1)})
		M.add_force(vehicle, brake)
	end

	if false and speed > 0 and curve_scale > 0 then
		local brake = vehicle.velocity * -(1 - curve_scale*curve_scale*curve_scale * understeer_scale*understeer_scale*understeer_scale)
		
		msg.post("@render:", "draw_line", {start_point = vehicle.position, end_point = vehicle.position + brake, color = vmath.vector4(1,0,0,0.99)})
		
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
	
	return true
end

function M.debug(vehicle)

	msg.post("@render:", "draw_line", {start_point = vehicle.position, end_point = vehicle.position + vehicle.accumulated_force, color = vmath.vector4(0,1,0,1)})
	

    msg.post("@render:", "draw_line", {start_point = vehicle.position, end_point = vehicle.target, color = vmath.vector4(0.5,0.5,0.5,1)})
    
	msg.post("@render:", "draw_line", {start_point = vehicle.position, end_point = vehicle.position + vehicle.velocity, color = vmath.vector4(1,1,1,1)})
	
	msg.post("@render:", "draw_line", {start_point = vehicle.waypoints[vehicle.waypointindex].pos + vmath.vector3(2,2,0), end_point = vehicle.waypoints[vehicle.waypointindexprev].pos + vmath.vector3(-2,-2,0), color = vmath.vector4(0, 1,1,1)})
	
	msg.post("@render:", "draw_line", {start_point = vehicle.curve_point, end_point = vehicle.curve_point + vmath.vector3(7, 10, 0), color = vmath.vector4(1, 1,1,1)})
    msg.post("@render:", "draw_line", {start_point = vehicle.curve_point2, end_point = vehicle.curve_point2 + vmath.vector3(7, 10, 0), color = vmath.vector4(1, 1,1,1)})	
end



return M
