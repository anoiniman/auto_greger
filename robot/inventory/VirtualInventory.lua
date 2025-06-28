-- WARNING, COLLISION RESOLUTION CODE IS UNTESTED, MIGHT NOT WORK
local component = require("component")
local sides_api = require("sides")

local deep_copy = require("deep_copy")
local comms = require("comms")
local search_table = require("search_table")

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


function Module:printObj()
    local print_table = {}
    for index = 1, #self.inv_table, 3 do
        if self.inv_table[index + 0] == EMPTY_STRING and self.inv_table[index + 1] == EMPTY_STRING then
            goto continue
        end

        local slot = (index + 2) / 3
        table.insert(print_table, "(Slot: ")
        table.insert(print_table, slot)
        table.insert(print_table, ")")
        table.insert(print_table, "\n")
        table.insert(print_table, self.inv_table[index + 0])
        table.insert(print_table, ", ")
        table.insert(print_table, self.inv_table[index + 1])
        table.insert(print_table, " (")
        table.insert(print_table, self.inv_table[index + 2])
        table.insert(print_table, ")")

        table.insert(print_table, "\n")
        table.insert(print_table, "----\n")

        ::continue::
    end
    print(comms.robot_send("info", table.concat(print_table)))
end

function Module:getData()
    return self.inv_table
end

function Module:reInstantiate(unserial)
    local new = deep_copy(self, pairs)
    new.inv_size = (#unserial / 3)
    new.table_size = #unserial
    new.inv_type = "virtual_inventory"

    new.inv_table = unserial
    return new
end

function Module:initTable() -- eager initialization
    for index = 1, self.table_size, 3 do
        self.inv_table[index] = EMPTY_STRING
        self.inv_table[index + 1] = EMPTY_STRING
        self.inv_table[index + 2] = 0
    end
end

-- internal, aka is this the robots own inventory?
function Module:new(inv_size)
    local new = deep_copy.copy(self, pairs)
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
    local div = math.floor(naive_add / 64)
    if div == 0 then return to_add end -- we can add everything in, because the result is smaller than 1 stack

    local modulo = naive_add % 64
    if modulo == 0 then return to_add end -- this is just the right ammount to make 1 stack, add everything

    -- then we should add (64 - modulo) in order to make a full stack
    return 64 - modulo
end

function Module:addToEmpty(lable, name, to_be_added, forbidden_slots)
    name = bucket_funcs.identify(name, lable)
    if to_be_added <= 0 then return 0 end

    for index = 1, self.table_size, 3 do
        local slot = (index + 2) / 3
        if search_table.ione(forbidden_slots, slot) then goto continue end
        if self.inv_table[index + 2] ~= 0 then goto continue end

        self.inv_table[index] = lable
        self.inv_table[index + 1] = name

        local cur_add = calc_add_to_stack(self.inv_table[index + 2], to_be_added)
        self.inv_table[index + 2] = cur_add
        to_be_added = to_be_added - cur_add

        if to_be_added == 0 then return 0 end
        ::continue::
    end

    return to_be_added -- remainder
end

-- WARNING: If addOrCreate doesn't mimic/isn't used 100% accuratly to model the real behaviour we're ffed
-- if name is not provided, name is probably generic, if name is generic, it is accepted by any lable
function Module:addOrCreate(lable, name, to_be_added, forbidden_slots)
    name = bucket_funcs.identify(name, lable)
    if to_be_added <= 0 then return 0 end

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

-- of lable is left nil, the behaviour will be identical to getAllSlotsPermissive,
-- if you want Strict mode only (return nil on nil lable), use "getAllSlotsStrict"
function Module:getAllSlots(lable, name, up_to)
    local check_func
    if lable ~= nil then check_func = self.checkEntry
    else check_func = self.checkEntryPermissive end

    return self:getAllSlotsInternal(lable, name, check_func, up_to)
end

function Module:getAllSlotsStrict(lable, name, up_to)
    if lable == nil then return nil end
    return self:getAllSlotsInternal(lable, name, self.checkEntry, up_to)
end

function Module:getAllSlotsPermissive(name, up_to)
    return self:getAllSlotsInternal(nil, name, self.checkEntryPermissive, up_to)
end

function Module:getAllSlotsInternal(lable, name, check_func, up_to)
    if up_to == nil then up_to = 100000 end
    name = bucket_funcs.identify(name, lable)

    local slot_table = {}
    for index = 1, self.table_size, 3 do
        if not check_func(self, lable, name, index) then
            goto continue
        end

        local slot = (index + 2) / 3
        local quantity = self.inv_table[index + 2]

        -- this code segment works to return only as many slots as you need to get the x quantity
        up_to = up_to - quantity
        if up_to < 0 then quantity = quantity + up_to end
        if quantity <= 0 then break end

        local new_entry = {slot, quantity}
        table.insert(slot_table, new_entry)

        ::continue::
    end
    if #slot_table == 0 then return nil end
    return slot_table
end

function Module:getEmptySlot(forbidden_slots) -- including forbidden ones!
    for index = 1, #self.inv_table, 3 do
        local empty = self.inv_table[index] == EMPTY_STRING
        if not empty then goto continue end

        local slot = (index + 2) / 3
        if search_table.ione(forbidden_slots, slot) then goto continue end

        if true then return slot end
        ::continue::
    end
    return nil
end

function Module:howMany(lable, name)
    local slot_table = self:getAllSlots(lable, name)
    if slot_table == nil then return 0 end

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

function Module:getSlotInfo(slot)
    local index = (slot * 3) - 2
    return self.inv_table[index], self.inv_table[index + 1], self.inv_table[index + 2]
end

-- One Day VVVVV
--[[function Module:customGetSlot(lable, name, condition)
end--]]

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

function Module:getLargestSlot(lable, name)
    name = bucket_funcs.identify(name, lable)

    local slot_table = self:getAllSlots(lable, name)
    if slot_table == nil then return nil end

    local largest_slot = -1
    local largest_stack = 0
    for _, inner_table in ipairs(slot_table) do
        local slot = inner_table[1]
        local stack_size = inner_table[2]
        if slot <= 0 then error(comms.robot_send("fatal", "slot assert failed")) end
        if type(stack_size) ~= "number" or stack_size <= 0 or stack_size > 64 then
            error(comms.robot_send("fatal", "stack_size assert failed"))
        end

        if stack_size > largest_stack then
            largest_slot = slot
            largest_stack = stack_size
        end
    end

    if largest_slot == -1 then return nil end
    return largest_slot
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

function Module:exchangeSlots(a, b)
    local offset_a = (a * 3) - 2
    local offset_b = (b * 3) - 2

    for index = 0, 2, 1 do
        local a_index = offset_a + index
        local b_index = offset_b + index

        local temp = self.inv_table[b_index]
        self.inv_table[b_index] = self.inv_table[a_index]
        self.inv_table[a_index] = temp
    end
end

function Module:forceUpdateSlot(lable, name, quantity, slot)
    if lable == nil then
        print(comms.robot_send("error", "foceUpdateSlot - lable not provided!"))
        print(comms.robot_send("error", debug.traceback()))
        return
    end
    name = bucket_funcs.identify(name, lable)

    local index = (slot * 3) - 2
    self.inv_table[index] = lable
    self.inv_table[index + 1] = name
    self.inv_table[index + 2] = quantity
end

function Module:forceUpdateAsForeign()
    self:forceUpdateGeneral(false)
end

function Module:forceUpdateInternal()
    self:forceUpdateGeneral(true)
end

function Module:forceUpdateGeneral(is_internal)
    local temp = Module:new(self.inv_size)
    for slot = 1, self.inv_size, 1 do
        local stack_info
        if is_internal then stack_info = inventory.getStackInInternalSlot(slot)
        else stack_info = inventory.getStackInSlot(sides_api.front, slot) end

        if stack_info == nil then goto continue end

        temp:forceUpdateSlot(stack_info.label, stack_info.name, stack_info.size, slot)
        ::continue::
    end

    -- self.inv_table = nil
    self.inv_table = temp.inv_table
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

    return new
end

-- it is generally better for the smaller table to be "other" rather than "self"
-- strict matches only
function Module:compareWithLedger(other)
    if other == nil then error(comms.robot_send("assert_failed")) end

    local diff_table = {}
    for index = 1, #other.inv_table, 3 do
        local o_table = other.inv_table

        local slot_quantity = o_table[index + 2]
        if slot_quantity == 0 then goto continue end

        local o_lable = o_table[index]
        local o_name = o_table[index + 1]

        for _, c_diff in ipairs(diff_table) do -- skip things already added
            if c_diff.lable == o_lable and c_diff.name == o_name then goto continue end
        end

        local other_quantity = other:howMany(o_lable, o_name)
        local own_quantity = self:howMany(o_lable, o_name)

        local diff = own_quantity - other_quantity
        local diff_obj = ComparisonDiff:new(o_lable, o_name, diff)
        table.insert(diff_table, diff_obj)

        ::continue::
    end

    return diff_table
end

return Module
