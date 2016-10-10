local constants = require("main/scripts/constants")

local M = {}

-- Implementation inspired by http://stackoverflow.com/a/1557247/468516
local function spiral_loop(X, Y, fn)
	local x = 0
	local y = 0
	local dx = 0
	local dy = -1
	local s = 0
	local ds = 2
	local max = math.max(X, Y)
	local maxsq = max*max
	local middlex = math.floor(X/2)
	local middley = math.floor(Y/2)
	for i = 0, maxsq-1 do
		if math.abs(x) <= X and math.abs(y) <= math.floor(Y/2) then
			fn(x+middlex, y+middley)
		end
		if i == s then
			dx, dy = -dy, dx
			s, ds = s + math.floor(ds/2), ds + 1
		end
		x, y = x+dx, y+dy
	end
end

local stencil_anim_count = 0

local function stencil_anim_done(self, url, property)
	stencil_anim_count = stencil_anim_count - 1
	if stencil_anim_count == 0 then
		print("disable_stencil_mask")
		msg.post("@render:", "disable_stencil_mask")
		
		--print("STOPPED RECORDING")
		--msg.post("@system:", "stop_record")
	end
end

function M.do_screen_fade_in(width, height, startpos)
    local num_tiles_x = math.ceil(width / constants.TILE_SIZE * 0.5)
    local num_tiles_y = math.ceil(height / constants.TILE_SIZE * 0.5)
    
    local screen_offset = startpos - vmath.vector3(width / 4, height / 4, 0)
    -- the distance from center of screen to the corner of the screen
    local max_dist = vmath.length( vmath.vector3(width / 4, height / 4, 0) )
    
    local tiles = {}
    
    local maxcount = num_tiles_x*num_tiles_y-1
    
    stencil_anim_count = 0
    
    
	--print("RECORDING")
	--msg.post("@system:", "start_record", { file_name = "/Users/mawe/defold_rec.ivf" } )
    
    local count = 0
    spiral_loop(num_tiles_x, num_tiles_y,
    	function(x, y)
            local scrx = x * constants.TILE_SIZE + constants.TILE_SIZE/2 + screen_offset.x
            local scry = y * constants.TILE_SIZE + constants.TILE_SIZE/2 + screen_offset.y
            local pos = vmath.vector3(scrx, scry, 0.8)
            local tile = factory.create("/common/common#stencil_tile_factory", pos, vmath.quat_rotation_z(0), {}, vmath.vector3(0, 0, 0) )
            tiles[tile] = tile
            
            stencil_anim_count = stencil_anim_count + 1
            
            -- spiral
            local unitcount = count/maxcount
            --go.animate(tile, "scale", go.PLAYBACK_ONCE_FORWARD, 1, go.EASING_LINEAR, 0.4 - 0.35 * unitcount, count * 0.008, stencil_anim_done)
            
            -- random
            go.animate(tile, "scale", go.PLAYBACK_ONCE_FORWARD, 1, go.EASING_LINEAR, 0.2 + math.random() * 0.2, math.random() * 0.3, stencil_anim_done)

			-- bottom left to top right
			local manhattandist = (x + y) / (num_tiles_x + num_tiles_y)
			--go.animate(tile, "scale", go.PLAYBACK_ONCE_FORWARD, 1, go.EASING_LINEAR, 0.5, manhattandist * 0.8, stencil_anim_done)
            
            count = count + 1
    	end)
end


return M
