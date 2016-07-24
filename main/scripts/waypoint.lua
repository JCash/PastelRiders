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

return M
