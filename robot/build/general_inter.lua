-- this either really cooks, or really fucks us over, who cares

return function iter(base_table, goal, segments)
    local iteration = 0
    return function ()
        iteration = iteration + 1 -- later indexes into 1,2,3
        local cur_base = base_table[iteration]
        if cur_base == nil then cur_base = base_table["def"] end

        local cur_segment = segments[iteration]
        if cur_segment == nil then
            return iteration, cur_base
        end

        local height_segment_to_return = deep_copy.copy_table(cur_base, ipairs)

        for _, value in pairs(cur_segment) do
            local term = table.remove(value, 1)
            for _, replace_index in pairs(value) do
                height_segment_to_return[replace_index] = term
            end
        end
        return iteration, height_segment_to_return  
    end
end
