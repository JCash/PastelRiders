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
		maxforce = 10000,
		
		waypoint = nil,
		waypoints = nil,
		waypointindex = 0,
		
		targetradius = 100,
	}
end

function M.update(vehicle, dt)

	if vehicle.waypointindex > 0 then
		local disttotarget = vmath.length(vehicle.waypoint - vehicle.position)
		if disttotarget < 32 then
			vehicle.waypointindex = vehicle.waypointindex + 1
			if vehicle.waypointindex > #vehicle.waypoints then
				vehicle.waypointindex = 1
			end
	    	vehicle.waypoint = vehicle.waypoints[vehicle.waypointindex]
		end
		M.update_target(vehicle, vehicle.waypoint)
	end
	
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
	vehicle.waypointindex = startindex
	vehicle.waypoints = waypoints
	vehicle.waypoint = vehicle.waypoints[vehicle.waypointindex]
end

function M.update_target(vehicle, target)
	local desired = target - vehicle.position
	local length = vmath.length(desired)
	local proximity = 1
	if length < vehicle.targetradius then
		proximity = 0.25 + length / vehicle.targetradius
	end
	desired = desired * (1 / length) * proximity * vehicle.maxspeed
	
	local steer = desired - vehicle.velocity
	local len = vmath.length(steer)
	if len > vehicle.maxforce then
		steer = steer * (1 / len) * vehicle.maxforce
	end
	
	M.add_force(vehicle, steer)
end

function M.debug(vehicle)
	--print("vehicle.accumulated_force", vehicle.accumulated_force)
	--print("vehicle.velocity", vehicle.velocity)
	
	msg.post("@render:", "draw_line", {start_point = vehicle.position, end_point = vehicle.position + vehicle.velocity, color = vmath.vector4(1,1,1,1)})
	
	msg.post("@render:", "draw_line", {start_point = vehicle.position, end_point = vehicle.waypoint, color = vmath.vector4(0,1,1,1)})
	
end



return M
