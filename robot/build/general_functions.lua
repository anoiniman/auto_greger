-- this either really cooks, or really fucks us over, who cares
-- friendly reminder that tables are passed by reference, otherwise this wouldn't work
local module = {}

function module.iter(base_table, goal, segments)
    local iteration = 0
    return function ()
        iteration = iteration + 1 -- later indexes into 1,2,3
        local cur_base = base_table[iteration]

        if cur_base == nil then cur_base = base_table["def"] end
        --if cur_base == nil then cur_base = base_table["o_def"] end

        local cur_segment = segments[iteration]
        if cur_segment == nil then
            return iteration, cur_base[2]
        end

        local height_segment_to_return = deep_copy.copy_table(cur_base[2], ipairs)  -- as you can see meta-data is stripped, I mean,
                                                                                    -- it simply isn't returned
        for _, value in pairs(cur_segment) do
            local term = table.remove(value, 1)
            for _, replace_index in pairs(value) do
                height_segment_to_return[replace_index] = term
            end
        end
        return iteration, height_segment_to_return  
    end
end

function module.mirror_x(base_table, segments)
    local watch_dog = false
    -- Reverse the base
    for key, base in pairs(base_table) do
        if base[1] == "def" then -- because there might be multiple refs to "def" we only need to reverse it once
            if watch_dog == false then
                watch_dog = true
            else
                goto continue
            end
        end

        for _, x_segment in ipairs(base[2]) do
            x_segment = string.reverse(x_segment)
        end
        ::continue::
    end

    -- Reverse the segments
    for _, seg in pairs(segments) do
        for _, sub_seg in ipairs(seg) do
            sub_seg[1] = string.reverse(segment[1])
        end
    end
end

function module.mirror_z(base_table, segments)
    local watch_dog = false
    -- Reverse the base
    for key, base in pairs(base_table) do
        if base[1] == "def" then -- because there might be multiple refs to "def" we only need to reverse it once
            if watch_dog == false then
                watch_dog = true
            else
                goto continue
            end
        end

        local human_readable = base[2]
        local jindex = 1
        for index = #human_readable, 1, -1 do
            local temp = human_readable[jindex]
            human_readable[jindex] = human_readable[index]
            human_readable[index] = temp
            jindex = jindex + 1
        end

        ::continue::
    end

    local quad_size_logic = 8 -- imagine this is a const, it's 7+1, the actual size of a quad + 1
    -- Reverse the segments
    for index, seg in pairs(segments) do
        for _, sub_seg in ipairs(seg) do
            for _, replacement_num in ipairs(sub_seg[2]) do
                replacement_num = quad_size_logic - replacement_num
            end
        end
    end
end

return module
