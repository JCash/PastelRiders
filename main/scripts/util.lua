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

function M.coords_to_screen_vector(x, y)
    local scrx = constants.TILE_SIZE * x + constants.TILE_SIZE / 2
    local scry = constants.TILE_SIZE * y + constants.TILE_SIZE / 2
    return vmath.vector3(scrx, scry, 0)
end

-- Takes a 2d screen coordinate, returns a zero based 2d tile coordinate
function M.screen_to_coords(x, y)
    return math.floor(x / constants.TILE_SIZE), math.floor(y / constants.TILE_SIZE)
end

function M.round(x)
  return x>=0 and math.floor(x+0.5) or math.ceil(x-0.5)
end

function M.angle_to_rad(angle)
	return (2.0 * math.pi * angle) / constants.NUM_DIRECTIONS
end

function M.deg_to_rad(deg)
	return deg * (math.pi/180)
end

function M.rad_to_deg(rad)
	return rad * (180/math.pi)
end


function M.rad_to_angle(rad)
	return math.floor((rad * constants.NUM_DIRECTIONS) / (2.0 * math.pi))
end

function M.get_direction_from_angle(angle)
	local rad = M.angle_to_rad(angle)
	return vmath.vector3(math.cos(rad), math.sin(rad), 0)
end

function M.get_direction_from_rad(rad)
	return vmath.vector3(math.cos(rad), math.sin(rad), 0)
end

function M.clamp(a, b, v)
	if v < a then
		return a
	elseif v > b then
		return b
	else
		return b
	end
end

function M.scale(v, a1, b1, a2, b2)
	local u = (v - a1) / (b1 - a1)
	return a2 + u * (b2 - a2)
end

function M.project_point_to_line_segment(p, a, b)
	local v = p - a
	local linesegment = b - a
	local linesegmentlength = vmath.length(linesegment)
	local dot = vmath.project(v, linesegment)
	
	local projected = nil
	if dot >= 1 then
		projected = b
	elseif dot <= 0 then
		projected = a
	else
		projected = a + linesegment * dot
	end
	return projected
end

function M.format_time(t)
    local minutes = math.floor(t / 60)
    local seconds = math.floor(t % 60)
    local fraction = t - seconds
    return string.format("%2d:%02d:%02d", minutes, seconds, fraction*100)
end

return M

