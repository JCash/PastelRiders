-- As seen in the examples by Björn Ritzl (https://github.com/britzl/publicexamples/tree/master/examples/fixed_aspect_ratio) 


local M = {}

M.width = 800
M.height = 600

function M.action_to_position(action)
    return vmath.vector3((M.xoffset or 0) + action.screen_x / (M.zoom_factor or 1), (M.yoffset or 0) + action.screen_y / (M.zoom_factor or 1), 0)
end

return M