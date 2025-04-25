-- coords are chunk_rel
local MetaDoorInfo = {x = 0, y = 0, len = 0}
MetaDoorInfo.__index = MetaDoorInfo

function MetaDoorInfo:zeroed()
    local obj = {}

    setmetatable(obj, self)
    return obj
end

-- Chunks are 16 by 16, roads includes they become 14 by 14, this is then sub devided into 4 - 7 by 7 sub-chu    nks
-- Builds (tm) will occupy marked sub-chunks inside a chunk instead of arbitrary rectangles, for ease of navi    gation
-- and they'll always be accessed through the "outside", this is to say, through the "road-blocks/lines"
-- if we want to get fancy, we can mark-down door locations and shit, so that we can have walls and enclosed     buildigs etc

local Module = {
    is_nil = true
    door_info = { MetaDoorInfo:zeroed() }
    primitive = {},
}
Module.__index = Module

function Module:new()
    local obj = {}

    setmetatable(obj, self)
    return obj
end

function Module:require(name)
    self.primitive = require("build." .. name)
end

function Module:getName()
    return primitive.name 
end


return Module
