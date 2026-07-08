require("inventory.__h_VirtualInventory")
local a_tbl = require("PriorityQueue")
local pqueue, PriorityQueue, Prioritizable = table.unpack(a_tbl)

local item_helper = require("inventory.__h_Item")

-- WARNING, COLLISION RESOLUTION CODE IS UNTESTED, MIGHT NOT WORK
local component = require("component")
local sides_api = require("sides")

local comms = require("comms")
local search_table = require("search_table")
local PPObj = require("common_pp_format")

local item_bucket = require("inventory.item_buckets")
local inventory = component.getPrimary("inventory_controller") as InventoryController

-- luacheck: globals EMPTY_STRING
global EMPTY_STRING: string = ""

global interface SlotEntry is Prioritizable
    slot: integer
    quantity: integer
end

local type CheckFunc = function(VirtualInventory, ItemDefinition, ?integer): boolean
local record helper
    how_many: function(VirtualInventory, ItemDefinition): integer
    new: function(integer): VirtualInventory

    get_all_slots_internal:
    function(
        VirtualInventory,
        ItemDefinition,
        CheckFunc,
        integer
    ): PriorityQueue<SlotEntry> | nil
    force_update_general: function(VirtualInventory, boolean)
end

-- We are going to be using a modulo 3 to determine trios of item_label/item_name/quantity, and the floor div 3
-- of the array will be the select

function helper.get_compressed_fmt_obj(vinv: VirtualInventory): PPObj
    local print_table = PPObj:new()
    print_table:setTitle("Default VInventory cfmtObj:")

    local label_table: {string} = {}
    local name_table: {string} = {}

    for index = 1, #vinv.inv_table, 3 do
        local label = vinv.inv_table[index]
        local name = vinv.inv_table[index + 1]

        if  (label == EMPTY_STRING and name == EMPTY_STRING)
            or (search_table.ione(label_table, label)
            and search_table.ione(name_table, name ))
        then
            goto continue
        end

        table.insert(label_table, label as string)
        table.insert(name_table, name as string)

        ::continue::
    end

    for index, label in ipairs(label_table) do
        local name = name_table[index]
        print_table:addString(label)
        :addString(", ")
        :addString(name)
        :addString(" (")
        :addString(tostring(helper.how_many(vinv, item_helper.new_item_definition(label, name))))
        :addString(")")
        :newLine()
    end

    print_table:build()
    return print_table
end

function helper.getFmtObj(vinv: VirtualInventory): PPObj
    local print_table = PPObj:new()
    print_table:setTitle("Default VInventory fmtObj:")

    for index = 1, #vinv.inv_table, 3 do
        if vinv.inv_table[index + 0] == EMPTY_STRING and vinv.inv_table[index + 1] == EMPTY_STRING then
            goto continue
        end

        local slot = (index + 2) / 3
        print_table:addString("(Slot: ")
                   :addString(tostring(slot))
                   :addString(")")
                   :newLine()
        print_table:addString(vinv.inv_table[index + 0] as string)
                   :addString(", ")
                   :addString(vinv.inv_table[index + 1] as string)
                   :addString(" (")
                   :addString(tostring(vinv.inv_table[index + 2]))
                   :addString(")")
                   :newLine()

        ::continue::
    end
    print_table:build()

    -- print(comms.robot_send("info", table.concat(print_table)))
    return print_table
end

function helper.print_obj(vinv: VirtualInventory)
    local print_table = helper.getFmtObj(vinv)
    print_table:printPage(false)
end

function helper.get_data(vinv: VirtualInventory): {string | integer}
    return vinv.inv_table
end

function helper.reinstantiate(unserial: {string | integer}): VirtualInventory
    local new = helper.new(-1)

    if #unserial % 3 ~= 0 then
        print(comms.robot_send("warning", "reinstantiated inv_table that is not divisable by 3:\n" .. debug.traceback()))
    end

    new.inv_size = (#unserial / 3) as integer
    new.table_size = #unserial

    new.inv_table = unserial
    return new
end

function helper.initTable(vinv: VirtualInventory) -- eager initialization
    for index = 1, vinv.table_size, 3 do
        vinv.inv_table[index] = EMPTY_STRING
        vinv.inv_table[index + 1] = EMPTY_STRING
        vinv.inv_table[index + 2] = 0
    end
end

function helper.new(inv_size: integer): VirtualInventory
    local new: VirtualInventory = {
        inv_size = inv_size,
        table_size = inv_size * 3,

        inv_type = "virtual_inventory",
        inv_table = {},
    }

    helper.initTable(new)
    return new
end

function helper.from_partial(partial: {string | integer}, inv_size: integer): VirtualInventory
    local new: VirtualInventory = {
        inv_size = inv_size,
        table_size = inv_size * 3,

        inv_type = "virtual_inventory",
        inv_table = {},
    }

    for index = 1, new.table_size, 3 do
        if partial[index] == nil then
            new.inv_table[index] = EMPTY_STRING
            new.inv_table[index + 1] = EMPTY_STRING
            new.inv_table[index + 2] = 0
        else
            new.inv_table[index] = partial[index]
            new.inv_table[index + 1] = partial[index + 1]
            new.inv_table[index + 2] = partial[index + 2]
        end
    end
    return new
end


function helper.check_entry(vinv: VirtualInventory, other: ItemDefinition, at_index: integer): boolean
    local item = item_helper.new_item_definition(vinv.inv_table[at_index] as string, vinv.inv_table[at_index + 1] as string)
    return item_helper.item_def_eq(item, other)
end

function helper.check_entry_permissive(vinv: VirtualInventory, other: ItemDefinition, at_index: integer): boolean
    local item = item_helper.new_item_definition(vinv.inv_table[at_index] as string, vinv.inv_table[at_index + 1] as string)
    return item_helper.item_def_perm_eq(item, other)
end

local function calc_add_to_stack(current: integer, to_add: integer): integer
    local naive_add = current + to_add
    local div = math.floor(naive_add / 64)
    if div == 0 then return to_add end -- we can add everything in, because the result is smaller than 1 stack

    local modulo = naive_add % 64
    if div == 1 and modulo == 0 then return to_add end -- this is just the right ammount to make 1 stack, add everything

    -- then we should add (64 - modulo) in order to make a full stack
    return math.max(to_add - modulo, 0)
end

function helper.add_to_empty(
    vinv: VirtualInventory,
    item: ItemDefinition,
    to_be_added: integer,
    forbidden_slots: {integer}
): integer
    item = item_bucket.identify(item)
    if to_be_added <= 0 then return 0 end

    for index = 1, vinv.table_size, 3 do
        local slot = (index + 2) / 3
        if search_table.ione(forbidden_slots, slot) then goto continue end
        if vinv.inv_table[index + 2] ~= 0 then goto continue end

        vinv.inv_table[index] = item.label
        vinv.inv_table[index + 1] = item.name

        local cur_add = calc_add_to_stack(vinv.inv_table[index + 2] as integer, to_be_added)
        vinv.inv_table[index + 2] = cur_add
        to_be_added = to_be_added - cur_add

        if to_be_added == 0 then return 0 end
        ::continue::
    end

    return to_be_added -- remainder
end

-- WARNING: If addOrCreate doesn't mimic/isn't used 100% accuratly to model the real behaviour we're ffed
-- if name is not provided, name is probably generic, if name is generic, it is accepted by any label
function helper.add_or_create(
    vinv: VirtualInventory,
    item: ItemDefinition,
    to_be_added: integer,
    forbidden_slots: {integer}
): integer
    item = item_bucket.identify(item)
    if to_be_added <= 0 then return 0 end

    -- do valid stack growth according to the rules of opencomputers (reduce left-first)
    for index = 1, vinv.table_size, 3 do
        local slot = (index + 2) / 3
        if search_table.ione(forbidden_slots, slot) then goto continue end
        if not helper.check_entry(vinv, item, index) then goto continue end

        local current: integer = vinv.inv_table[index + 2] as integer
        if current == 64 then goto continue end -- stack is already full

        local cur_add = calc_add_to_stack(current, to_be_added)
        vinv.inv_table[index + 2] = current + cur_add
        if vinv.inv_table[index + 2] as integer > 64 then 
            error(comms.robot_send("fatal", "assert failed: " .. tostring(vinv.inv_table[index + 2])))
        end

        to_be_added = to_be_added - cur_add
        if to_be_added == 0 then break end

        ::continue::
    end

    -- something might have remained, simply add to empty slot
    local remainder = helper.add_to_empty(vinv, item, to_be_added, forbidden_slots)
    if remainder > 0 then
        print(comms.robot_send("error", "remainder > 0, error in updating virtual inventory, inventory is prob full"))
    end
    return remainder
end

-- of label is left nil, the behaviour will be identical to getAllSlotsPermissive,
-- if you want Strict mode only (return nil on nil label), use "getAllSlotsStrict"
function helper.get_all_slots(vinv: VirtualInventory, item: ItemDefinition, up_to?: integer): PriorityQueue<SlotEntry>
    local check_func: function(vinv, ItemDefinition, ?integer): boolean
    if item.label ~= nil then check_func = helper.check_entry
    else check_func = helper.check_entry_permissive end

    return helper.get_all_slots_internal(vinv, item, check_func, up_to)
end

function helper.get_all_slots_strict(vinv: VirtualInventory, item: ItemDefinition, up_to: integer): PriorityQueue<SlotEntry> | nil
    if item.label == nil then return nil end
    return helper.get_all_slots_internal(vinv, item, helper.check_entry, up_to)
end

function helper.get_all_slots_permissive(
    vinv: VirtualInventory,
    item: ItemDefinition,
    up_to: integer
): PriorityQueue<SlotEntry> | nil
    return helper.get_all_slots_internal(vinv, item, helper.check_entry_permissive, up_to)
end

function helper.get_all_slots_internal(
    vinv: VirtualInventory,
    item: ItemDefinition,
    check_func: CheckFunc,
    up_to: integer
): PriorityQueue<SlotEntry> | nil
    if up_to == nil then up_to = 100000 end
    item = item_bucket.identify(item)

    local slot_table: PriorityQueue<SlotEntry> = pqueue.new()
    for index = 1, vinv.table_size, 3 do
        if not check_func(vinv, item, index) then
            goto continue
        end

        local slot: integer = ((index + 2) / 3) as integer
        local quantity: integer = vinv.inv_table[index + 2] as integer

        -- this code segment works to return only as many slots as you need to get the x quantity
        up_to = up_to - quantity
        if up_to < 0 then quantity = quantity + up_to end
        if quantity <= 0 then break end

        local new_entry = {slot = slot, quantity = quantity, priority = quantity}
        pqueue.insert(slot_table, new_entry)

        ::continue::
    end
    if pqueue.size(slot_table) == 0 then return nil end
    return slot_table
end

function helper.get_empty_slot(vinv: VirtualInventory, forbidden_slots: {integer}): integer | nil
    for index = 1, #vinv.inv_table, 3 do
        local empty = vinv.inv_table[index] == EMPTY_STRING
        if not empty then goto continue end

        local slot: integer = ((index + 2) / 3) as integer
        if search_table.ione(forbidden_slots, slot) then goto continue end

        if true then return slot end
        ::continue::
    end
    return nil
end

function helper.get_all_empty_slots(vinv: VirtualInventory, forbidden_slots: {integer}): {SlotEntry} | nil
    local matching_slots = {}
    for index = 1, #vinv.inv_table, 3 do
        local empty = vinv.inv_table[index] == EMPTY_STRING
        if not empty then goto continue end

        local slot: integer = ((index + 2) / 3) as integer
        if search_table.ione(forbidden_slots, slot) then goto continue end

        local new_entry = {slot = slot, quantity = 0}
        if true then table.insert(matching_slots, new_entry) end
        ::continue::
    end

    if #matching_slots == 0 then return nil end
    return matching_slots
end

function helper.how_many(vinv: VirtualInventory, item: ItemDefinition): integer
    local slot_table = helper.get_all_slots(vinv, item)
    if slot_table == nil then return 0 end

    local total = 0
    -- for _, element in pqueue.iter(slot_table) do
    for _, element in ipairs(slot_table.inner) do
        -- local slot = element[1]
        local quantity = element.quantity
        total = total + quantity
    end
    return total
end

function helper.how_many_slot(vinv: VirtualInventory, slot: integer): integer
    local index = (slot * 3) - 2
    return (vinv.inv_table[index + 2]) as integer
end

function helper.get_slot_info(vinv: VirtualInventory, slot: integer): string, string, integer
    local index: integer = ((slot * 3) - 2) as integer
    return vinv.inv_table[index] as string, vinv.inv_table[index + 1] as string, vinv.inv_table[index + 2] as integer
end

-- One Day VVVVV
--[[function Module:customGetSlot(label, name, condition)
end--]]

function helper.get_smallest_slot(vinv: VirtualInventory, item: ItemDefinition): integer | nil -- returns a slot num
    item = item_bucket.identify(item)

    local slot_table = helper.get_all_slots(vinv, item)
    if slot_table == nil then return nil end

    local smallest_slot = -1
    local smallest_stack = 65
    for _, inner_table in ipairs(slot_table.inner) do
        local slot = inner_table.slot
        local stack_size = inner_table.quantity
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

function helper.get_largest_slot(vinv: VirtualInventory, item: ItemDefinition): integer | nil
    item = item_bucket.identify(item)

    local slot_table = helper.get_all_slots(vinv, item)
    if slot_table == nil then return nil end

    local largest_slot = -1
    local largest_stack = 0
    for _, inner_table in ipairs(slot_table.inner) do
        local slot = inner_table.slot
        local stack_size = inner_table.quantity
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
function helper.remove_from_slot(vinv: VirtualInventory, what_slot: integer, how_much: integer): integer
    -- returns how much was actually removed
    local offset: integer = ((what_slot * 3) - 2) as integer

    vinv.inv_table[offset + 2] = (vinv.inv_table[offset + 2] as integer) - how_much
    local excess = -(vinv.inv_table[offset + 2] as integer)
    local real_removed = how_much - excess

    if (vinv.inv_table[offset + 2] as integer) <= 0 then
        vinv.inv_table[offset] = EMPTY_STRING
        vinv.inv_table[offset + 1] = EMPTY_STRING
        vinv.inv_table[offset + 2] = 0
    end

    if excess < 0 then return real_removed end
    return how_much
end

function helper.exchange_slots(vinv: VirtualInventory, a: integer, b: integer)
    local offset_a = (a * 3) - 2
    local offset_b = (b * 3) - 2

    for index = 0, 2, 1 do
        local a_index = offset_a + index
        local b_index = offset_b + index

        local temp = vinv.inv_table[b_index]
        vinv.inv_table[b_index] = vinv.inv_table[a_index]
        vinv.inv_table[a_index] = temp
    end
end

function helper.force_update_slot(
    vinv: VirtualInventory,
    item: FullDefinition,
    slot: integer
)
    item = item_bucket.identify(item)

    local index = (slot * 3) - 2
    if vinv.inv_table[index] == nil then
        print(comms.robot_send("error", "forceUpdateSlot - slot_num provided is invalid!"))
        print(comms.robot_send("error", debug.traceback()))
        return
    end

    vinv.inv_table[index] = item.label
    vinv.inv_table[index + 1] = item.name
    vinv.inv_table[index + 2] = item.size
end

function helper.force_update_as_foreign(vinv: VirtualInventory)
    helper.force_update_general(vinv, false)
end

function helper.forceUpdateInternal(vinv: VirtualInventory)
    helper.force_update_general(vinv, true)
end

function helper.force_update_general(vinv: VirtualInventory, is_internal: boolean)
    local temp = helper.new(vinv.inv_size)
    for slot = 1, vinv.inv_size, 1 do
        local stack_info: StackInfo
        if is_internal then stack_info = inventory.getStackInInternalSlot(slot)
        else stack_info = inventory.getStackInSlot(sides_api.front, slot) end

        if stack_info == nil then goto continue end

        local item = item_bucket.identify(
            item_helper.new_item_definition(
                stack_info.label,
                stack_info.name,
                stack_info.size
            )
        ) as FullDefinition

        if string.find(item.name, "tool:")then
            local offset = (slot * 3) - 2
            local o_label: string = vinv.inv_table[offset] as string
            local o_name: string = vinv.inv_table[offset + 1] as string

            if o_label ~= "" and string.find(o_name, "tool:") then
                item.size = 1
                helper.force_update_slot(temp, item, slot)
                item = nil
                goto continue -- we preserve the original, because of how tools work
            end
        end

        helper.force_update_slot(temp, item, slot)
        ::continue::
    end

    -- self.inv_table = nil
    vinv.inv_table = temp.inv_table
end

function helper.get_num_of_empty_slots(vinv: VirtualInventory): integer
    local counter = 0
    for slot = 1, vinv.inv_size, 1 do
        local offset = (slot * 3) - 2
        if vinv.inv_table[offset] == EMPTY_STRING then counter = counter + 1 end
    end
    return counter
end

-- returns slot to actually robot.select && robot.equip() [does not equip by itself! only updates the virtual inventory!]
-- Note, that if we return nil nothing has been updated in the internal database
function helper.equip_something(
    vinv: VirtualInventory,
    tool_type: ToolType,
    tool_level: ToolLevel,
    forbidden_slots: {integer}
): integer, boolean
    if vinv.equip_info == nil then print(comms.send_unexpected()) end
    local label_table = item_bucket.id_equipment(tool_type, tool_level)
    if label_table == nil then return nil end

    local from_slot, from_label, from_level: integer, string, integer
    -- this only works because the tables are already pre-sorted from best to worst
    for level_offset, sub_tbl in ipairs(label_table) do
        for _, label_query in ipairs(sub_tbl) do
            local item = item_helper.new_item_definition(label_query.label, nil)
            local possible_slot = helper.get_largest_slot(vinv, item)
            if possible_slot ~= nil then
                from_label = item.label
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
            print(comms.robot_send("warning", "label_table was not empty, but even so we failed to get/find tool"))
            return nil
        end -- else we just make sure we are holding nothing :)
        from_slot = helper.get_empty_slot(vinv, forbidden_slots)
        from_label = EMPTY_STRING

        do_empty = true
        if vinv.equip_info.name == EMPTY_STRING then -- our hand is already empty, we can skip
            return from_slot, true
        end
    end

    -- WARNING -- very very dependend on we detecting an equipment break BEFORE we "equipSomething"
    local old_label = vinv.equip_info.label
    local old_name = vinv.equip_info.name

    vinv.equip_info.label = from_label

    if not do_empty then
        vinv.equip_info.tool_type = tool_type
        vinv.equip_info.name = "tool:" .. tool_type
    else
        vinv.equip_info.tool_type = EMPTY_STRING as ToolType
        vinv.equip_info.name = EMPTY_STRING
    end

    vinv.equip_info.equiped_level = from_level

    local offset = (from_slot * 3) - 2
    vinv.inv_table[offset] = old_label
    vinv.inv_table[offset + 1] = old_name
    if old_label ~= EMPTY_STRING then
        vinv.inv_table[offset + 2] = 1 -- WARNING -- asumes equipment is non-stackable
    else
        vinv.inv_table[offset + 2] = 0
    end

    return from_slot, false
end

-- basically re-inits the table lol
function helper.report_equiped_break(vinv: VirtualInventory)
    vinv.equip_info.label = EMPTY_STRING
    vinv.equip_info.name = EMPTY_STRING

    vinv.equip_info.tool_type = EMPTY_STRING as ToolType
    vinv.equip_info.equiped_level = -1
end

function helper.get_equiped_info(vinv: VirtualInventory): string, ToolType, integer
    return vinv.equip_info.label, vinv.equip_info.tool_type, vinv.equip_info.equiped_level
end

local function comparison_new(item: ItemQuery, diff: integer): ComparisonDiff
    local new: ComparisonDiff = {
        item = item,
        diff = diff
    }

    return new
end

-- it is generally better for the smaller table to be "other" rather than "self"
-- strict matches only
function helper.compare_with_ledger(self: VirtualInventory, other: VirtualInventory): {ComparisonDiff}
    if other == nil then error(comms.robot_send("fatal", "assert_failed")) end

    local diff_table: {ComparisonDiff} = {}
    for index = 1, #other.inv_table, 3 do
        local o_table = other.inv_table

        local slot_quantity = o_table[index + 2]
        if slot_quantity == 0 then goto continue end

        local o_label: string = o_table[index] as string
        local o_name: string = o_table[index + 1] as string

        -- Suuuure let's just do this raw why not what can go wrong :3
        for _, c_diff in ipairs(diff_table) do -- skip things already added
            if c_diff.item.label == o_label and c_diff.item.name == o_name then goto continue end
        end

        local other_item = item_helper.new_item_definition(o_label, o_name)
        local other_quantity = helper.how_many(other, other_item)
        local own_quantity = helper.how_many(self, other_item)

        local diff = own_quantity - other_quantity
        if diff ~= 0 then
            local diff_obj = comparison_new(item_helper.new_item_query(o_label, o_name), diff)
            table.insert(diff_table, diff_obj)
        end

        ::continue::
    end

    return diff_table
end

return helper
