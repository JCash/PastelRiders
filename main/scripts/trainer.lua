
local M = {}

function M.render_trainer_data(data)
    for i = 1, #data do
        if data[i] ~= nil then
            local d1 = data[i]
            local d2 = data[i % #data + 1]
            
            local spd = vmath.length(d1.velocity)
            spd = math.min(250, math.max(0, spd)) / 250 
            
            msg.post("@render:", "draw_line", {start_point = d1.position, end_point = d2.position, color = vmath.vector4(spd, spd, spd, 1)})
        end
    end
end


local function stringify_vec3(wp)
    return "" .. tostring(wp.x) .. "," .. tostring(wp.y) .. "," .. tostring(wp.z) .. ""
end

local function stringify_trainer_point(pt)
    local pos = '"pos" : "' .. stringify_vec3(pt.position) .. '"'
    local dir = '"dir" : "' .. stringify_vec3(pt.direction) .. '"'
    local vel = '"vel" : "' .. stringify_vec3(pt.velocity) .. '"'
    
    return '{ ' .. pos .. ', ' .. dir .. ', ' .. vel .. ' }'
end


local function stringify_trainer_points(pts)
    local s = "{\n"
    for i, pt in pairs(pts) do
        s = s .. '  ' .. tostring(i) .. ' : ' .. stringify_trainer_point(pt)
        if i ~= #pts then
            s = s .. ',\n'
        else
            s = s .. '\n'
        end
    end
    s = s .. "}\n"
    return s
end

function M.save_data(path, data)
    local encoded = stringify_trainer_points(data)
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

local function decode_vec3(s)
    local x, y, z = s:match("([^,]+),([^,]+),([^,]+)")
    return vmath.vector3( tonumber(x), tonumber(y), tonumber(z) )
end

function M.load_data(path)
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

    local decodedpts = json.decode(encoded)
    
    local pts = {}
    
    for i, v in pairs(decodedpts) do
        local pt = {}
        pt.position = decode_vec3(v.pos)
        pt.direction = decode_vec3(v.dir)
        pt.velocity = decode_vec3(v.vel)
        pts[i] = pt
    end
    
    return pts
end

return M
