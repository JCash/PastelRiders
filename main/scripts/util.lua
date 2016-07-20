local constants = require("main/scripts/constants")

local M = {}

-- Takes a 1 based array index, creates a zero based 2d tile coordinate
function M.index_to_coords(index, width)
    local x = math.floor((index-1) % width)
    local y = math.floor((index-1) / width)
    return x, y
end

-- Takes a zero based 2d tile coordinate, and the level width (tiles)
-- Returns a 1 based array index 
function M.coords_to_index(x, y, width)
    return y * width + x + 1
end

-- Takes a zero based 2d tile coordinate, returns a 2d screen coordinate
function M.coords_to_screen(x, y)
    local scrx = constants.TILE_SIZE * x + constants.TILE_SIZE / 2
    local scry = constants.TILE_SIZE * y + constants.TILE_SIZE / 2
    return scrx, scry
end

-- Takes a 2d screen coordinate, returns a zero based 2d tile coordinate
function M.screen_to_coords(x, y)
    return math.floor(x / constants.TILE_SIZE), math.floor(y / constants.TILE_SIZE)
end

return M
