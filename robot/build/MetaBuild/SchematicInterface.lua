-- luacheck: ignore io
local serialize = require("serialization")
local io = require("io")

local comms = require("comms")
local deep_copy = require("deep_copy")

local MetaSchematic = require("build.MetaBuild.MetaSchematic")
local BuildInstruction = require("build.MetaBuild.BuildInstruction")

local BuildStack = { -- reading head maxxed printer pilled state machine adjacent
    logical_x = 1,
    logical_z = 1,
    logical_y = 1
}
function BuildStack:new()
    return deep_copy.copy(self, pairs)
end

-- adds bounding box and ref to child.dictionary to MetaSchematic
local SchematicInterface = {
    schematic = MetaSchematic:new(),
    dictionary = nil, -- {}
    origin_block = {
        x = 0,
        z = 0,
        y = 0
    },
    special_blocks = {},

    build_stack = BuildStack:new()
}
function SchematicInterface:new()
    return deep_copy.copy(self, pairs)
end

function SchematicInterface:init(dict, origin)
    self.origin_block = origin
    self.dictionary = dict
end

function SchematicInterface:getSpecialBlocks()
    return self.special_blocks
end

function SchematicInterface:parseStringArr(string_array, square_index)
    local special_blocks = self.schematic:parseStringArr(string_array, square_index)
    if special_blocks ~= nil then
        for _, special in ipairs(special_blocks) do
            table.insert(self.special_blocks, special)
        end
    end

    if #self.schematic == 0 then print(comms.robot_send("error", "we ballsd up good :(")) end
end

function SchematicInterface:advanceY(top_down)
    local b_stack = self.build_stack
    if top_down then
        return b_stack.logical_y > 0
    end
    return b_stack.logical_y <= #self.schematic
end

function SchematicInterface:forceAdvanceHead(top_down)
    local b_stack = self.build_stack

    if b_stack.logical_z <= 7 then -- try and read every line
        b_stack.logical_x = 1
        b_stack.logical_z = b_stack.logical_z + 1
    elseif self:advanceY(top_down) then -- only then move-up in height
        b_stack.logical_x = 1
        b_stack.logical_z = 1

        if not top_down then
            b_stack.logical_y = b_stack.logical_y + 1
        else
            b_stack.logical_y = b_stack.logical_y - 1
        end
    else -- we can only assume there is nothing left to process, let's mark ourself as built
        return true
    end

    return false -- aka continue
end

-- chunk.dist && chunk.symbol
function SchematicInterface:doBuild(top_down)
    local b_stack = self.build_stack

    --[[local print_a = serialize.serialize(b_stack, true)
    print(comms.robot_send("debug", "b_stack is: \n" .. print_a))

    local print_schematic = serialize.serialize(self.schematic, true)
    print(comms.robot_send("debug", "self.schematic is: \n" .. print_a))--]]

    --local chunk = self.schematic.lookUp(b_stack.logical_y, b_stack.logical_z, b_stack.logical_x)

    local chunk = nil --luacheck: ignore
    local line = nil --luacheck: ignore
    local square = nil --luacheck: ignore

    square = self.schematic[b_stack.logical_y]
    if square == nil then goto very_funny end

    line = square[b_stack.logical_z]
    if line == nil then goto very_funny end

    chunk = line[b_stack.logical_x]

    ::very_funny::
    if chunk == nil then
        if self:forceAdvanceHead(top_down) then
            return true, "done"
        end
        return self:doBuild(top_down)
    end
    if chunk.symbol == '*' or chunk.symbol == '+' or chunk.symbol == '?' then -- or other such special characters
        b_stack.logical_x = b_stack.logical_x + 1
        return self:doBuild(top_down)
    end

    b_stack.logical_x = b_stack.logical_x + 1 -- prepare the advance to next column element

    local rel = {0, 0, 0}
    rel[3] = self.origin_block[3] + (b_stack.logical_y - 1) -- (-1) compensates for array access being on 1
    rel[2] = self.origin_block[2] + (b_stack.logical_z - 1)
    rel[1] = self.origin_block[1] + chunk.x

    local instruction = self:InstructionConstruction(chunk, rel)

    return true, "continue", instruction
end

-- place for the side argument in place
-- orientation to have the robot change it's orientation before placing

local function interpret_element(element, index, do_error)
    if element == nil then
        print(comms.robot_send("error", "SI:interpret_element, element nil! Expected a table to have more than 1 element"))
        return nil
    end

    if element == "west" or element == "east" or element == "north" or element == "south" or element == "up" or element == "down" then
        if index == 1 then return "place", element
        elseif index == 2 then return "orient", element
        else error(comms.robot_send("fatal", "interpret_element: as of yet unsupported!")) end

    else -- non instruction element
        if do_error then
            print(comms.robot_send("error", "SI:IC, instruction: \"" .. element .. "\" not recognized"))
        end
        return nil
    end
end

function SchematicInterface:InstructionConstruction(chunk, rel)
    local translated_symbol = self.dictionary[chunk.symbol]
    if translated_symbol == nil then
        print(comms.robot_send("error", "symbol: \"" .. chunk.symbol .. "\" does not possess a valid flag in the dictionary"))
        return false
    end
    --print(comms.robot_send("debug", "coords: " .. rel[1] .. ", " .. rel[2] .. ", " .. rel[3]))
    if type(translated_symbol) ~= "table" then
        --print(comms.robot_send("debug", "symbol: " .. chunk.symbol .. " -- " .. translated_symbol))
    else -- if it IS a table
        translated_symbol = deep_copy.copy(translated_symbol, ipairs) -- Yes I should do this in place, no I don't care for now

        local serial = serialize.serialize(translated_symbol, true)
        --print(comms.robot_send("debug", "symbol: " .. chunk.symbol .. " -- " .. serial))
    end

    local coords = deep_copy.copy(rel, ipairs)

    if type(translated_symbol) ~= "table" then
        return BuildInstruction:newBasic(coords, translated_symbol)
    end

    local instruction
    local first = table.remove(translated_symbol, 1) -- should be lable
    local peek = interpret_element(translated_symbol[1], 1, false)
    if peek == nil then
        local second = table.remove(translated_symbol, 1)
        if first == "nil" then first = nil end
        instruction = BuildInstruction:newBasic(coords, first, second)
    else
        instruction = BuildInstruction:newBasic(coords, first, nil)
    end

    for index, element in ipairs(translated_symbol) do
        local i_str, arg = interpret_element(element, index, true)
        instruction:addExtra(i_str, arg)
    end

    if instruction == nil then
        error(comms.robot_send("fatal", "SI:InstructionConstruction, no instruction was created!"))
    end
    return instruction
end

return SchematicInterface
