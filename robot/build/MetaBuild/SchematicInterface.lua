local serialize = require("serialization")
local io = require("io")

local comms = require("comms")
local deep_copy = require("deep_copy")

local MetaSchematic = require("build.MetaBuild.MetaSchematic")

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

function SchematicInterface:parseStringArr(string_array, square_index)
    local special_blocks = self.schematic:parseStringArr(string_array, square_index)
    if special_blocks ~= nil then self.special_blocks = special_blocks end

    if #self.schematic == 0 then print(comms.robot_send("error", "we ballsd up good :(")) end
end

function SchematicInterface:forceAdvanceHead()
    local b_stack = self.build_stack

    if b_stack.logical_z <= 7 then -- try and read every line
        b_stack.logical_x = 1
        b_stack.logical_z = b_stack.logical_z + 1
    elseif b_stack.logical_y <= #self.schematic then -- only then move-up in height
        b_stack.logical_x = 1
        b_stack.logical_z = 1
        b_stack.logical_y = b_stack.logical_y + 1
    else -- we can only assume there is nothing left to process, let's mark ourself as built
        return true
    end

    return false -- aka continue
end

-- chunk.dist && chunk.symbol
function SchematicInterface:doBuild()
    local b_stack = self.build_stack

    --[[local print_a = serialize.serialize(b_stack, true)
    print(comms.robot_send("debug", "b_stack is: \n" .. print_a))

    local print_schematic = serialize.serialize(self.schematic, true)
    print(comms.robot_send("debug", "self.schematic is: \n" .. print_a))--]]

    --local chunk = self.schematic.lookUp(b_stack.logical_y, b_stack.logical_z, b_stack.logical_x)

    local chunk = nil
    local line = nil
    local square = nil

    square = self.schematic[b_stack.logical_y]
    if square == nil then goto very_funny end

    line = square[b_stack.logical_z]
    if line == nil then goto very_funny end

    chunk = line[b_stack.logical_x]

    ::very_funny::
    if chunk == nil then 
        if self:forceAdvanceHead() then
            return true, "done"
        end
        return self:doBuild()
    end
    if chunk.symbol == '*' then -- or other such special characters
        b_stack.logical_x = b_stack.logical_x + 1
        return self:doBuild()
    end

    b_stack.logical_x = b_stack.logical_x + 1 -- prepare the advance to next column element

    local rel = {0, 0, 0}
    rel[3] = self.origin_block[3] + (b_stack.logical_y - 1) -- (-1) compensates for array access being on 1
    rel[2] = self.origin_block[2] + (b_stack.logical_z - 1)
    rel[1] = self.origin_block[1] + chunk.x

    local translated_symbol = self.dictionary[chunk.symbol]
    if translated_symbol == nil then
        print(comms.robot_send("error", "symbol: \"" .. chunk.symbol .. "\" does not possess a valid flag in the dictionary"))
        return false
    end
    print(comms.robot_send("debug", "coords: " .. rel[1] .. ", " .. rel[2] .. ", " .. rel[3]))
    print(comms.robot_send("debug", "symbol: " .. chunk.symbol .. " -- " .. translated_symbol))
    io.read()

    local coords = deep_copy.copy(rel, ipairs)
    return true, "continue", coords, translated_symbol
end

return SchematicInterface
