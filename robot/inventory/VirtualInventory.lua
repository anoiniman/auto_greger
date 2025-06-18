-- WARNING, COLLISION RESOLUTION CODE IS UNTESTED, MIGHT NOT WORK
local component = require("component")
local sides_api = require("sides")

local deep_copy = require("deep_copy")
local comms = require("comms")
local search_table = require("search_i_table")

local simple_hash = require("simple_hash")
local bucket_funcs, _ = table.unpack(require("inventory.item_buckets"))

local inventory = component.getPrimary("inventory_controller")

-- luacheck: globals HASH_FOR_GENERIC
HASH_FOR_GENERIC = simple_hash("generic")

local Module = {}

Module.inv_size = -1
Module.table_size = -1

-- hopefully this doesn't consume to much RAM, this should be used only for the internal inventory imo

-- let's go for a flat table in order to save RAM (we're also going to be saving hashes of name/lable
-- instead of and lable it self
--
-- We are going to be using a module 3 to determine trios of item_lable/item_name/quantity, and the floor div 3
-- of the array will be the select
Module.inv_table = {}

-- the collision table stores full information for things that have collided {lable, name, slot, quantity}
Module.collision_table = {}
Module.is_internal = false

function Module:initTable() -- eager initialization
    for index = 1, self.table_size, 3 do
        self.inv_table[index] = 0
        self.inv_table[index + 1] = 0
        self.inv_table[index + 2] = 0
    end
end

-- internal, aka is this the robots own inventory?
function Module:new(inv_size, internal)
    local new = deep_copy(self, pairs)
    new.inv_size = inv_size
    new.table_size = inv_size * 3
    new.is_internal = internal or false

    new:initTable()
    return new
end

function Module:collisionCheck(lable, name)
    for _, entry in ipairs(self.collision_table) do
        local bool = entry.lable == lable and (name == "generic" or name == entry.name)
        if bool then return true, true end
    end
    return false, true
end

function Module:checkEntry(lable, name, l_hash, n_hash, at_index)
    local int_lhash = self.inv_table[at_index]
    local int_nhash = self.inv_table[at_index + 1]
    if type(int_lhash) == "number" then
        return int_lhash == l_hash and (n_hash == HASH_FOR_GENERIC or n_hash == int_nhash), false
    end -- else look in the collision table

    return self:collisionCheck(lable, name)
end

-- colisions will be rare, so if there is a colision, we'll simply create a table entry with the
-- hash + the "full-key" (e.g -> Dirt), so if the keys do not match then a re-hash will occur,
-- if this re-hash also collides, repeat, remember to "move" the old entries
--
-- If only the lable collides, but the name remains uncollided then this disambiguation is still possible
--
-- keeps hashing until good (finds good hashes)
function Module:coalesce(lable, name)
    local l_hash = simple_hash(lable)
    local n_hash = simple_hash(name)

    local collision_info = {}
    local collision_index = {}
    for index = 1, self.inv_size, 3 do
        local result, _ = self:checkEntry(lable, name, l_hash, n_hash, index)
        if result then
            local slot = (index * 3) - 2
            local item_info
            if self.is_internal then
                item_info = inventory.getStackInInternalSlot(slot)
            else
                item_info = inventory.getStackInSlot(sides_api.front, slot)
            end

            -- this is a (full) collision [we found something different from us in a slot with the same hashes than us]
            if (name == "generic" or (name ~= nil and item_info.name ~= name)) and item_info.label ~= lable then
                table.insert(collision_info, item_info)
                table.insert(collision_index, index)
            end
        end
    end

    if #collision_info == 0 then return l_hash, n_hash end -- no collision, all good
    for i = 1, #collision_info, 1 do
        local index = collision_index[i]
        self.inv_table[index] = true
        self.inv_table[index + 1] = true
        self.inv_table[index + 2] = true
        local collision_slot = (index + 2) / 3

        local item = collision_info[i]
        table.insert(self.collision_table, {item.label, item.name, item.size, collision_slot})
        self.inv_table[index] = self.collision_table[#self.collision_table]

        table.insert(self.collision_table, {lable, name, 0, -1})
    end

    return nil
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

function Module:cAddToEmpty(lable, name, to_be_added, forbidden_slots)
    local found_entries = {}
    for _, element in ipairs(self.collision_table) do
        if element[1] == lable and (name == "generic" or element[2] == name) then
            table.insert(found_entries, element)
            break
        end
    end

    for _, element in ipairs(found_entries) do
        if element[3] == 0 then
            local cur_add = calc_add_to_stack(element[3], to_be_added)
            element[3] = cur_add
            to_be_added = to_be_added - cur_add
        end
    end

    if to_be_added <= 0 then return to_be_added end
    -- we need to create new entries

    for index = 1, self.table_size, 3 do
        local slot = (index + 2) / 3
        if search_table.one(forbidden_slots, slot) then goto continue end
        if self.inv_table[index + 2] ~= 0 then goto continue end

        local new_table = {lable, name, 0, slot}
        self.inv_table[index] = new_table
        self.inv_table[index + 1] = true
        self.inv_table[index + 2] = true

        local cur_add = calc_add_to_stack(new_table[3], to_be_added)
        new_table[3] = cur_add
        to_be_added = to_be_added - cur_add

        if true then break end
        ::continue::
    end

    return to_be_added
end

function Module:addToEmpty(l_hash, n_hash, to_be_added, forbidden_slots)
    for index = 1, self.table_size, 3 do
        local slot = (index + 2) / 3
        if search_table.one(forbidden_slots, slot) then goto continue end
        if self.inv_table[index + 2] ~= 0 then goto continue end

        self.inv_table[index] = l_hash
        if n_hash ~= HASH_FOR_GENERIC then self.inv_table[index + 1] = n_hash end

        local cur_add = calc_add_to_stack(self.inv_table[index + 2], to_be_added)
        self.inv_table[index + 2] = cur_add
        to_be_added = to_be_added - cur_add

        if true then break end
        ::continue::
    end

    return to_be_added
end

-- DRY is for bozos
function Module:cAddOrCreate(lable, name, to_be_added, forbidden_slots)
    for index = 1, self.table_size, 3 do
        local slot = (index + 2) / 3

        if search_table.one(forbidden_slots, slot) then goto continue end
        local inner_table = self.inv_table[index]
        if type(inner_table) ~= "table" then goto continue end -- since we are collision we go into a table

        if inner_table[1] ~= lable or (name ~= nil and inner_table[2] ~= name) then goto continue end

        local current = inner_table[4]
        if current == 64 then goto continue end -- stack is already full

        local cur_add = calc_add_to_stack(current, to_be_added)
        inner_table[4] = current + cur_add
        if self.inv_table[index + 2] > 64 then error(comms.robot_send("fatal", "assert failed")) end

        to_be_added = to_be_added - cur_add

        if to_be_added == 0 then break end

        ::continue::
    end

    local remainder = self:cAddToEmpty(lable, name, to_be_added, forbidden_slots)
    if remainder > 0 then
        print(comms.robot_send("error", "remainder > 0, error in updating virtual inventory, inventory is prob full"))
    end
    return remainder
end


-- if name is nil then not to worry, it simply won't be checked, so we only have to pass name to duplicates
function Module:addOrCreate(lable, name, to_be_added, forbidden_slots)
    name = bucket_funcs.identify(name, lable)

    if lable == nil then error(comms.robot_send("fatal", "lable cannot be nil!")) end
    local l_hash, n_hash = self:coalesce(lable, name)
    if l_hash == nil then
        return self:cAddOrCreate(lable, name, to_be_added, forbidden_slots)
    end

    -- do valid stack growth according to the rules of opencomputers (reduce left-first)
    for index = 1, self.table_size, 3 do
        local slot = (index + 2) / 3
        if search_table.one(forbidden_slots, slot) then goto continue end
        if self.inv_table[index] ~= l_hash then goto continue end
        if n_hash ~= HASH_FOR_GENERIC and self.inv_table[index + 1] ~= n_hash then goto continue end

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
    local remainder = self:addToEmpty(l_hash, n_hash, to_be_added, forbidden_slots)
    if remainder > 0 then
        print(comms.robot_send("error", "remainder > 0, error in updating virtual inventory, inventory is prob full"))
    end
    return remainder
end

function Module:getAllSlots(lable, name)
    name = bucket_funcs.identify(name, lable)

    -- No need to coalesce since this won't modify the data, just retrieve
    local l_hash = simple_hash(lable)
    local n_hash = simple_hash(name)

    local slot_table = {}
    for index = 1, self.table_size, 3 do
        if type(self.inv_table[index]) == "table" then
            local inner_table = self.inv_table[index]
            if lable ~= inner_table[1] or (name ~= nil and name ~= inner_table[2]) then goto continue end

            local new_entry = {inner_table[3], inner_table[4]} -- slot, quantity
            table.insert(slot_table, new_entry)
            goto continue
        end

        if l_hash ~= self.inv_table[index] or (n_hash ~= HASH_FOR_GENERIC and n_hash ~= self.inv_table[index + 1]) then
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

    if type(self.inv_table[offset]) == "table" then
        local element = self.inv_table[offset]
        element[3] = element[3] - how_much

        if element[3] <= 0 then
            for inner_index, real_element in ipairs(self.collision_table) do
                if real_element == element then
                    table.remove(self.collision_table, inner_index)
                    break
                end
            end

            self.inv_table[offset] = 0
            self.inv_table[offset + 1] = 0
            self.inv_table[offset + 2] = 0
        end
    end

    self.inv_table[offset + 2] = self.inv_table[offset + 2] - how_much
    local excess = -self.inv_table[2]
    local real_removed = how_much - excess

    if self.inv_table[offset + 2] <= 0 then
        self.inv_table[offset] = 0
        self.inv_table[offset + 1] = 0
        self.inv_table[offset + 2] = 0
    end

    if excess < 0 then return real_removed end
    return how_much
end

return Module
