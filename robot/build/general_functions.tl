require("deep_copy")
require("build.MetaBuild.MetaSchematic")
require("Position")

local interface BaseFormat is {{string}} default: {string} end
local type SubSegment = {string, Pos2D}
local type SegmentArray = {integer : {SubSegment}}

local record module end
function module.iter(base_table: BaseFormat, goal: integer, segments: SegmentArray): function(): integer | nil, {string} | nil
    local iteration: integer = 0
    return function (): integer | nil, {string} | nil
        iteration = iteration + 1 -- later indexes into 1,2,3
        if iteration > goal then return nil end -- gg

        local cur_base = base_table[iteration]
        if cur_base == nil then cur_base = base_table.default end

        local cur_segment = segments[iteration]
        if cur_segment == nil then
            -- print(comms.robot_send("debug", "iter_func -- segment at iter: " .. tostring(iteration) .. " -- is null"))
            return iteration, cur_base
        end

        local square_segment_to_return = COPY(cur_base, ipairs)

        for _, replaces in ipairs(cur_segment) do
            local term = replaces[1]
            for _, replace_index in ipairs(replaces[2]) do
                square_segment_to_return[replace_index as integer] = term
                -- print(comms.robot_send("debug", "iter_func -> \n" .. serialize.serialize(square_segment_to_return, true)))
            end
        end
        return iteration, square_segment_to_return
    end
end

function module.mirror_x(base_table: BaseFormat, segments: SegmentArray)
    -- Reverse the base
    for _, base in ipairs(base_table) do
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

function module.mirror_z(base_table: BaseFormat, segments: SegmentArray)
    -- Reverse the base
    local ref_to_default: {string} | nil = nil
    for key, base in pairs(base_table as {integer : {string}}) do
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
        if key as string == "def" then ref_to_default = base end

        ::continue::
    end

    -- Early Return
    if segments == nil then return end

    local quad_size_logic = 8 -- imagine this is a const, it's 7+1, the actual size of a quad + 1
    -- Reverse the segments
    for _, seg in pairs(segments) do
        for _, sub_seg in ipairs(seg) do
            for jindex, replacement_num in ipairs(sub_seg[2]) do
                replacement_num = quad_size_logic - (replacement_num as integer)
                sub_seg[2][jindex] = replacement_num
            end
        end
    end
end

function module.count_occurence_of_symbol(
    what_symbol: SpecialSymbol,
    index: integer,
    where: {SpecialSchematicChunk}
): SpecialSchematicChunk | nil, integer | nil
    local to_return: SpecialSchematicChunk = nil
    local num_to_return: integer = nil

    local hits = 0
    for _, symbol in ipairs(where) do
        if symbol[1] == what_symbol then hits = hits + 1 end
        if hits == index then
            num_to_return = index + 1
            local copy = COPY(symbol, ipairs)
            table.remove(copy, 1) -- you fucker man, damn
            to_return = copy
            break
        end
    end

    return to_return, num_to_return
end

return module
