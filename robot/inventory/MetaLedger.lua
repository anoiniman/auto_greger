-- luacheck: globals HASH_FOR_GENERIC
local component = require("component")
local sides_api = require("sides")

local deep_copy = require("deep_copy")
local comms = require("comms")
local simple_hash = require("simple_hash")

local SpecialDefinition = require("inventory.SpecialDefinition")
local bucket_functions, _ = table.unpack(require("inventory.item_buckets"))

local inventory = component.getPrimary("inventory_controller")

-- It is assumed this will never be used for the robots own inventory

-- this will be a virtual inventory without slot info, achieving good item compression
-- the format now is 4 based {l_hash, n_hash, quantity, ex_slot}
-- an example slot is necessary to detect collisions


-- I could've bit-masked the slot into the quantity and saved on 8 bytes, but what are 8 bytes anyway? hahaha
-- it's only 800kb per 100.000 items stacks, when we have to worry about this many items stacks we'll be using servers
local VirtualInventory = require("inventory.VirtualInventory")
local Module = VirtualInventory:new(-1)

-- (new) function is unchanged from VirtualInventory (except for the fact that the table is not pre-inited)
function Module:new(inv_size)
    local new = deep_copy(self, pairs)
    new.inv_size = inv_size
    new.table_size = 0 * 4 -- :)

    return new
end

function Module:findSuggestedSlot(lable, name, suggested_slot)
    if suggested_slot == nil then -- this slow, plz sugest a slot :sadge:
        for slot = 1, self.inv_size, 1 do
            local external_item = inventory.getStackInSlot(sides_api.front, slot)
            if external_item == nil then goto continue end

            local id_name = bucket_funcs.identify(external_item.name, external_item.label)
            if external_item.label ~= lable or (name ~= "generic" and id_name ~= name) then goto continue end

            suggested_slot = slot
            if true then break end

            ::continue::
        end
    end

    return suggested_slot
end

function Module:findIndexesPermissive(lable, name)
    local n_hash = simple_hash(name)

    local index_table = {}
    for index = 1, #self.inv_table, 4 do
        if n_hash ~= self.inv_table[index + 1] then
            goto continue
        end -- collision check

        local slot = self.inv_table[index + 4]
        local item = inventory.getStackInSlot(sides_api.front, slot)
        if lable ~= item.label or (name ~= nil and name ~= item.name) then goto continue end -- this is a collision

        something_found = index -- the big thing
        if true then break end

        ::continue::
    end

    return something_found
end

function Module:findIndex(lable, name, no_collision_check)
    if lable == nil then error(comms.robot_send("fatal", "lable cannot be nil!")) end
    local l_hash = simple_hash(lable)
    local n_hash = simple_hash(name)

    local something_found = -1
    for index = 1, #self.inv_table, 4 do
        if self.inv_table[index] ~= l_hash or (n_hash ~= HASH_FOR_GENERIC and n_hash ~= self.inv_table[index + 1]) then
            goto continue
        end -- collision check

        local slot = self.inv_table[index + 4]
        local item = inventory.getStackInSlot(sides_api.front, slot)
        if lable ~= item.label or (name ~= nil and name ~= item.name) then goto continue end -- this is a collision

        something_found = index -- the big thing
        if true then break end

        ::continue::
    end

    return something_found
end

-- special definitions will not be stored per se (they'll not be treated in a special manner)
function Module:addOrCreate(lable, name, to_be_added, suggested_slot)
    name = bucket_funcs.identify(name, lable)

    local index = self:findIndex(lable, name)
    if index ~= -1 then 
        self.inv_table[index + 2] = self.inv_table[index + 2] + to_be_added
        return
    end -- else we need to add another entry

    suggested_slot = self:findSuggestedSlot(lable, name, suggested_slot)

    -- the horror, there is no example slot!
    if suggested_slot == nil then
        comms.robot_send("error", "HORRIBLE THING HAPPENED :)")
        return
    end

    local new_offset = #self.inv_table + 1
    self.inv_table[new_offset] = l_hash
    if n_hash ~= nil then
            self.inv_table[new_offset + 1] = n_hash
    else    self.inv_table[new_offset + 1] = 0 end

    self.inv_table[new_offset + 2] = to_be_added
    self.inv_table[new_offset + 3] = suggested_slot 
end

function Module:subtract(name, lable, to_remove, suggested_slot)
    name = bucket_funcs.identify(name, lable)

    local index = self:findIndex(lable, name)
    if index == -1 then 
        comms.robot_send("error", "Attempted to remove something that didn't exist")
        return
    end
    self.inv_table[index + 2] = self.inv_table[index + 2] - to_remove
    if self.inv_table[index + 2] == 0 then -- we'll have to remove the entry and compact the table
        -- everything to the right of this entry needs to be "pulled down" three slots
       for i = index + 4, #self.inv_table, 4 do
            self.inv_table[i - 4] = self.inv_table[i]
            self.inv_table[i + 1 - 4] = self.inv_table[i + 1]
            self.inv_table[i + 2 - 4] = self.inv_table[i + 2]
            self.inv_table[i + 3 - 4] = self.inv_table[i + 3]
       end
       -- and then the last entry needs to get le deleted
       local le_end = #self.inv_table
       self.inv_table[le_end] = nil
       self.inv_table[le_end - 1] = nil
       self.inv_table[le_end - 2] = nil
       self.inv_table[le_end - 3] = nil
    end
end

-- TODO - collision checking? (because this one might be called from anywhere)
function Module:howMany(name, lable)
    name = bucket_funcs.identify(name, lable)
    local index = self:findIndex(lable, name)
    if index == -1 then return 0 end

    return self.inv_table[index + 2]
end

function Module:howManyPermissive(name)
    name = bucket_funcs.identify(name, lable)

end

return Module
