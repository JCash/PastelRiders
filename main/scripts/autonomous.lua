
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
		
		waypoint = nil,
		waypoints = nil,
		waypointindex = 0,
		pathedge = nil,
		
		targetradius = 100,
		trackradius = 3 * 32 * 0.25, --3 * 32 * 0.5,
		targetlookaheaddist = 64,--24,
		
		curve_point = nil
	}
end


function M.update(vehicle, dt)
	M.update_target(vehicle)
	
	msg.post("@render:", "draw_line", {start_point = vehicle.position, end_point = vehicle.position + vehicle.accumulated_force, color = vmath.vector4(0,1,0,1)})
	
	local acceleration = vehicle.accumulated_force * vehicle.oneovermass
	vehicle.velocity = vehicle.velocity + acceleration * dt
	vehicle.position = vehicle.position + vehicle.velocity * dt
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
		local wpindexprev = wpindex - 1
		if wpindexprev < 1 then
			wpindexprev = #vehicle.waypoints
		end
		previousdir = vehicle.waypoints[wpindex] - vehicle.waypoints[wpindexprev]
		segmentlength = vmath.length(previousdir)
	end
	previousdir = previousdir * (1/segmentlength)
	point_on_path = vehicle.waypoints[wpindex]
	
	--print("previousdir", previousdir)
	
	local angle = 0
	while distance_ahead > 0 do
		wpindex = wpindex + 1
		if wpindex > #vehicle.waypoints then
			wpindex = 1
		end
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
		local previndex = index - 1
		if previndex < 1 then
			previndex = #vehicle.waypoints
		end
		
		local v = predicted_pos - vehicle.waypoints[previndex]
		pathsegment = vehicle.waypoints[index] - vehicle.waypoints[previndex]
		local pathsegmentlength = vmath.length(pathsegment)
		pathsegment = pathsegment * (1/pathsegmentlength)
		
		-- project the position onto the track edge
		local dot = vmath.dot(v, pathsegment) / pathsegmentlength
		
		local projected = nil
		if dot >= 1 then
			projected = vehicle.waypoints[index]
		elseif dot <= 0 then
			projected = vehicle.waypoints[previndex]
		else
			projected = vehicle.waypoints[previndex] + pathsegment * pathsegmentlength * dot
		end

		local distance_from_segment = vmath.length(projected - predicted_pos)
		
		if distance_from_segment < closestdist then
			closestdist = distance_from_segment 
			
			--if distance_from_segment > vehicle.trackradius then
			--	msg.post("@render:", "draw_line", {start_point = predicted_pos, end_point = projected, color = vmath.vector4(1, 0, 0,1)})
			--else
			--	msg.post("@render:", "draw_line", {start_point = predicted_pos, end_point = projected, color = vmath.vector4(1, 1,0,1)})
			--end
			
			newindex = index
			newindexprev = previndex

msg.post("@render:", "draw_line", {start_point = predicted_pos, end_point = predicted_pos + vmath.vector3(10, 10, 0), color = vmath.vector4(0, 0,1,1)})	
msg.post("@render:", "draw_line", {start_point = projected, end_point = projected + vmath.vector3(10, 10, 0), color = vmath.vector4(1, 0,0,1)})
msg.post("@render:", "draw_line", {start_point = vehicle.position, end_point = projected, color = vmath.vector4(1, 0,0,1)})
				
			if distance_from_segment > vehicle.trackradius then
				target = projected + pathsegment * vehicle.targetlookaheaddist
			else
				target = vehicle.waypoints[index]
			end
		end
	end
	
	vehicle.waypointindex = newindex
	vehicle.waypointindexprev = newindexprev

	vehicle.target = target

	local curviness = get_curviness(vehicle, vehicle.position, 200)
	local curviness_unit = curviness / 180
	if curviness_unit > 1 then
		curviness_unit = 1
	elseif curviness_unit < -1 then
		curviness_unit = -1
	end
	
	print("curviness", util.rad_to_deg(curviness), curviness_unit)

	--local desired = vehicle.target - vehicle.position	
	--local offset_normal = vmath.normalize(vmath.vector3(-desired.y, desired.x, 0))
	--vehicle.target = vehicle.target + offset_normal * curviness_unit * 32
	--msg.post("@render:", "draw_line", {start_point = vehicle.target + vmath.vector3(5,5,0), end_point = vehicle.target, color = vmath.vector4(0, 1,0,1)})
	
	local desired = vehicle.target - vehicle.position
	
	
	local length = vmath.length(desired)
	
	--local slowdown = (1.0 - math.abs(curviness_unit)) * 0.85 + 0.15
	print("vehicle.curve_point", vehicle.curve_point)
	local vellength = vmath.length(vehicle.velocity)
	local vel_curve_dot = 1
	if vellength > 0 then
		local dir = vehicle.velocity * (1/vellength)
		local cpdir = vehicle.curve_point - vehicle.position
		local cpdirlength = vmath.length(cpdir)
		if cpdirlength > 0 then
			print("dir", dir)
			print("cpdir", cpdir)
			print("vehicle.curve_point", vehicle.curve_point)
			print("vehicle.position", vehicle.position)
			vel_curve_dot = vmath.dot(dir, cpdir * (1/cpdirlength))
			if vel_curve_dot < 0 then
				vel_curve_dot = 0
			end
		end
	end
	local slowdown = 0.15 + 0.85 * vel_curve_dot
	
	print("slowdown", slowdown)
	
	--local proximity = 1
	--local wpproximity = vmath.length(vehicle.waypoints[vehicle.waypointindex] - vehicle.position)
	--if wpproximity < vehicle.targetradius then
		--proximity = 0.25 + wpproximity / vehicle.targetradius
		--print("proximity", proximity)
	--end
	
	
	desired = desired * (1 / length) * slowdown * vehicle.maxspeed
	
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
