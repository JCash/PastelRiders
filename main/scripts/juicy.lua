local M = {}

function M.bounce_text(node, duration)
    gui.set_scale(node, vmath.vector3(1.2) )
    gui.animate(node, gui.PROP_SCALE, vmath.vector4(1), gui.EASING_LINEAR, 0.5, 0, nil, gui.PLAYBACK_ONCE)
    
    local color = gui.get_color(node)
    gui.set_color(node, vmath.vector4(0.8, 0.8, 0.8, 1))
    gui.animate(node, gui.PROP_COLOR, color, gui.EASING_INOUTQUAD, 0.5) -- start animation
end

return M
