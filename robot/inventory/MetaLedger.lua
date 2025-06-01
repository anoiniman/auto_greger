local deep_copy = require("deep_copy")
local comms = require("comms")

local SpecialDefinition = require("inventory.SpecialDefinition")
local bucket_functions, item_buckets = table.unpack(require("inventory.item_buckets"))

-- special_ledger does not have buckets
local Module = {ledger_proper = nil, special_ledger = nil}
-- Changed it so that there is an actual "duplicate" bucket rather than simply spilling the lables all over the place
function Module:new()
    local new = deep_copy.copy(self, pairs)
    -- buckets will now be lazily initialised
    new.ledger_proper = {}

    return new
end

local function access_bucket(ledger, bucket) -- returns inner_ref
    if ledger == nil then
        error(comms.robot_send("fatal", "MetaLedger, attempted to access non-existing ledger?!?!?!"))
    end

    if ledger[bucket] == nil then ledger[bucket] = {} end
    return ledger[bucket]
end

function Module:addOrCreate(name, lable, quantity)
    --if string.find(name, "gt.metaitem") then -- the question of meta-items is complex and I gave it thought
    local bucket, is_special = bucket_functions.identify(name, lable)
    if is_special ~= nil then
        self:specialAddOrCreate(bucket, lable)
        return
    end
    if bucket == "duplicate" then -- will fukkie wukkie if this still remains ambiguous :$
        local dup_bucket = access_bucket(self.ledger_proper, bucket)
        local lable_bucket = access_bucket(dup_bucket, lable)
        local entry_quantity = lable_bucket[name] -- num

        if entry_quantity == nil then
            lable_bucket[name] = quantity
            return
        end
        lable_bucket[name] = entry_quantity + quantity
        return
    end

    local bucket_inner = access_bucket(self.ledger_proper, bucket)
    local entry_quantity = bucket_innter[lable]

    if entry_quantity == nil then
        bucket_innter[lable] = quantity
        return
    end
    bucket_innter[lable] = entry_quantity + quantity
end

function Module:specialAddOrCreate(bucket, lable) -- specials are probably non-stackable, right? Maybe not
    local new_definition = SpecialDefinition:new(bucket)
    local material, level = bucket_functions.material.identify(lable)
    if material == nil then
        error(comms.robot_send("fatal", "wasn't able to identify special, ID of GT tools still unimplemented"))
        --return false
    end
    new_definition.material = material
    new_definition.item_level = level
    table.insert(self.special_ledger, new_definition)
end

-- TODO --> We also need to programme in something that detects when tools break!
function Module:subtract(name, lable, to_remove) -- does not accept special items
    local bucket, is_special = bucket_functions.identify(name, lable)
    if is_special ~= nil then
        print(comms.robot_send("warning", "Ledger: attempted to delete something \"special\""))
        return false
    end

    local identifier
    local bucket_ref = access_bucket(self.ledger_proper, bucket)

    if bucket == "duplicate" then
        identifier = name
        bucket_ref = access_bucket(self.ledger_proper, lable)
    else
        identifier = lable
    end
    local quantity = bucket_ref[identifier]

    if quantity == nil then
        print(comms.robot_send("warning", "Ledger: attempted to delete something that doesn't exist"))
        return false
    elseif quantity <= 0 then
        print(comms.robot_send("warning", "Ledger: attempted to delete something is already at 0"))
        return false
    end

    local calc = quantity - to_remove
    bucket_ref[identifier] = math.max(calc, 0)
    return true
end

function Module:howMany(name, lable) -- not implemented for special items, for now
    local bucket, is_special = bucket_functions.identify(name, lable)
    if is_special then
        print(comms.robot_send("warning", "trying to count a special item in ledger, thats bad"))
        return -1
    end

    if bucket == "duplicate" then
        local to_return = self.ledger_proper[lable][name]
        if to_return == nil then return 0 end
        return to_return
    end
    local to_return = self.ledger_proper[bucket][lable]
    if to_return == nil then return 0 end
    return to_return
end

-- Only compares ledger proper, not special ledgers
function Module:compareWithLedger(other)
    for bucket, identifiers in pairs(self.ledger_proper) do
        if bucket == "duplicate" then
            
            
            goto continue
        end

        ::continue::
    end
end

-- We'll be assuming that name's always have a ':' in them and lables never have a ':' in them
--[[function Module:returnComplement(name_or_lable)
end--]]

return Module
