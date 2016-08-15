local M = {}

function M.set_waypoints(waypoints)
	M.waypoints = waypoints
end

function M.get_waypoints()
	return M.waypoints
end

-- Traverses a tilemap layer, finding waypoints along the way
-- Each waypoint has an extra neighbor that dictates the next direction (may be diagonal)
-- The traversal stops if it passes the starting point again 
function M.find_route(tilemap_url, layername, starttile, startdir)
	local tilemapx, tilemapy, tilemapwidth, tilemapheight = tilemap.get_bounds(tilemap_url)
	
	local waypoints = {}
	
	local x = starttile[1]
	local y = starttile[2]
	local dirx = startdir[1]
	local diry = startdir[2]
	
	local last_waypoint_x = x
	local last_waypoint_y = y
	
	while true do
		x = x + dirx
		y = y + diry

		if x == starttile[1] and y == starttile[2] then
			break
		end
		
		if x < tilemapx or x >= tilemapx + tilemapwidth or y < tilemapy or y >= tilemapy + tilemapheight then
			print("We hit the border at", x, y)
			print("Last waypoint was at", last_waypoint_x, last_waypoint_y)
			break
		end
		
		local tile = tilemap.get_tile(tilemap_url, layername, x, y)
		if tile > 0 then
			-- We found a waypoint
			table.insert(waypoints, {x, y})
			
			-- now search for the direction to go next
			-- i.e. find a non nil neighbor in any of the 8 directions
			local debug = false and x == 5 and y == 17
			for ny = -1,1 do
				for nx = -1,1 do
					-- avoid the center tile and the tile we're coming from
					local is_center = nx == 0 and ny == 0
					local has_visited = x+nx == last_waypoint_x and y+ny == last_waypoint_y
					if not is_center and not has_visited then
						local neighbortile = tilemap.get_tile(tilemap_url, layername, x+nx, y+ny)

						if neighbortile > 0 then
							dirx = nx
							diry = ny
							break
						end
					end
				end
			end
			
			last_waypoint_x = x
			last_waypoint_y = y
		end 	
	end
	return waypoints
end

function M.stringify_vec3(wp)
    return "" .. tostring(wp.x) .. "," .. tostring(wp.y) .. "," .. tostring(wp.z) .. ""
end

local function stringify_wp(wp)
    local pos = '"pos" : "' .. M.stringify_vec3(wp.pos) .. '"'
    local offset = '"offset" : "' .. M.stringify_vec3(wp.offset) .. '"'
    local speed = '"speed" : "' .. tostring(wp.speed) .. '"'
    
    return '{ ' .. pos .. ', ' .. offset .. ', ' .. speed .. ' }'
end


local function stringify_waypoints(waypoints)
    local s = "{\n"
    for i, wp in pairs(waypoints) do
        s = s .. '  ' .. tostring(i) .. ' : ' .. stringify_wp(wp)
        if i ~= #waypoints then
            s = s .. ',\n'
        else
            s = s .. '\n'
        end
    end
    s = s .. "}\n"
    return s
end


function M.save_waypoints(path, waypoints)
    local encoded = stringify_waypoints(waypoints)
    
    local file = io.open(path, "wb")
    file:write(encoded)
    file:close()
end

local function split(s, delimiter)
    result = {};
    for match in (s..delimiter):gmatch("(.-)"..delimiter) do
        table.insert(result, match);
    end
    return result;
end

function M.decode_vec3(s)
    local x, y, z = s:match("([^,]+),([^,]+),([^,]+)")
    return vmath.vector3( tonumber(x), tonumber(y), tonumber(z) )
end

function M.load_waypoints(path)
    local file, result = io.open(path, "rb")
    if file == nil then
        print("No such file", path)
        return nil
    end
    
    local encoded = ""
    for line in file:lines() do
        encoded = encoded .. line
    end
    file:close()

    local decodedwaypoints = json.decode(encoded)
    
    local waypoints = {}
    
    for i, v in pairs(decodedwaypoints) do
        local wp = {}
        local v = decodedwaypoints[i]
        wp.pos = M.decode_vec3(v.pos)
        wp.offset = M.decode_vec3(v.offset)
        wp.speed = tonumber(v.speed)
        waypoints[i] = wp
    end
    
    return waypoints
end

function M.get_previous_index(waypoints, index)
    local index = index - 1
    if index < 1 then
        index = #waypoints
    end
    return index
end

function M.get_next_index(waypoints, index)
    local index = index + 1
    if index > #waypoints then
        index = 1
    end
    return index
end

function M.wrap_index(waypoints, index)
    return ((index-1) % #waypoints) + 1
end

-- gets a point on the path, given a distance, relative to the start position (which should be on the path)
function M.get_curve_point(startposition, startindex, waypoints, distance)
    while distance > 0 do
        local segment = waypoints[startindex].pos + waypoints[startindex].offset - startposition
        local segmentlength = vmath.length(segment)
        
        if segmentlength > distance then
            segment = segment * (1 / segmentlength)
            return startposition + segment * distance
        end
        
        distance = distance - segmentlength
        startposition = waypoints[startindex].pos
        startindex = M.get_next_index(waypoints, startindex)
    end
    return startposition
end


-- returns the curviness (+/- angle) for a waypoint, given some lookahead distance
function M.get_curviness(waypoints, index, distance)
    index = M.wrap_index(waypoints, index)
    local pos = waypoints[index].pos
    local curve_point = M.get_curve_point(pos, index, waypoints, distance)
    local segment = vmath.normalize(pos - waypoints[M.get_previous_index(waypoints, index)].pos)
    local dir = curve_point - pos
    local normal = vmath.vector3(-segment.y, segment.x, 0)
    local dot = vmath.dot(segment, vmath.normalize(dir))

    if vmath.dot(normal, dir) >= 0 then
        return math.acos(dot)
    else
        return -math.acos(dot)
    end
end


-- gets the segement (i2 - i1)
function M.get_segment(waypoints, index1, index2)
    index1 = M.wrap_index(waypoints, index1)
    index2 = M.wrap_index(waypoints, index2)
    return waypoints[index2].pos - waypoints[index1].pos
end


function M.get_segment_length(waypoints, index1, index2)
    return vmath.length( M.get_segment(waypoints, index1, index2) )
end

function M.get_segment_normal(waypoints, index1, index2)
    local segment = M.get_segment(waypoints, index1, index2)
    return vmath.vector3(-segment.y, segment.x, 0)
end

function M.get_projected_position(position, waypoints, waypointindex, waypointcount)
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

return M
