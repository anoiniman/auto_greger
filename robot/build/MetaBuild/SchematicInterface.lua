local comms = require("comms")
local deep_copy = require("deep_copy")

local MetaSchematic, SpecialBlockEnum = require("build.MetaBuild.MetaSchematic")

local BuildStack = { -- reading head maxxed printer pilled state machine adjacent
    rel_x = 0,
    rel_z = 0,
    height = 0,

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
    }
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
            -- TODO
            print(comms.robot_send("error", "TODO 012"))
        end
    end
end

return SchematicInterface
