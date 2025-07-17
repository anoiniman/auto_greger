-- luacheck: globals EMPTY_STRING
local deep_copy = require("deep_copy")
local comms = require("comms")

-- local SpecialDefinition = require("inventory.SpecialDefinition")
local item_bucket = require("inventory.item_buckets")

-- It is assumed this will never be used for the robots own inventory

-- this will be a virtual inventory without fixed buckets and initialised lazily, achieving good item compression
-- the format now still 3 based {lable, name, quantity}

local VirtualInventory = require("inventory.VirtualInventory")
local Module = VirtualInventory:new(-1)

-- (new) function is unchanged from VirtualInventory (except for the fact that the table is not pre-inited)
function Module:new(max_size)
    local new = deep_copy(self, pairs)
    new.max_size = max_size
    new.table_size = 0 * 3 -- :)
    new.inv_type = "ledger"

    return new
end

function Module:findIndicesPermissive(lable, name)
    if lable == nil then lable = "" end

    local index_table = {}
    for index = 1, #self.inv_table, 3 do
        if lable ~= self.inv_table[index] and name ~= self.inv_table[index + 1] then goto continue end

        table.insert(index_table, index)
        ::continue::
    end

    if #index_table == 0 then return nil end
    return index_table
end

function Module:findIndex(lable, name)
    if lable == nil then error(comms.robot_send("fatal", "lable cannot be nil!")) end

    local something_found = -1
    for index = 1, #self.inv_table, 3 do
        if not self:checkEntry(lable, name, index) then goto continue end

        something_found = index -- the big thing
        if true then break end
        ::continue::
    end

    return something_found
end

-- special definitions will not be stored per se (they'll not be treated in a special manner)
function Module:addOrCreate(lable, name, to_be_added)
    name = item_bucket.identify(name, lable)

    local index = self:findIndex(lable, name)
    if index ~= -1 then
        self.inv_table[index + 2] = self.inv_table[index + 2] + to_be_added
        return
    end -- else we need to add another entry

    local new_offset = #self.inv_table + 1
    self.inv_table[new_offset] = lable
    self.inv_table[new_offset + 1] = name
    self.inv_table[new_offset + 2] = to_be_added
end

function Module:subtract(lable, name, to_remove)
    name = item_bucket.identify(name, lable)

    local index = self:findIndex(lable, name)
    if index == -1 then
        comms.robot_send("error", "Attempted to remove something that didn't exist")
        return
    end
    self.inv_table[index + 2] = self.inv_table[index + 2] - to_remove
    if self.inv_table[index + 2] == 0 then -- we'll have to remove the entry and compact the table
        -- everything to the right of this entry needs to be "pulled down" three indecis
       for i = index + 3, #self.inv_table, 3 do
            self.inv_table[i - 3] = self.inv_table[i]
            self.inv_table[i + 1 - 3] = self.inv_table[i + 1]
            self.inv_table[i + 2 - 3] = self.inv_table[i + 2]
       end
       -- and then the last entry needs to get le deleted
       local le_end = #self.inv_table
       self.inv_table[le_end] = nil
       self.inv_table[le_end - 1] = nil
       self.inv_table[le_end - 2] = nil
    elseif self.inv_table[index + 2] < 0 then error(comms.robot_send("fatal", "assert failed")) end
end

function Module:howMany(lable, name)
    name = item_bucket.identify(name, lable)
    local index = self:findIndex(lable, name)
    if index == -1 then return 0 end

    return self.inv_table[index + 2]
end

-- returns table of lable-quantity pairs (ok for lable to be nil)
function Module:howManyPermissive(lable, name)
    name = item_bucket.identify(name, lable)
    local indices = self:findIndicesPermissive(lable, name)
    if indices == nil then return 0 end

    local count = 0
    for _, tbl_index in ipairs(indices) do
        count = self.inv_table[tbl_index + 2] + count
    end
    return count
end

-- luacheck: no unused args
function Module:forceUpdateInternal()
    error(comms.robot_send("fatal", "this is not supposed to be called for a ledger, only vinv!"))
end

return Module
