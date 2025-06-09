local deep_copy = require("deep_copy")
local comms = require("comms")
local serialize = require("serialization")

-- this either really cooks, or really fucks us over, who cares
-- friendly reminder that tables are passed by reference, otherwise this wouldn't work
local module = {}

function module.iter(base_table, goal, segments)
    local iteration = 0
    return function ()
        iteration = iteration + 1 -- later indexes into 1,2,3
        if iteration > goal then return nil end -- gg

        local cur_base = base_table[iteration]
        if cur_base == nil then cur_base = base_table["def"] end

        local cur_segment = segments[iteration]
        if cur_segment == nil then
            print(comms.robot_send("debug", "iter_func -- segment at iter: " .. tostring(iteration) .. " -- is null"))
            return iteration, cur_base
        end

        local square_segment_to_return = deep_copy.copy_table(cur_base, ipairs)

        for _, replaces in pairs(cur_segment) do
            local term = replaces[1]
            for _, replace_index in pairs(replaces[2]) do
                square_segment_to_return[replace_index] = term
                print(comms.robot_send("debug", "iter_func -> \n" .. serialize.serialize(square_segment_to_return, true)))
            end
        end
        return iteration, square_segment_to_return
    end
end

function module.mirror_x(base_table, segments)
    -- Reverse the base
    for key, base in pairs(base_table) do
        -- segments == nil -> we are not using meta-date -> etc
        for index, x_segment in ipairs(base) do
            x_segment = string.reverse(x_segment)
            base[index] = x_segment
        end
    end

    -- Early Return
    if segments == nil then return end

    -- Reverse the segments
    for _, seg in pairs(segments) do
        for _, sub_seg in ipairs(seg) do
            sub_seg[1] = string.reverse(sub_seg[1])
        end
    end
end

function module.mirror_z(base_table, segments)
    -- Reverse the base
    local ref_to_default = nil
    for key, base in pairs(base_table) do
        if base == ref_to_default then goto continue end -- in order not to reverse the def twice
        -- maybe this can be expanded into an "already seen" table in order to not double reverse arbitrarily

        local jindex = 1
        for index = #base, 1, -1 do
            local temp = base[jindex]
            base[jindex] = base[index]
            base[index] = temp
            jindex = jindex + 1
            if index == 4 then break end -- this was the problem, we were reversing and then unreversing
        end
        if key == "def" then ref_to_default = base end

        ::continue::
    end

    -- Early Return
    if segments == nil then return end

    local quad_size_logic = 8 -- imagine this is a const, it's 7+1, the actual size of a quad + 1
    -- Reverse the segments
    for index, seg in pairs(segments) do
        for _, sub_seg in ipairs(seg) do
            for jindex, replacement_num in ipairs(sub_seg[2]) do
                replacement_num = quad_size_logic - replacement_num
                sub_seg[2][jindex] = replacement_num
            end
        end
    end
end

return module
