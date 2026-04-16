-- You hook this up to anything you want to register as an external inventory
local deep_copy = require("deep_copy")
local comms = require("comms")

-- local MetaLedger = require("inventory.MetaLedger")
require("inventory.__h_Item")
local map = require("nav_module.map_obj")
local inv = require("inventory.inv_obj")

local vinv_helper = require("inventory.VirtualInventory")
local cvinv_helper = require("inventory.CompressedVinventory")

local record meta_item end

-- as obvious, if it is an item inside a static storage it has no output
-- permissive matters no more, because to be permissive we simple have to have a "name with no lable" association,
local record MetaItem
    item: ItemDefinition
    output: ItemDefinition
end

function meta_item.new(item: ItemDefinition, output: ItemDefinition): MetaItem
    return {
        item = item,
        output = output
    }
end

local enum StorageType
    "chest"
    "double_chest"
    "iron_chest"

    "furnace"
    "coke_oven"
end

local function get_storage_size(storage_type?: StorageType): integer
    if storage_type == nil or storage_type == "chest" then
        return 27
    elseif storage_type == "double_chest" then
        return 54
    elseif storage_type == "furnace" then
        return 3
    elseif storage_type == "coke_oven" then
        return 2
    elseif storage_type == "iron_chest" then
        error(comms.robot_send("fatal", "unimplemented"))
    end
    error(comms.robot_send("fatal", "unimplemented"))
end

-- storage compared to being a production inventory that consumes items
-- long_term_storage compared to being an inventory associated with this 1 specific building
global interface ExternalInventory
    parent_build: Build | nil
    
    item_defs: MetaItem
    storage: boolean | nil
    long_term_storage: boolean | nil

    ledger: CompressedVinventory
    symbol: string
    special_block_index: integer
end
local record module end

function module.new(
    item_defs: {ItemDefinition},
    parent_build: Build | nil,
    is_cache: boolean,
    symbol: SpecialSymbol,
    index: integer,
    storage_type: StorageType
): ExternalInventory
    if not is_cache and parent_build == nil then
        print(comms.robot_send("error", "MetaExtInventory, parent_build is nil"))
        print(comms.robot_send("stack", debug.traceback()))
    end

    local new: ExternalInventory = {
        parent_build = parent_build,

        item_defs = item_defs,

        ledger = cvinv_helper.compress(vinv_helper.new(storage_size)),
        symbol = symbol 
        special_block_index = index
    }
    if not is_cache then
        inv.register_ledger(new) -- important
    end
    return new
end

local function find_function(table, sindex) -- has a tendency to go on ininite loops! (yay)
    for key, value in pairs(table) do
        if type(value) == "table" then
            find_function(value, string.format("%s-%s", sindex, tostring(key)))
        elseif type(value) == "function" then
            print("We found a function on: " .. string.format("%s-%s", sindex, tostring(key)))
            io.read()
        end
    end
end

function Module:getData()
    local save_ledger = self.ledger:getData()
    local parent_chunk = "nil"
    local what_quad = "nil"

    if self.parent_build ~= nil then
        parent_chunk = self.parent_build.what_chunk
        local door_info = self.parent_build.doors
        what_quad = map.find_quad(parent_chunk, door_info).quad
    end

    local big_table = {
        parent_chunk,               -- 1
        what_quad,
        deep_copy.copy_no_functions(self.item_defs),  -- 3
        self.storage,               -- 4
        self.long_term_storage,     -- 5

        save_ledger,
        self.symbol,
        self.special_block_index,    -- 8
    }
    --[[for index, value in ipairs(big_table) do
        if type(value) == "table" then
            find_function(value, string.format("%d", index))
        end
    end--]]

    return big_table
end

function Module:reInstantiate(big_table)
    local serial_ledger = big_table[6]
    local real_ledger = VirtualInventory:reInstantiate(serial_ledger)

    local parent_chunk = big_table[1]
    local what_quad = big_table[2]
    local real_build = nil

    if big_table[1] ~= "nil" then
        real_build = map.get_chunk(parent_chunk):getBuildRef(what_quad)
    end

    local no_func_item_defs = big_table[3]
    local storage = big_table[4]
    local long_term_storage = big_table[5]

    local symbol = big_table[7]
    local sp_index = big_table[8]

    local new = deep_copy.copy(self, pairs)
    new.parent_build = real_build
    new.ledger = real_ledger


    new.item_defs = {}
    if no_func_item_defs ~= nil then
        for _, raw in ipairs(no_func_item_defs) do
            local new_def = MetaItem:new(raw.name, raw.lable, raw.permissive, raw.output)
            table.insert(new.item_defs, new_def)
        end
    else new.item_defs = nil end

    new.storage = storage
    new.long_term_storage = long_term_storage
    new.symbol = symbol
    new.special_block_index = sp_index

    return new
end

function Module:getDistance()
    return self.parent_build:getDistToSpecial(self.symbol, self.special_block_index)
end

function Module:getCoords()
    return self.parent_build:getSpecialCoords(self.symbol, self.special_block_index)
end


function Module:getQuadNum()
    local chunk = self.parent_build.what_chunk
    local doors = self.parent_build.doors
    local quad_num = map.find_quad(chunk, doors).quad
    if quad_num == nil then
        print(comms.robot_send("warning", "MetaExternalInventory, was unable to getQuadNum?!"))
        quad_num = -1
    end

    return quad_num
end

function Module:getChunk()
    return deep_copy.copy(self.parent_build.what_chunk)
end


function Module:canAdd(lable, name)
    if self.item_defs == nil then
        print(comms.robot_send("warning", "item_defs == nil"))
        return false
    end

    -- faking hell man, I should've really had made a standardized way to do this comparisions
    -- TODO for version 2.0 I guess
    for _, meta_item in ipairs(self.item_defs) do
        if meta_item.name == name and meta_item.lable == lable then return true
        elseif meta_item.name == nil and meta_item.lable == lable then return true
        elseif meta_item.name == name and meta_item.lable == nil then return true end
        -- elseif meta_item.name == "any:any" then return true end
    end
    return false
end

-- call this after getting nil from canAdd
function Module:canAny()
    if self.item_defs == nil then
        return false
    end

    for _, meta_item in ipairs(self.item_defs) do
        if meta_item.name == "any:any" then return true end
    end
    return false
end

function Module:itemDefIter()
    local iteration = 0

    -- checks if it is not a plain def (aka, if item_defs is a table, not a just a raw item_def)
    if self.item_defs["permissive"] == nil then
        return function()
            iteration = iteration + 1
            if iteration > 1 then return nil end

            return 1, self.item_defs
        end
    end

    return function()
        iteration = iteration + 1
        local item_def = self.item_defs[iteration]
        if item_def == nil then return nil end

        return iteration, item_def
    end
end


function Module:newLongTermStorage(item_defs, parent_build, symbol, index, storage_type)
    local new = self:new(item_defs, parent_build, false, symbol, index, storage_type)
    new.storage = true
    new.long_term_storage = true
    return new
end

-- this is where the robot dumps its inventory temporarily in order to work a building, basically a fat ledger
function Module:newSelfCache()
    local new = self:new(nil, nil, true)
    new.storage = true
    return new
end

function Module:newStorage(item_defs, parent_build, symbol, index, storage_type)
    local new = self:new(item_defs, parent_build, false, symbol, index, storage_type)
    new.storage = true
    return new
end

function Module:newMachine(item_defs, parent_build, symbol, index, storage_type, extern)
    local is_cache = false
    if extern == nil or extern == false then is_cache = true end

    local new = self:new(item_defs, parent_build, is_cache, symbol, index, storage_type)
    new.storage = false
    return new
end

return {Module, MetaItem}
