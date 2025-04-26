local math = require("math")
local comms = require("comms")

-- Chunks are 16 by 16, roads includes they become 14 by 14, this is then sub devided into 4 - 7 by 7 sub-chu    nks
-- Builds (tm) will occupy marked sub-chunks inside a chunk instead of arbitrary rectangles, for ease of navi    gation
-- and they'll always be accessed through the "outside", this is to say, through the "road-blocks/lines"
-- if we want to get fancy, we can mark-down door locations and shit, so that we can have walls and enclosed     buildigs etc

-- Meta schematic chunk
local MSChunk = {dist = 0, symbol = "0"}
MSChunk.__index = MSChunk

function MSChunk:zeroed()
    local obj = {}
    setmetatable(obj, self)
    return obj
end
function MSChunk:new(dist, symbol)
    local obj = self.zeroed()
    obj.dist = dist
    obj.symbol = symbol
end


-- lines into squares into square_cuboids (the meta_schematic itself)
-- acts as a sort of multi-dimensional queue
local MetaSchematic = {} -- Cuboid (top-level)
MetaSchematic[1] = {} -- 1st square
MetaSchematic[1][1] = {} -- 1st line
-- MetaSchematic[1][1][1] -- 1st chunk of 1st line
MetaSchematic.__index = MetaSchematic

function MetaSchematic:new()
    local obj = {}
    setmetatable(obj, self)
    return obj
end

local function return_or_init_table_table(tbl, index) -- for maybe nils
    if tbl[index] ~= nil then
        return tbl[index]
    end

    tbl[index] = {}
    return tbl[index] -- returns ref to inner table
end

-- I hope no return needed, we're modifying self (a ref) anyhow
-- 2d slice of height 1, where 1 string is 1 line (x,z)
function MetaSchematic:parseStringArr(string_array, square_index) 
    local square = return_or_init_table_table(self, square_index)

    --local line = nil
    local max_line = 0

    for _, str in ipairs(string_array) do
        local dist = 0
        local line_index = 1

        for char in str:gmatch"." do
            max_line = math.max(max_line, line_index)
            local line = return_or_init_table_table(square, line_index)

            if char != '-' then
                local new_obj = MSChunk::new(dist, char)
                table.insert(line, new_obj)
            end -- if

            line_index = line_index + 1
            dist = dist + 1
        end -- for char
        square_index = square_index + 1
    end -- for str
end

-- adds bounding box and ref to child.dictionary to MetaSchematic
local MetaMetaSchematic = {
    schematic = MetaSchematic:new(),
    iter_init_func = nil, -- function that mutes the schematic on init, for a lot of fun! Implements iteration through __pairs()
    dictionary = nil, -- {}
    origin_block = {
        x = 0,
        z = 0,
        y = 0
    }
}

MetaMetaSchematic.__index = MetaMetaSchematic
function MetaMetaSchematic:new()
    local obj = {}

    setmetatable(obj, self)
    return obj
end

function MetaMetaSchematic:parseStringArr(string_array, square_index)
    self.schematic.parseStringArr(string_array, square_index)
end

local Module = {
    is_nil = true,
    primitive = {},

    door_info = { MetaDoorInfo:zeroed() },
    schematic = MetaMetaSchematic:new()
}
Module.__index = Module

function Module:new()
    local obj = {}

    setmetatable(obj, self)
    return obj
end

function Module:init_primitive()
    self.primitive.parent = self
    self.
end

function Module:require(name)
    self.primitive = dofile("build." .. name)
    self.init_primitive()

    local human_read = self.primitive.human_readable
    local schematic = self.schematic

    self.checkHumanMap(human_read, name)
    if schematic.iter_init_func == nil then
        for index = 1, #human_read, 1 do
            schematic.parseStringArr(human_read, index)
        end
    else
        for index, human_read_obj in schematic.iter_init_func(human_read) do
            schematic.parseStringArr(human_read_obj, index)
        end
    end
end

function Module:getName()
    return primitive.name 
end

function Module:checkHumanMap(map, name)
    if #map > 7 then
        comms.robot_send("error", "In human map -- Build: \"" .. name .. "\" -- Too Many Lines!")
        return -1
    end

    for index, line in ipairs(map) do
        if string.len(line) > 7 then
            comms.robot_send("error", "In human map -- Build: \"" .. name .. "\" -- Line: \"" .. tostring(index) .. "\" -- Line is way too big!")
            return index
        end
    end
    return 0
end


return Module
