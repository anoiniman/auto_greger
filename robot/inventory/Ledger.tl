-- luacheck: globals EMPTY_STRING
local comms = require("comms")

-- local SpecialDefinition = require("inventory.SpecialDefinition")
local item_bucket = require("inventory.item_buckets")

local record module end

-- It is assumed this will never be used for the robots own inventory

-- this will be a virtual inventory without fixed buckets and initialised lazily, achieving good item compression
-- the format now still 3 based {lable, name, quantity}
-- This property also means that we'll not be tracking down index / 3 = slot.
-- We'll simply record how many of an item exist in an inventory, but now how many in each solt etc.
local vinv_helper = require("inventory.VirtualInventory")
local interface MetaLedger is VirtualInventory
where self.inv_type == "ledger"
    max_size: integer
end

-- (new) function is unchanged from VirtualInventory (except for the fact that the table is not pre-inited)
function module.new(max_size: integer): MetaLedger
    local new = vinv_helper.new(0) as MetaLedger
    new.max_size = max_size
    new.table_size = 0 * 3
    new.inv_type = "ledger"

    return new
end

function module.find_indices_permissive(ledger: MetaLedger, item: ItemDefinition): {integer}
    local index_table: {integer} = {}
    for index = 1, #ledger.inv_table, 3 do
        -- Until big structural changes do not change this for using item_helper.item_def_perm_eq
        -- local other_item = item_helper.new_item_definition(ledger.inv_table[index], ledger.inv_table[index + 1])
        if item.label ~= ledger.inv_table[index] and item.name ~= ledger.inv_table[index + 1] then goto continue end
        
        table.insert(index_table, index)
        ::continue::
    end
end

function module.find_index(ledger: MetaLedger, item: ItemDefinition): integer | integer
    if item.label == nil then error(comms.robot_send("fatal", "lable cannot be nil!")) end

    local something_found: integer | nil = nil
    for index = 1, #ledger.inv_table, 3 do
        if not vinv_helper.check_entry(ledger, item, index) then goto continue end
        
        something_found = index
        if true then break end
        ::continue::
    end

    return something_found
end

-- special definitions will not be stored per se (they'll not be treated in a special manner)
function module.add_or_create(ledger: MetaLedger, item: FullerDefinition)
    item = item_bucket.identify(item)

    local index = module.find_index(ledger, item)
    if index ~= -1 then
        ledger.inv_table[index + 2] = ledger.inv_table[index + 2] as integer + item.size
    end -- else we need to add another entry

    local new_offset = #ledger.inv_table + 1
    ledger.inv_table[new_offset] = item.label
    ledger.inv_table[new_offset + 1] = item.name
    ledger.inv_table[new_offset + 2] = item.size
end

function module.subtract(ledger: MetaLedger, item: FullerDefinition)
    item = item_bucket.identify(item)

    local index = module.find_index(ledger, item)
    if index == -1 then
        comms.robot_send("error", "Attempted to remove something that didn't exist")
        return
    end
    ledger.inv_table[index + 2] = ledger.inv_table[index + 2] as integer - item.size
    if ledger.inv_table[index + 2] == 0 then -- we'll have to remove the entry and compact the table
        -- everything to the right of this entry needs to be "pulled down" three indecis
       for i = index + 3, #ledger.inv_table, 3 do
            ledger.inv_table[i - 3] = ledger.inv_table[i] as string
            ledger.inv_table[i + 1 - 3] = ledger.inv_table[i + 1] as string
            ledger.inv_table[i + 2 - 3] = ledger.inv_table[i + 2] as integer
       end
       -- and then the last entry needs to get le deleted
       local le_end = #ledger.inv_table
       ledger.inv_table[le_end] = nil
       ledger.inv_table[le_end - 1] = nil
       ledger.inv_table[le_end - 2] = nil
    elseif (ledger.inv_table[index + 2] as integer) < 0 then error(comms.robot_send("fatal", "assert failed")) end
end

function module.how_many(ledger: MetaLedger, item: ItemDefinition): integer
    item = item_bucket.identify(item)
    local index = module.find_index(ledger, item)
    if index == -1 then return 0 end

    return ledger.inv_table[index + 2] as integer
end

-- returns table of lable-quantity pairs (ok for lable to be nil)
function module.how_many_permissive(ledger: MetaLedger, item: ItemDefinition): integer
    item = item_bucket.identify(item)
    local indices = module.find_indices_permissive(ledger, item)
    if indices == nil then return 0 end

    local count = 0
    for _, tbl_index in ipairs(indices) do
        count = ledger.inv_table[tbl_index + 2] as integer + count
    end
    return count
end

--[[function Module:forceUpdateInternal()
    error(comms.robot_send("fatal", "this is not supposed to be called for a ledger, only vinv!"))
end--]]

return module
