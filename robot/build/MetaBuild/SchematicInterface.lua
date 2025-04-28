local MetaSchematic, SpecialBlockEnum = require("build.MetaBuild.MetaSchematic")


-- adds bounding box and ref to child.dictionary to MetaSchematic
local SchematicInterface = {
    schematic = MetaSchematic:new(),
    iter_init_func = nil, -- function that mutes the schematic on init, for a lot of fun! Implements iteration through __pairs()
    dictionary = nil, -- {}
    origin_block = {
        x = 0,
        z = 0,
        y = 0
    }
    special_blocks = {}
}

SchematicInterface.__index = MetaMetaSchematic
function SchematicInterface:new()
    local obj = {}

    setmetatable(obj, self)
    return obj
end

function SchematicInterface:parseStringArr(string_array, square_index)
    local special_blocks = self.schematic.parseStringArr(string_array, square_index)
    if special_blocks ~= nil then self.special_blocks = special_blocks end
end

return SchematicInterface
