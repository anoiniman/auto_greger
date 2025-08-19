-- WARNING, COLLISION RESOLUTION CODE IS UNTESTED, MIGHT NOT WORK
local component = require("component")
local sides_api = require("sides")

local deep_copy = require("deep_copy")
local comms = require("comms")
local search_table = require("search_table")
local PPObj = require("common_pp_format")

local item_bucket = require("inventory.item_buckets")
local inventory = component.getPrimary("inventory_controller")

-- luacheck: globals EMPTY_STRING
EMPTY_STRING = ""

local Module = {}

Module.inv_size = -1
Module.table_size = -1

-- We are going to be using a module 3 to determine trios of item_lable/item_name/quantity, and the floor div 3
-- of the array will be the select
Module.inv_table = {}

function Module:getCompressedFmtObj()
    local print_table = PPObj:new()
    print_table:setTitle("Default VInventory cfmtObj:")

    local lable_table = {}
    local name_table = {}

    for index = 1, #self.inv_table, 3 do
        local lable = self.inv_table[index]
        local name = self.inv_table[index + 1]

        if  (lable == EMPTY_STRING and name == EMPTY_STRING)
            or (search_table.ione(lable_table, lable)
            and search_table.ione(name_table, name ))
        then
            goto continue
        end

        table.insert(lable_table, lable)
        table.insert(name_table, name)

        ::continue::
    end

    for index, lable in ipairs(lable_table) do
        local name = name_table[index]
        print_table:addString(lable)
        :addString(", ")
        :addString(name)
        :addString(" (")
        :addString(self:howMany(lable, name))
        :addString(")")
        :newLine()
    end

    print_table:build()
    return print_table
end

function Module:getFmtObj()
    local print_table = PPObj:new()
    print_table:setTitle("Default VInventory fmtObj:")

    for index = 1, #self.inv_table, 3 do
        if self.inv_table[index + 0] == EMPTY_STRING and self.inv_table[index + 1] == EMPTY_STRING then
            goto continue
        end

        local slot = (index + 2) / 3
        print_table:addString("(Slot: ")
                   :addString(slot)
                   :addString(")")
                   :newLine()
        print_table:addString(self.inv_table[index + 0])
                   :addString(", ")
                   :addString(self.inv_table[index + 1])
                   :addString(" (")
                   :addString(self.inv_table[index + 2])
                   :addString(")")
                   :newLine()

        ::continue::
    end
    print_table:build()

    -- print(comms.robot_send("info", table.concat(print_table)))
    return print_table
end

function Module:printObj()
    local print_table = self:getFmtObj()
    print_table:printPage(false)
end

function Module:getData()
    return self.inv_table
end

function Module:reInstantiate(unserial)
    local new = deep_copy.copy(self, pairs)
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
    return name == i_name
end

local function calc_add_to_stack(current, to_add)
    local naive_add = current + to_add
    local div = math.floor(naive_add / 64)
    if div == 0 then return to_add end -- we can add everything in, because the result is smaller than 1 stack

    local modulo = naive_add % 64
    if div == 1 and modulo == 0 then return to_add end -- this is just the right ammount to make 1 stack, add everything

    -- then we should add (64 - modulo) in order to make a full stack
    return math.max(to_add - modulo, 0)
end

function Module:addToEmpty(lable, name, to_be_added, forbidden_slots)
    name = item_bucket.identify(name, lable)
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
    name = item_bucket.identify(name, lable)
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
        if self.inv_table[index + 2] > 64 then error(comms.robot_send("fatal", "assert failed: " .. self.inv_table[index + 2])) end

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
    if lable ~= nil and lable ~= "nil" and lable ~= "nil_lable" then check_func = self.checkEntry
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
    name = item_bucket.identify(name, lable)

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

function Module:getEmptySlot(forbidden_slots)
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
    name = item_bucket.identify(name, lable)

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
    name = item_bucket.identify(name, lable)

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
    local excess = -self.inv_table[offset + 2]
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
        print(comms.robot_send("error", "forceUpdateSlot - lable not provided!"))
        print(comms.robot_send("error", debug.traceback()))
        return
    end
    if slot == nil then
        print(comms.robot_send("error", "forceUpdateSlot - slot not provided!"))
        print(comms.robot_send("error", debug.traceback()))
        return
    end

    name = item_bucket.identify(name, lable)

    local index = (slot * 3) - 2
    if self.inv_table[index] == nil then
        print(comms.robot_send("error", "forceUpdateSlot - slot_num provided is invalid!"))
        print(comms.robot_send("error", debug.traceback()))
        return
    end

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

        local name = item_bucket.identify(stack_info.name, stack_info.label)
        if string.find(name, "tool:")then
            local offset = (slot * 3) - 2
            local o_lable = self.inv_table[offset]
            local o_name = self.inv_table[offset + 1]

            if o_lable ~= "" and string.find(o_name, "tool:") then
                temp:forceUpdateSlot(o_lable, o_name, 1, slot)
                goto continue -- we preserve the original, because of how tools work
            end
        end

        temp:forceUpdateSlot(stack_info.label, stack_info.name, stack_info.size, slot)
        ::continue::
    end

    -- self.inv_table = nil
    self.inv_table = temp.inv_table
end

function Module:getNumOfEmptySlots()
    local counter = 0
    for slot = 1, self.inv_size, 1 do
        local offset = (slot * 3) - 2
        if self.inv_table[offset] == EMPTY_STRING then counter = counter + 1 end
    end
    return counter
end

-- returns slot to actually robot.select && robot.equip() [does not equip by itself! only updates the virtual inventory!]
-- Note, that if we return nil nothing has been updated in the internal database
function Module:equipSomething(tool_type, tool_level, forbidden_slots)
    if self.equip_tbl == nil then print(comms.send_unexpected()) end
    local lable_table = item_bucket.id_equipment(tool_type, tool_level)
    if lable_table == nil then return nil end

    local from_slot, from_lable, from_level
    -- this only works because the tables are already pre-sorted from best to worst
    for level_offset, sub_tbl in ipairs(lable_table) do
        for _, lable in ipairs(sub_tbl) do
            local possible_slot = self:getLargestSlot(lable)
            if possible_slot ~= nil then
                from_lable = lable
                from_slot = possible_slot
                from_level = level_offset + tool_level - 1 -- amazing how this works
                if tool_level == 0 then from_level = from_level + 1 end
                break
            end
        end
    end

    local do_empty = false
    if from_slot == nil then
        if tool_level > 0 then
            print(comms.robot_send("warning", "lable_table was not empty, but even so we failed to get/find tool"))
            return nil
        end -- else we just make sure we are holding nothing :) (TODO)
        from_slot = self:getEmptySlot(forbidden_slots)
        from_lable = EMPTY_STRING

        do_empty = true
        if self.equip_tbl.name == EMPTY_STRING then -- our hand is already empty, we can skip
            return from_slot, true
        end
    end

    -- WARNING -- very very dependend on we detecting an equipment break BEFORE we "equipSomething"
    local old_lable = self.equip_tbl.lable
    local old_name = self.equip_tbl.name

    self.equip_tbl.lable = from_lable

    if not do_empty then
        self.equip_tbl.tool_type = tool_type
        self.equip_tbl.name = "tool:" .. tool_type
    else
        self.equip_tbl.tool_type = EMPTY_STRING
        self.equip_tbl.name = EMPTY_STRING
    end

    self.equip_tbl.equiped_level = from_level

    local offset = (from_slot * 3) - 2
    self.inv_table[offset] = old_lable
    self.inv_table[offset + 1] = old_name
    if old_lable ~= EMPTY_STRING then
        self.inv_table[offset + 2] = 1 -- WARNING -- asumes equipment is non-stackable
    else
        self.inv_table[offset + 2] = 0
    end

    return from_slot, false
end

-- basically re-inits the table lol
function Module:reportEquipedBreak()
    self.equip_tbl.lable = EMPTY_STRING
    self.equip_tbl.name = EMPTY_STRING

    self.equip_tbl.tool_type = EMPTY_STRING
    self.equip_tbl.equiped_level = -1
end

function Module:getEquipedInfo()
    return self.equip_tbl.lable, self.equip_tbl.tool_type, self.equip_tbl.equiped_level
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
        if diff ~= 0 then
            local diff_obj = ComparisonDiff:new(o_lable, o_name, diff)
            table.insert(diff_table, diff_obj)
        end

        ::continue::
    end

    return diff_table
end

return Module
