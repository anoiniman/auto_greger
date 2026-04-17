-- You hook this up to anything you want to register as an external inventory
local deep_copy = require("deep_copy")
local comms = require("comms")

-- local MetaLedger = require("inventory.MetaLedger")
local item_helper = require("inventory.__h_Item")
local map = require("nav_module.map_obj")
-- local inv = require("inventory.inv_obj")

local einv_item = require("inventory.eInvItem")
local vinv_helper = require("inventory.VirtualInventory")
local cvinv_helper = require("inventory.CompressedVinventory")
local meta_build = require("build.MetaBuild")

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
    
    item_defs: {eInvItem}
    storage: boolean
    long_term_storage: boolean

    ledger: CompressedVinventory
    symbol: string
    special_block_index: integer
end
local record module end

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
        print(comms.robot_send("stack", debug.traceback()))
    end

    local new: ExternalInventory = {
        parent_build = parent_build,

        item_defs = item_defs,

        ledger = cvinv_helper.compress(vinv_helper.new(get_storage_size(storage_type))),
        symbol = symbol,
        special_block_index = index
    }
    if not is_cache then
        inv.register_ledger(new) -- important
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

function module.get_data(einv: ExternalInventory): {any}
    local vinv = cvinv_helper.uncompress(einv.ledger)
    local save_ledger = vinv_helper.get_data(vinv)
    local parent_chunk: string | Pos2D = "nil"
    local what_quad: string | integer = "nil"

    if einv.parent_build ~= nil then
        parent_chunk = einv.parent_build.what_chunk
        what_quad = einv.parent_build.quad
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

function module.reinstantiate(big_table: {any}): ExternalInventory
    local serial_ledger = big_table[6]
    local real_ledger = vinv_helper.reinstantiate(serial_ledger)

    local parent_chunk = big_table[1] as Pos2D
    local what_quad = big_table[2] as integer
    local real_build: Build = nil

    if big_table[1] ~= "nil" then
        real_build = map.get_build_ref(parent_chunk, what_quad)
    end

    local item_defs = big_table[3] as {eInvItem}
    local storage = big_table[4] as boolean
    local long_term_storage = big_table[5] as boolean

    local symbol = big_table[7] as SpecialSymbol
    local sp_index = big_table[8] as integer

    local new: ExternalInventory = {}
    new.parent_build = real_build
    new.ledger = real_ledger

    if item_defs == "nil" then item_defs = nil end
    new.item_defs = item_defs

    new.storage = storage
    new.long_term_storage = long_term_storage
    new.symbol = symbol
    new.special_block_index = sp_index

    return new
end

function module.get_distance(einv: ExternalInventory): integer
    return meta_build.parent_build.getDistToSpecial(einv.parent_build, einv.symbol, einv.special_block_index)
end

function module.get_coords(einv: ExternalInventory): Pos3D
    return meta_build.get_special_coords(einv.parent_build, einv.symbol, einv.special_block_index)
end

function module.get_quad_num(einv: ExternalInventory): integer
    local chunk = einv.parent_build.what_chunk
    local doors = einv.parent_build.doors
    local quad_num = map.find_quad(chunk, doors).quad
    if quad_num == nil then
        print(comms.robot_send("warning", "MetaExternalInventory, was unable to getQuadNum?!"))
        quad_num = -1
    end

    return quad_num
end

function module.get_chunk(einv: ExternalInventory): Pos2D
    return COPY(einv.parent_build.what_chunk)
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

    return function()
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
    local new = einv:new(item_defs, parent_build, false, symbol, index, storage_type)
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

    local new = einv:new(item_defs, parent_build, is_cache, symbol, index, storage_type)
    new.storage = false
    return new
end

global EInvModuleMetaType = module
return module
