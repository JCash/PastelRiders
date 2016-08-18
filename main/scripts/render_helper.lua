-- As seen in the examples by Björn Ritzl (https://github.com/britzl/publicexamples/tree/master/examples/fixed_aspect_ratio) 


local M = {}

--[[
M.xoffset = 0
M.yoffset = 0
M.zoom_factor = 1
--]]
M.width = 800
M.height = 600

function M.point_to_position(x, y)
    return vmath.vector3((M.xoffset or 0) + x / (M.zoom_factor or 1), (M.yoffset or 0) + y / (M.zoom_factor or 1), 0)
end

return M