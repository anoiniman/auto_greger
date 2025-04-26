
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
}

SchematicInterface.__index = MetaMetaSchematic
function SchematicInterface:new()
    local obj = {}

    setmetatable(obj, self)
    return obj
end

function SchematicInterface:parseStringArr(string_array, square_index)
    self.schematic.parseStringArr(string_array, square_index)
end

return SchematicInterface
