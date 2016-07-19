local M = {}

-- Traverses a tilemap layer, finding waypoints along the way
-- Each waypoint has an extra neighbor that dictates the next direction (may be diagonal)
function M.find_route(tilemap_url, layername, starttile, startdir)
	local tilemapx, tilemapy, tilemapwidth, tilemapheight = tilemap.bounds(tilemap_url)
	
	local waypoints = {}
	
	local x = starttile[1]
	local y = starttile[2]
	local dirx = startdir[1]
	local diry = startdir[2]
	while true do
		x = x + dirx
		y = y + diry
		
		if x < tilemapx or x >= tilemapx + tilemapwidth then
		end
		
		local tile = tilemap.get_tile(tilemap_url, layername, x, y)
		if tile ~= nil then
		end 	
	end 
end

return M
