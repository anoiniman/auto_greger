-- You hook this up to anything you want to register as an external inventory
local deep_copy = require("deep_copy")
local comms = require("comms")

-- local MetaLedger = require("inventory.MetaLedger")
local map = require("nav_module.map_obj")
local VirtualInventory = require("inventory.VirtualInventory")
local inv = require("inventory.inv_obj")

-- as obvious, if it is an item inside a static storage it has no output
-- permissive matters no more, because to be permissive we simple have to have a "name with no lable" association, but I guess it is important right now because some checks depend on this :tf:
local MetaItem = {
    name = nil,
    lable = nil,
    permissive = false,

    output = nil
}
function MetaItem:new(name, lable, permissive, output)
    local new = deep_copy.copy(self, pairs)
    new.name = name
    new.lable = lable
    new.permissive = permissive or false
    new.output = output

    return new
end

local function get_storage_size(storage_type)
    if storage_type == nil or storage_type == "chest" or storage_type == "normal_chest" then
        return 27
    elseif storage_type == "double_chest" then
        return 54
    elseif storage_type == "iron_chest" then
        error(comms.robot_send("fatal", "unimplemented"))
    else
        error(comms.robot_send("fatal", "unimplemented"))
    end
end

local Module = {
    parent_build = nil,

    item_defs = nil,
    storage = false, -- compared to being a production inventory that consumes items
    long_term_storage = false, -- compared to being an inventory associated with this 1 specific building

    ledger = nil,
    symbol = nil,
    special_block_index = nil,
}

function Module:new(item_defs, parent_build, is_cache, symbol, index, storage_type)
    if not is_cache and parent_build == nil then
        print(comms.robot_send("error", "MetaExtInventory, parent_build is nil"))
        print(comms.robot_send("stack", debug.traceback()))
    end

    local new = deep_copy.copy(self, pairs)
    new.item_defs = item_defs

    local storage_size = get_storage_size(storage_type)
    new.ledger = VirtualInventory:new(storage_size)     -- for now we'll do everything as a vinv to make things
                                                        -- easier for us. If we start running out of ram then woops
    new.parent_build = parent_build
    new.symbol = symbol
    new.special_block_index = index

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
    if self.item_defs == nil then -- we can add anything, I guess?
        return true 
    end

    -- faking hell man, I should've really had made a standardized way to do this comparisions
    -- TODO for version 2.0 I guess
    for _, meta_item in ipairs(self.item_defs) do
        if meta_item.name == name and meta_item.lable == lable then return true
        elseif meta_item.name == nil and meta_item.lable == lable then return true
        elseif meta_item.name == name and meta_item.lable == nil then return true
        elseif meta_item.name == "any:any" then return true end
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

function Module:newMachine(item_defs, parent_build, symbol, index, storage_type)
    local new = self:new(item_defs, parent_build, false, symbol, index, storage_type)
    new.storage = false
    return new
end

return {Module, MetaItem}
