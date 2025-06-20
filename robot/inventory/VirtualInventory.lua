-- WARNING, COLLISION RESOLUTION CODE IS UNTESTED, MIGHT NOT WORK
local component = require("component")
local sides_api = require("sides")

local deep_copy = require("deep_copy")
local comms = require("comms")
local search_table = require("search_i_table")

local bucket_funcs, _ = table.unpack(require("inventory.item_buckets"))
local inventory = component.getPrimary("inventory_controller")

-- luacheck: globals EMPTY_STRING
EMPTY_STRING = ""

local Module = {}

Module.inv_size = -1
Module.table_size = -1

-- We are going to be using a module 3 to determine trios of item_lable/item_name/quantity, and the floor div 3
-- of the array will be the select
Module.inv_table = {}

function Module:initTable() -- eager initialization
    for index = 1, self.table_size, 3 do
        self.inv_table[index] = EMPTY_STRING
        self.inv_table[index + 1] = EMPTY_STRING
        self.inv_table[index + 2] = 0
    end
end

-- internal, aka is this the robots own inventory?
function Module:new(inv_size)
    local new = deep_copy(self, pairs)
    new.inv_size = inv_size
    new.table_size = inv_size * 3
    new.inv_type = "virtual_inventory"

    new:initTable()
    return new
end

function Module:checkEntry(lable, name, at_index)
    local i_lable = self.inv_table[at_index]
    local i_name = self.inv_table[at_index + 1]
    return lable == i_lable and (name == "generic" or name == i_name)
end

function Module:checkEntryPermissive(_, name, at_index)
    local i_name = self.inv_table[at_index + 1]
    return name == "generic" or name == i_name
end

local function calc_add_to_stack(current, to_add)
    local naive_add = current + to_add
    local div = naive_add / 64
    if div == 0 then return to_add end -- we can add everything in, because the result is smaller than 1 stack

    local modulo = naive_add % 64
    if modulo == 0 then return to_add end -- this is just the right ammount to make 1 stack, add everything

    -- then we should add (64 - modulo) in order to make a full stack
    return 64 - modulo
end

function Module:addToEmpty(lable, name, to_be_added, forbidden_slots)
    for index = 1, self.table_size, 3 do
        local slot = (index + 2) / 3
        if search_table.ione(forbidden_slots, slot) then goto continue end
        if self.inv_table[index + 2] ~= 0 then goto continue end

        self.inv_table[index] = lable
        self.inv_table[index + 1] = name

        local cur_add = calc_add_to_stack(self.inv_table[index + 2], to_be_added)
        self.inv_table[index + 2] = cur_add
        to_be_added = to_be_added - cur_add

        if true then break end
        ::continue::
    end

    return to_be_added
end

-- if name is not provided, name is probably generic, if name is generic, it is accepted by any lable
function Module:addOrCreate(lable, name, to_be_added, forbidden_slots)
    name = bucket_funcs.identify(name, lable)

    -- do valid stack growth according to the rules of opencomputers (reduce left-first)
    for index = 1, self.table_size, 3 do
        local slot = (index + 2) / 3
        if search_table.ione(forbidden_slots, slot) then goto continue end
        if not self:checkEntry(lable, name, index) then goto continue end

        local current = self.inv_table[index + 2]
        if current == 64 then goto continue end -- stack is already full

        local cur_add = calc_add_to_stack(current, to_be_added)
        self.inv_table[index + 2] = current + cur_add
        if self.inv_table[index + 2] > 64 then error(comms.robot_send("fatal", "assert failed")) end

        to_be_added = to_be_added - cur_add
        if to_be_added == 0 then break end

        ::continue::
    end

    -- something might have remained, simply add to empty slot
    local remainder = self:addToEmpty(lable, name, to_be_added, forbidden_slots)
    if remainder > 0 then
        print(comms.robot_send("error", "remainder > 0, error in updating virtual inventory, inventory is prob full"))
    end
    return remainder
end

function Module:getAllSlots(lable, name)
    return self:getAllSlotsInternal(lable, name, self.checkEntry)
end

function Module:getAllSlotsPermissive(name)
    return self:getAllSlotsInternal(nil, name, self.checkEntryPermissive)
end

function Module:getAllSlotsInternal(lable, name, check_func)
    name = bucket_funcs.identify(name, lable)

    local slot_table = {}
    for index = 1, self.table_size, 3 do
        if not check_func(self, lable, name, index) then
            goto continue
        end

        local slot = (index + 2) / 3
        local new_entry = {slot, self.inv_table[index + 2]} -- slot, quantity
        table.insert(slot_table, new_entry)

        ::continue::
    end
    if #slot_table == 0 then return nil end
    return slot_table
end

function Module:howMany(lable, name)
    local slot_table = self:getAllSlots(lable, name)

    local total = 0
    for _, element in ipairs(slot_table) do
        -- local slot = element[1]
        local quantity = element[2]
        total = total + quantity
    end
    return total
end

function Module:howManySlot(slot)
    local index = (slot * 3) - 2
    return self.inv_table[index + 2]
end

function Module:getSmallestSlot(lable, name) -- returns a slot num
    name = bucket_funcs.identify(name, lable)

    local slot_table = self:getAllSlots(lable, name)
    if slot_table == nil then return nil end

    local smallest_slot = -1
    local smallest_stack = 65
    for _, inner_table in ipairs(slot_table) do
        local slot = inner_table[1]
        local stack_size = inner_table[2]
        if slot <= 0 then error(comms.robot_send("fatal", "slot assert failed")) end
        if type(stack_size) ~= "number" or stack_size <= 0 or stack_size > 64 then
            error(comms.robot_send("fatal", "stack_size assert failed"))
        end

        if smallest_stack > stack_size then
            smallest_slot = slot
            smallest_stack = stack_size
        end
    end

    if smallest_slot == -1 then return nil end
    return smallest_slot
end

-- 1 stack at the time obvs
function Module:removeFromSlot(what_slot, how_much) -- returns how much was actually removed
    local offset = (what_slot * 3) - 2

    self.inv_table[offset + 2] = self.inv_table[offset + 2] - how_much
    local excess = -self.inv_table[2]
    local real_removed = how_much - excess

    if self.inv_table[offset + 2] <= 0 then
        self.inv_table[offset] = EMPTY_STRING
        self.inv_table[offset + 1] = EMPTY_STRING
        self.inv_table[offset + 2] = 0
    end

    if excess < 0 then return real_removed end
    return how_much
end

function Module:forceUpdateAsForeign()
    self:forceUpdateGeneral(false)
end

function Module:forceUpdateInternal(forbidden_slots)
    self:forceUpdateGeneral(true, forbidden_slots)
end

function Module:forceUpdateGeneral(is_internal, forbidden_slots)
    local temp = Module:new(self.max_size)
    for slot = 1, self.max_size, 1 do
        local stack_info
        if is_internal then stack_info = inventory.getStackInInternalSlot(slot)
        else stack_info = inventory.getStackInSlot(sides_api.front, slot) end

        if stack_info == nil then goto continue end

        temp:addOrCreate(stack_info.label, stack_info.name, stack_info.size, forbidden_slots)
        ::continue::
    end

    -- self.inv_table = nil
    self.inv_table = temp
end

local ComparisonDiff = {
    lable = nil,
    name = nil,
    diff = 0
}

function ComparisonDiff:new(lable, name, diff)
    local new = deep_copy.copy(self, pairs)
    new.lable = lable
    new.name = name
    new.diff = diff

    return nil
end

-- it is generally better for the smaller table to be "other" rather than "self"
-- strict matches only
function Module:compareWithLedger(other)
    if other == nil then error(comms.robot_send("assert_failed")) end

    local diff_table = {}
    for index = 1, #other.inv_table, 3 do
        local o_table = other.inv_table

        local o_lable = o_table[index]
        local o_name = o_table[index + 1]
        local other_quantity = o_table[index + 2]

        local own_quantity = self:howMany(o_lable, o_name)

        local diff = own_quantity - other_quantity
        local diff_obj = ComparisonDiff:new(o_lable, o_name, diff)
        table.insert(diff_table, diff_obj)
    end

    return diff_table
end


return Module
