local constants = require("main/scripts/constants")

local M = {}

M.trainer_runs = {}
M.trainer_current_run = {}
M.trainer_current_time = 0
M.trainer_best_run = 0 -- index into the trainer runs
M.trainer_best_run_time = 1000000 -- the currently best time
M.trainer_run_count = 0
M.trainer_waypoints = {}
M.trainer_waypoint_reached = 0 -- what is the highest index reached?
M.trainer_segments_visited = 0

M.trainer_best_run_data = nil


function M.render_trainer_data(data)
    if data == nil then
        return
    end
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

function M.print_wps(index, waypoints)
    for i = 1, #waypoints do
        local s = (i == index) and "*" or ""
        
        print(string.format("%g: spd: %g %s", i, math.floor(waypoints[i].speed), s))
    end
end

function M.waypoints_setup(waypoints)
    for i = 1, #waypoints do
        local index = i
        
        local segment_prev = waypoint.get_segment(waypoints, index-1, index)
        local segment_next = waypoint.get_segment(waypoints, index, index+1)
        local entering_curve_scale = vmath.length_sqr(segment_prev) > vmath.length_sqr(segment_next) and 1 or -1
        local curviness = waypoint.get_curviness(waypoints, index, 150)
        local normal = vmath.normalize(vmath.vector3(-segment_prev.y, segment_prev.x, 0))
        
        if waypoints[index].offset ~= nil then
            print("offset before", waypoints[index].offset)
        end
        
        local dist = math.random()
        local angle = math.pi * 2 * math.random()
        local rand_offset = 0 * dist * vmath.vector3(math.cos(angle), math.sin(angle), 0)
        
        local curvescale = math.max(0, (1 - curviness/math.pi) - 1)
        waypoints[index].offset = normal * constants.TRACK_RADIUS * curvescale * entering_curve_scale + rand_offset
        
        waypoints[index].speed = level_maxspeed - constants.LEVEL_MAX_SPEED * curvescale
        
        print("segment_next", segment_next)
        print("normal", normal)
        print("entering_curve", entering_curve_scale)
        print("curvescale", curvescale)
        print("offset after", waypoints[index].offset)
    end
end

function M.modify_waypoints(self, waypoints, maxspeed)
    if self.trainer == 1 then
        local index = 0
        local lower_speed = 0
        local speed_lower_limit = 60
        
        print("modify_waypoints")
        
        if trainer_waypoint_reached == 0 or trainer_waypoint_reached == #waypoints then
            print("  lap case")    
            index = math.floor(math.random() * (#waypoints-1)) + 1
            
        else
            print("  wp case")
            
            local countback = 6
            local r = math.random()
            index = trainer_waypoint_reached - math.floor(r * countback)
            index = waypoint.wrap_index(waypoints, index)
            
            print("trainer_waypoint_reached", trainer_waypoint_reached)
            print("index", index)
            
            if trainer_waypoint_reached == 1 then
                print("trainer_waypoint_reached / countback", trainer_waypoint_reached, countback)
            end
            
            local start_search_index = trainer_waypoint_reached
            if trainer_waypoint_reached < trainer_segments_visited then
                -- we have reached almost all the way around
                start_search_index = #waypoints
                print("index (changed)", index)
            end
            
            local found = 0
            for i = start_search_index, start_search_index - countback, -1 do
                local ii = waypoint.wrap_index(waypoints, i)

                local speed = waypoints[ii].speed
                if speed == 0 or speed > speed_lower_limit then
                    index = ii
                    print("index (changed)", index)
                    break
                end
            end
            
            
            lower_speed = 1
        end
        
        --local dist = math.random()
        --local angle = math.pi * 2 * math.random()
        --waypoints[index].offset = constants.TRACK_RADIUS * dist * vmath.vector3(math.cos(angle), math.sin(angle), 0)
        
        --index = 1
        
        local segment_prev = waypoint.get_segment(waypoints, index-1, index)
        local segment_next = waypoint.get_segment(waypoints, index, index+1)
        local entering_curve_scale = vmath.length_sqr(segment_prev) > vmath.length_sqr(segment_next) and 1 or -1
        local curviness = waypoint.get_curviness(waypoints, index, 150)
        local normal = vmath.normalize(vmath.vector3(-segment_prev.y, segment_prev.x, 0))
        
        if waypoints[index].offset ~= nil then
            print("offset before", waypoints[index].offset)
        end
        
        
        local dist = math.random()
        local angle = math.pi * 2 * math.random()
        local rand_offset = 10 * dist * vmath.vector3(math.cos(angle), math.sin(angle), 0)
        
        local curvescale = math.max(0, (1 - curviness/math.pi) - 1)
        waypoints[index].offset = normal * constants.TRACK_RADIUS * curvescale * entering_curve_scale + rand_offset
        
        --print("segment_next", segment_next)
        --print("normal", normal)
        --print("entering_curve", entering_curve_scale)
        --print("curvescale", curvescale)
        --print("offset after", waypoints[index].offset)
        
        if lower_speed ~= 0 then
            local speed = waypoints[index].speed
            
            --print("lower_speed", lower_speed)
            if speed == 0 then
                waypoints[index].speed = maxspeed * 0.9
                print(string.format("set maxspeed[%d] = %f", index, waypoints[index].speed))
            elseif speed > maxspeed then
                waypoints[index].speed = waypoints[index].speed * 0.9
                print(string.format("set speed[%d] = %f", index, waypoints[index].speed))
            elseif speed > speed_lower_limit  then
                waypoints[index].speed = waypoints[index].speed * 0.95
                print(string.format("speed[%d] = %f", index, waypoints[index].speed))
            end
        else
            waypoints[index].speed = waypoints[index].speed * 1.10
            print(string.format("increase speed[%d] = %f", index, waypoints[index].speed))
        end
    end
end

function M.update(dt)
    M.trainer_current_time = M.trainer_current_time + dt
    if M.trainer_best_run ~= 0 and M.trainer_current_time > M.trainer_best_run_time then
        -- if the run took too long, abort
        msg.post("#", constants.TRAINER_MESSAGE_FAILED, { reason = "Lap took too long", waypoint = 0, time = trainer_current_time, speed = 0, numsegments = 0 })
    end
end

return M
