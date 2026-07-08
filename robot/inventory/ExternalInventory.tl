-- You hook this up to anything you want to register as an external inventory
require("deep_copy")
local comms = require("comms")

-- local MetaLedger = require("inventory.MetaLedger")
local item_helper = require("inventory.__h_Item")
local map = require("nav_module.map_obj")
-- local inv = require("inventory.inv_obj")

require("inventory.eInvItem")
local vinv_helper = require("inventory.VirtualInventory")
local cvinv_helper = require("inventory.CompressedVinventory")
local build_helper = require("build.MetaBuild")
require("inventory.__h_ExternalInventory")

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

local record module end
local external_inventories: {string : {ExternalInventory}} = {}

function module.get_external_inv_arr(): {string : {ExternalInventory}}
    return external_inventories
end

function module.register_ledger(fat_ledger: ExternalInventory)
    if fat_ledger.parent_build == nil then return end

    local build = fat_ledger.parent_build as Build
    local build_name = build.name
    if build_name == nil then print(comms.send_unexpected()); return end

    if external_inventories[build_name] == nil then
        external_inventories[build_name] = {fat_ledger}
        return
    end
    table.insert(external_inventories[build_name], fat_ledger)
end

function module.new_cache(storage_type?: StorageType): ExternalInventory
    return {
        is_cache = true,
        ledger = cvinv_helper.compress(vinv_helper.new(get_storage_size(storage_type))),
    }
end

function module.new(
    item_defs: {eInvItem},
    parent_build: Build | nil,
    is_cache: boolean,
    symbol: SpecialSymbol,
    index: integer,
    storage_type: StorageType
): ExternalInventory
    if not is_cache and parent_build == nil then
        print(comms.robot_send("error", "MetaExtInventory, parent_build is nil"))
        print(comms.robot_send("error", debug.traceback()))
    end

    local new: ExternalInventory = {
        parent_build = parent_build,

        item_defs = item_defs,

        ledger = cvinv_helper.compress(vinv_helper.new(get_storage_size(storage_type))),
        symbol = symbol,
        special_block_index = index
    }
    if not is_cache then
        module.register_ledger(new) 
    end
    return new
end

--[[ local function find_function(table, sindex) -- has a tendency to go on ininite loops! (yay)
    for key, value in pairs(table) do
        if type(value) == "table" then
            find_function(value, string.format("%s-%s", sindex, tostring(key)))
        elseif type(value) == "function" then
            print("We found a function on: " .. string.format("%s-%s", sindex, tostring(key)))
            io.read()
        end
    end
end --]]

local type SaveTable = {
    string | ChunkCoord, string | integer, {eInvItem}, boolean, boolean, {string | integer}, SpecialSymbol, integer
}
function module.get_data(einv: ExternalInventory): SaveTable
    local vinv = cvinv_helper.uncompress(einv.ledger)
    local save_ledger = vinv_helper.get_data(vinv)
    local parent_chunk: string | ChunkCoord = "nil"
    local what_quad: string | integer = "nil"

    local build = einv.parent_build
    if build is Build then
        parent_chunk = build.chunk
        what_quad = build.quad
    end

    local big_table = {
        parent_chunk,               -- 1
        what_quad,
        COPY(einv.item_defs),       -- 3
        einv.storage,               -- 4
        einv.long_term_storage,     -- 5

        save_ledger,
        einv.symbol,
        einv.special_block_index,   -- 8
    }
    --[[for index, value in ipairs(big_table) do
        if type(value) == "table" then
            find_function(value, string.format("%d", index))
        end
    end--]]

    return big_table
end

function module.reinstantiate(big_table: SaveTable): ExternalInventory
    local serial_ledger = big_table[6]
    local real_ledger = vinv_helper.reinstantiate(serial_ledger)

    local parent_chunk = big_table[1]
    local what_quad = big_table[2]
    local real_build: Build = nil

    if big_table[1] ~= "nil" then
        real_build = map.get_build_ref(parent_chunk as ChunkCoord, what_quad as integer)
    end

    local item_defs = big_table[3]
    local storage = big_table[4]
    local long_term_storage = big_table[5]

    local symbol = big_table[7]
    local sp_index = big_table[8]

    local new: ExternalInventory = {}
    new.parent_build = real_build
    new.ledger = cvinv_helper.compress(real_ledger)

    new.item_defs = item_defs

    new.storage = storage
    new.long_term_storage = long_term_storage
    new.symbol = symbol
    new.special_block_index = sp_index

    return new
end

function module.get_distance(einv: ExternalInventory): integer
    if einv.parent_build == nil then
        print(comms.robot_send("warning", "MEI attempted to get distance of einv with no parent_build"))
        return math.maxinteger
    end
    local build = einv.parent_build as Build
    return build_helper.get_dist_to_special(build, einv.symbol, einv.special_block_index)
end

function module.get_coords(einv: ExternalInventory): Pos3D
    return build_helper.get_special_coords(einv.parent_build, einv.symbol, einv.special_block_index)
end

function module.get_quad_num(einv: ExternalInventory): integer
    if einv.parent_build == nil then
        print(comms.robot_send("warning", "MEI attempted to get quad_num of einv with no parent_build"))
        return -1
    end
    local build = einv.parent_build as Build
    return build.quad
end

function module.get_chunk(einv: ExternalInventory): ChunkCoord
    if einv.parent_build == nil then
        print(comms.robot_send("warning", "MEI attempted to get chunk of einv with no parent_build"))
        return {-111111111111, -11111111111}
    end
    local build = einv.parent_build as Build
    return COPY(build.chunk)
end

function module.can_add(einv: ExternalInventory, other_item: ItemDefinition): boolean
    if einv.item_defs == nil then
        print(comms.robot_send("warning", "item_defs == nil"))
        return false
    end

    for _, m_item in ipairs(einv.item_defs) do
        if item_helper.item_def_wildcard_eq(m_item.item, other_item) then return true end
    end
    return false
end

-- call this after getting nil from canAdd
function module.can_any(einv: ExternalInventory): boolean
    if einv.item_defs == nil then
        return false
    end

    for _, m_item in ipairs(einv.item_defs) do
        if tostring(m_item.item.name) == "any:any" then return true end
    end
    return false
end

function module.item_def_iter(einv: ExternalInventory): function(): integer | nil, eInvItem | nil
    local iteration = 0

    return function(): integer | nil, eInvItem | nil
        iteration = iteration + 1
        local item_def = einv.item_defs[iteration]
        if item_def == nil then return nil, nil end

        return iteration, item_def
    end
end


function module.new_long_term_storage(
    item_defs: {eInvItem},
    parent_build: Build,
    symbol: SpecialSymbol,
    index: integer,
    storage_type: StorageType
): ExternalInventory
    local new = module.new(item_defs, parent_build, false, symbol, index, storage_type)
    new.storage = true
    new.long_term_storage = true
    return new
end

-- this is where the robot dumps its inventory temporarily in order to work a building, basically a fat ledger
function module.new_einv_cache(storage_type?: StorageType): ExternalInventory
    local new = module.new_cache(storage_type)
    new.storage = true
    return new
end

function module.new_storage(
    item_defs: {eInvItem},
    parent_build: Build,
    symbol: SpecialSymbol,
    index: integer,
    storage_type: StorageType
): ExternalInventory
    local new = module.new(item_defs, parent_build, false, symbol, index, storage_type)
    new.storage = true
    return new
end

function module.new_machine(
    item_defs: {eInvItem},
    parent_build: Build,
    symbol: SpecialSymbol,
    index: integer,
    storage_type: StorageType,
    extern: boolean
): ExternalInventory
    local is_cache = false
    if extern == nil or extern == false then is_cache = true end

    local new = module.new(item_defs, parent_build, is_cache, symbol, index, storage_type)
    new.storage = false
    return new
end

-- global EInvModuleMetaType = module
return module
