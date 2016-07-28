
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
		accumulated_force = vmath.vector3(0,0,0),
		maxforce = 100000,
		
		waypoints = nil,
		waypointindex = 0,
		
		trackradius = 3 * 32 * 0.5 - 10, --3 * 32 * 0.5,
		targetlookaheaddist = 64,--24,
		
		curve_point = nil,
		
		curve_lookahead = 200,
		
		pause = false
	}
end


function M.update(vehicle, dt)
	M.update_target(vehicle)
	
	msg.post("@render:", "draw_line", {start_point = vehicle.position, end_point = vehicle.position + vehicle.accumulated_force, color = vmath.vector4(0,1,0,1)})
	
	if not vehicle.pause then
		local acceleration = vehicle.accumulated_force * vehicle.oneovermass
		vehicle.velocity = vehicle.velocity + acceleration * dt
		vehicle.position = vehicle.position + vehicle.velocity * dt
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
    local wpindex = startindex
    local previousdir = waypoints[wpindex] - startposition
    local segmentlength = vmath.length(previousdir)
    
    curve_point = startposition
    
    -- if the distance is large enough
    if segmentlength > 0.001 then
        distance = distance - segmentlength
    else
        -- if we're too close, we need to use the segment as a dir
        local wpindexprev = get_previous_index(waypoints, wpindex)
        previousdir = waypoints[wpindex] - waypoints[wpindexprev]
        segmentlength = vmath.length(previousdir)
    end
    previousdir = previousdir * (1/segmentlength)
    startposition = waypoints[wpindex]
    
    local angle = 0
    while distance > 0 do
        wpindex = get_next_index(waypoints, wpindex)
        local segment = waypoints[wpindex] - startposition
        segmentlength = vmath.length(segment)
        segment = segment * (1/segmentlength)
        
        if (distance - segmentlength) < 0 then
            local pos = startposition + segment * distance
            curve_point = pos
        end
        
        distance = distance - segmentlength

        previousdir = segment
        startposition = waypoints[wpindex]
    end
    
    return curve_point
end 

local function get_curviness(vehicle, point_on_path, distance_ahead)
	local wpindex = vehicle.waypointindex
	local previousdir = vehicle.waypoints[wpindex] - point_on_path
	local segmentlength = vmath.length(previousdir)
	
	vehicle.curve_point = point_on_path
	--print("")
	--print("distance_ahead", distance_ahead)
	--print("segmentlength", segmentlength)
	
	-- if the distance is large enough
	if segmentlength > 0.001 then
		distance_ahead = distance_ahead - segmentlength
	else
		-- if we're too close, we need to use the segment as a dir
		local wpindexprev = get_previous_index(vehicle.waypoints, wpindex)
		previousdir = vehicle.waypoints[wpindex] - vehicle.waypoints[wpindexprev]
		segmentlength = vmath.length(previousdir)
	end
	previousdir = previousdir * (1/segmentlength)
	point_on_path = vehicle.waypoints[wpindex]
	
	--print("previousdir", previousdir)
	
	local angle = 0
	while distance_ahead > 0 do
		wpindex = get_next_index(vehicle.waypoints, wpindex)
		local segment = vehicle.waypoints[wpindex] - point_on_path
		segmentlength = vmath.length(segment)
		segment = segment * (1/segmentlength)
		
		if (distance_ahead - segmentlength) < 0 then
			local pos = point_on_path + segment * distance_ahead
			vehicle.curve_point = pos
		end
		
		distance_ahead = distance_ahead - segmentlength
		
		-- check what side of the direction the segment is on (left = normal, right = -normal)
		local normal = vmath.vector3(-previousdir.y, previousdir.x, 0)
		local sidedot = vmath.dot(normal, segment)
		if sidedot <= 0 then
			sidedot = -1
		else
			sidedot = 1
		end
		
		local segmentangle = math.acos( vmath.dot(segment, previousdir) ) * sidedot
		angle = angle + segmentangle

		previousdir = segment
		point_on_path = vehicle.waypoints[wpindex]
	end
	return angle
end

function M.update_target(vehicle)
	local speed = vmath.length(vehicle.velocity)
	local predicted_pos = vehicle.position
	if speed > 0 then
		 predicted_pos = predicted_pos + vehicle.velocity * (1/speed) * vehicle.targetlookaheaddist
	end
	
	local target = vehicle.target
	
	local pathsegment = nil
	local projected = nil
	local closestdist = 100000
	local newindex = 0
	local newprevindex = 0
	
	for i = vehicle.waypointindex, vehicle.waypointindex+1 do
		local index = i
		if index > #vehicle.waypoints then
			index = 1
		end
		local previndex = get_previous_index(vehicle.waypoints, index)

		local projected = util.project_point_to_line_segment(predicted_pos, vehicle.waypoints[previndex], vehicle.waypoints[index])
		local distance_from_segment = vmath.length(projected - predicted_pos)
		
--msg.post("@render:", "draw_line", {start_point = projected, end_point = projected+vmath.vector3(10,10,0), color = vmath.vector4(0,0,1,1)})
		
		if distance_from_segment < closestdist then
			closestdist = distance_from_segment 
			
			if distance_from_segment > vehicle.trackradius then
				msg.post("@render:", "draw_line", {start_point = predicted_pos, end_point = projected, color = vmath.vector4(1, 0, 0,1)})
			else
				msg.post("@render:", "draw_line", {start_point = predicted_pos, end_point = projected, color = vmath.vector4(1, 1,0,1)})
			end
			
			newindex = index
			newindexprev = previndex

msg.post("@render:", "draw_line", {start_point = predicted_pos, end_point = predicted_pos + vmath.vector3(10, 10, 0), color = vmath.vector4(0, 0,1,1)})	
msg.post("@render:", "draw_line", {start_point = projected, end_point = projected + vmath.vector3(10, 10, 0), color = vmath.vector4(1, 1,0,1)})
msg.post("@render:", "draw_line", {start_point = vehicle.position, end_point = projected, color = vmath.vector4(1, 0,1,1)})
			
			if distance_from_segment > vehicle.trackradius then
				local pathsegment = vmath.normalize(vehicle.waypoints[index] - vehicle.waypoints[previndex])
				target = projected + pathsegment * vehicle.targetlookaheaddist
			else
				target = vehicle.waypoints[index]
			end
		end
	end
	
	vehicle.waypointindex = newindex
	vehicle.waypointindexprev = newindexprev

	vehicle.target = target

    
	--local curviness = get_curviness(vehicle, vehicle.position, vehicle.curve_lookahead)
	--local curviness_unit = curviness / 180
	--if curviness_unit > 1 then
	--	curviness_unit = 1
	--elseif curviness_unit < -1 then
	--	curviness_unit = -1
	--end
	
	vehicle.curve_point = get_curve_point(vehicle.position, get_previous_index(vehicle.waypoints, vehicle.waypointindex), vehicle.waypoints, vehicle.curve_lookahead)
	local diff = vehicle.curve_point - vehicle.position
	local curviness = math.acos( vmath.dot( vmath.normalize(diff), vmath.normalize(vehicle.velocity) ) )
	
    local curviness_unit = curviness / 180
    curviness_unit = util.clamp(-1, 1, curviness_unit)
    
	--print("curviness", math.deg(curviness), curviness_unit)

	--local desired = vehicle.target - vehicle.position	
	--local offset_normal = vmath.normalize(vmath.vector3(-desired.y, desired.x, 0))
	--vehicle.target = vehicle.target + offset_normal * curviness_unit * 32
	--msg.post("@render:", "draw_line", {start_point = vehicle.target + vmath.vector3(5,5,0), end_point = vehicle.target, color = vmath.vector4(0, 1,0,1)})
	
	local desired = vehicle.target - vehicle.position
	
	
	local length = vmath.length(desired)
	
	--print("vehicle.curve_point", vehicle.curve_point)
	local vellength = vmath.length(vehicle.velocity)
	local vel_curve_dot = 1
	if vellength > 0 then
		local dir = vehicle.velocity * (1/vellength)
		local cpdir = vehicle.curve_point - vehicle.position
		local cpdirlength = vmath.length(cpdir)
		if cpdirlength > 0 then
			--print("dir", dir)
			--print("cpdir", cpdir)
			--print("vehicle.curve_point", vehicle.curve_point)
			--print("vehicle.position", vehicle.position)
			vel_curve_dot = vmath.dot(dir, cpdir * (1/cpdirlength))
			if vel_curve_dot < 0 then
				vel_curve_dot = 0
			end
		end
	end
	
	local velocity = vmath.length(vehicle.velocity)
	if velocity > 0 then
		local brake = vehicle.velocity * -(1 - vel_curve_dot)
		--print("brake", brake)
		--print("vel_curve_dot", vel_curve_dot)
		
		msg.post("@render:", "draw_line", {start_point = vehicle.position, end_point = vehicle.position + brake, color = vmath.vector4(1,0,0,1)})
	
		M.add_force(vehicle, brake)
	end
	
	desired = desired * (1 / length) * vehicle.maxspeed
	
	local steer = desired - vehicle.velocity
	local len = vmath.length(steer)
	if len > vehicle.maxforce then
		steer = steer * (1 / len) * vehicle.maxforce
	end
	
	M.add_force(vehicle, steer)
end

function M.debug(vehicle)

	msg.post("@render:", "draw_line", {start_point = vehicle.position, end_point = vehicle.position + vehicle.velocity, color = vmath.vector4(1,1,1,1)})
	
	msg.post("@render:", "draw_line", {start_point = vehicle.waypoints[vehicle.waypointindex] + vmath.vector3(2,2,0), end_point = vehicle.waypoints[vehicle.waypointindexprev] + vmath.vector3(-2,-2,0), color = vmath.vector4(0, 1,1,1)})
	
	--msg.post("@render:", "draw_line", {start_point = vehicle.position, end_point = vehicle.waypoints[vehicle.waypointindex], color = vmath.vector4(0,1,1,1)})
	--msg.post("@render:", "draw_line", {start_point = vehicle.position, end_point = vehicle.waypoints[vehicle.waypointindexprev], color = vmath.vector4(0,0.8,0.8,1)})

			msg.post("@render:", "draw_line", {start_point = vehicle.curve_point, end_point = vehicle.curve_point + vmath.vector3(5, 10, 0), color = vmath.vector4(1, 0,1,1)})	
end



return M
