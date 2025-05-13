local comms = require("comms")
local deep_copy = require("deep_copy")

local MetaSchematic = require("build.MetaBuild.MetaSchematic")

local rel_positions = {0, 0, 0} -- x, z, y
function rel_positions:new()
    return deep_copy.copy(self, ipairs)
end

local BuildStack = { -- reading head maxxed printer pilled state machine adjacent
    rel = rel_positions:new(),

    logical_x = 0,
    logical_z = 0,
    logical_y = 0
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

function SchematicInterface:parseStringArr(string_array, square_index)
    local special_blocks = self.schematic:parseStringArr(string_array, square_index)
    if special_blocks ~= nil then self.special_blocks = special_blocks end

    if #self.schematic == 0 then print(comms.robot_send("error", "we ballsd up good :(")) end
end

function SchematicInterface:forceAdvanceHead()
    local b_stack = self.build_stack

    if b_stack.logical_z < 7 then -- try and read every line
        b_stack.rel[1] = 0 -- Very Important to reset the rel_x column now that we moved to the next line
        b_stack.logical_x = 0
        b_stack.logical_z = b_stack.logical_z + 1
    elseif b_stack.logical_y < #self.schematic then -- only then move-up in height
        b_stack.logical_x = 0
        b_stack.logical_z = 0
        b_stack.logical_y = b_stack.logical_y + 1
    else -- we can only assume there is nothing left to process, let's mark ourself as built
        return true
    end

    return false
end

-- chunk.dist && chunk.symbol
function SchematicInterface:doBuild()
    b_stack = self.build_stack
    --local chunk = self.schematic.lookUp(b_stack.logical_y, b_stack.logical_z, b_stack.logical_x)
    local chunk = self.schematic[b_stack.logical_y][b_stack.logical_z][b_stack.logical_x]
    if chunk == nil then 
        if self:forceAdvanceHead() then
            return true, "done"
        end
        return self:doBuild()
    end
    b_stack.logical_x = b_stack.logical_x + 1 -- prepare the advance to next column element

    local rel = b_stack.rel

    rel[3] = b_stack.logical_y
    rel[2] = b_stack.logical_z
    rel[1] = rel[1] + chunk.dist

    local translated_symbol = self.dictionary[chunk.symbol]
    if translated_symbol == nil then
        print(comms.send("error", "symbol: \"" .. chunk.symbol .. "\" does not possess a valid flag in the dictionary"))
        return false
    end

    local coords = deep_copy.copy(rel, ipairs)
    return true, "continue", coords, translated_symbol
end

return SchematicInterface
