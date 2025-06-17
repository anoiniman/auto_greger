-- WARNING, COLLISION RESOLUTION CODE IS UNTESTED, MIGHT NOT WORK
local component = require("component")

local deep_copy = require("deep_copy")
local comms = require("comms")
local search_table = require("search_i_table")

local simple_hash = require("simple_hash")

local inventory = component.getPrimary("inventory_controller")

local Module = {}

Module.inv_size = 32
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

function Module:init_table() -- eager initialization
    for index = 1, self.table_size, 3 do
        self.inv_table[index] = 0
        self.inv_table[index + 1] = 0
        self.inv_table[index + 2] = 0
    end
end

function Module:new(inv_size)
    local new = deep_copy(self, pairs)
    new.inv_size = inv_size
    new.table_size = inv_size * 3

    new:init_table()
    return new
end

function Module:CollisionCheck(lable, name)
    for _, entry in ipairs(self:collision_table) do
        return entry.lable == lable and (name == nil or name = entry.name), true
    end
    return false, true
end

function Module:checkEntry(lable, name, l_hash, n_hash, at_index)
    local int_lhash = self.inv_table[at_index]
    local int_nhash = self.inv_table[at_index + 1]
    if type(int_lhash) == "number" then
        return int_lhash == l_hash and (n_hash == nil or n_hash == int_nhash), false
    end -- else look in the collision table
    
    return collision_check(lable, name)
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
    if n_hash == nil then n_hash = 0 end

    local collision_info = {}
    local collision_index = {}
    for index = 1, self.inv_size, 3 do
        local result, _ = self:checkEntry(lable, name, l_hash, n_hash, index)
        if result then
            local slot = (index * 3) - 2
            local item_info = inventory.getStackInInternalSlot(slot)

            -- this is a (full) collision [we found something different from us in a slot with the same hashes than us]
            if (name == nil or (name ~= nil and item_info.name ~= name)) and item_info.label ~= lable then
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
        if element[1] == lable and (name == nil or element[2] == name) then
            table.insert(found_entry, element)
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

        if true then return end
        ::continue::
    end

    return to_be_added
end

function Module:addToEmpty(lable, l_hash, name, n_hash, to_be_added, forbidden_slots)
    for index = 1, self.table_size, 3 do
        local slot = (index + 2) / 3
        if search_table.one(forbidden_slots, slot) then goto continue end
        if self.inv_table[index + 2] ~= 0 then goto continue end

        self.inv_table[index] = l_hash
        if n_hash ~= nil then self.inv_table[index + 1] = n_hash end

        local cur_add = calc_add_to_stack(self.inv_table[index + 2], to_be_added)
        self.inv_table[index + 2] = cur_add
        to_be_added = to_be_added - cur_add

        if true then return end
        ::continue::
    end

    return to_be_added
end

function Module:cAddMaybeNew(lable, name, to_be_added, forbidden_slots)
    -- DRY is for bozos
    for index = 1, self.table_size, 3 do
        if search_table.one(forbidden_slots, slot) then goto continue end
        local inner_table = self.inv_table[index]
        if type(inner_table) ~= "table" then goto continue end -- since we are collision we go into a table

        if inner_table[1] ~= lable or (name ~= nil and inner_table[2] ~= name) then goto continue end

        local current = inner_table[4]
        if current == 64 then goto continue end -- stack is already full

        local cur_add = calc_add_to_stack(current, to_be_added)
        inner_table[4] = current + cur_add
        if self.inv_table > 64 then error(comms.robot_send("fatal", "assert failed")) end

        to_be_added = to_be_added - cur_add

        if to_be_added == 0 then break end

        ::continue::
    end

    local remainder = self:cAddToEmpty(l_hash, n_hash, to_be_added, forbidden_slots)
    if remainder > 0 then
        print(comms.robot_send("error", "remainder > 0, error in updating virtual inventory"))
    end
end

-- expected quantity is the "full_value" returned from the ledger database, if the computed value does not
-- match (i.e -> is bigger) than the expected one then a collision is occuring
--
-- WARNING expected_quantity is the one before adition (obviously, but still)
-- if name is nil then not to worry, it simply won't be checked, so we only have to pass name to duplicates
function Module:addMaybeNew(lable, name, to_be_added, forbidden_slots)
    if lable == nil then error(comms.robot_send("fatal", "lable cannot be nil!")) end
    local l_hash, n_hash = self:coalesce(lable, name)
    if l_hash == nil then
        self:cAddMaybeNew(lable, name, to_be_added, forbidden_slots)
        return
    end

    -- do valid stack growth according to the rules of opencomputers (reduce left-first)
    for index = 1, self.table_size, 3 do
        local slot = (index + 2) / 3
        if search_table.one(forbidden_slots, slot) then goto continue end
        if self.inv_table[index] ~= l_hash then goto continue end
        if n_hash ~= nil and self.inv_table[index + 1] ~= n_hash then goto continue end

        local current = self.inv_table[index + 2]
        if current == 64 then goto continue end -- stack is already full

        local cur_add = calc_add_to_stack(current, to_be_added)
        self.inv_table[index + 2] = current + cur_add
        if self.inv_table > 64 then error(comms.robot_send("fatal", "assert failed")) end

        to_be_added = to_be_added - cur_add

        if to_be_added == 0 then break end

        ::continue::
    end

    -- something might have remained, simply add to empty slot
    local remainder = self:addToEmpty(l_hash, n_hash, to_be_added, forbidden_slots)
    if remainder > 0 then
        print(comms.robot_send("error", "remainder > 0, error in updating virtual inventory"))
    end
end

-- TODO
function Module:getSmallestSlot(lable, name) -- returns a slot num
    for index = 1, self.table_size, 3 do

    end
end

function Module:removeFromSlot(what_slot, how_much)
    local offset = (what_slot * 3) - 2
    self.inv_table[offset + 2] = self.inv_table[offset + 2] - how_much

    if self.inv_table[offset + 2] <= 0 then
        self.inv_table[offset] = 0
        self.inv_table[offset + 1] = 0
    end
end

return Module
