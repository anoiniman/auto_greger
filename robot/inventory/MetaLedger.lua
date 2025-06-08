local deep_copy = require("deep_copy")
local comms = require("comms")

-- luacheck: push ignore item_buckets
local SpecialDefinition = require("inventory.SpecialDefinition")
local bucket_functions, item_buckets = table.unpack(require("inventory.item_buckets"))
-- luacheck: pop

-- special_ledger does not have buckets
local Module = {ledger_proper = nil, special_ledger = nil}
-- Changed it so that there is an actual "duplicate" bucket rather than simply spilling the lables all over the place
function Module:new()
    local new = deep_copy.copy(self, pairs)
    -- buckets will now be lazily initialised
    new.ledger_proper = {}

    return new
end

local function access_bucket(ledger, bucket, do_not_create) -- returns inner_ref
    if ledger == nil then error(comms.robot_send("fatal", "MetaLedger, attempted to access non-existing ledger?!?!?!")) end
    if do_not_create == nil then do_not_create = false end

    if not do_not_create and ledger[bucket] == nil then ledger[bucket] = {} end
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
    local entry_quantity = bucket_inner[lable]

    if entry_quantity == nil then
        bucket_inner[lable] = quantity
        return
    end
    bucket_inner[lable] = entry_quantity + quantity
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

local function generic_bucket_ref(ledger, bucket, lable, name, do_not_create)
    local bucket_ref = access_bucket(ledger, bucket)
    local identifier

    if bucket == "duplicate" then
        if bucket_ref == nil then return nil end

        identifier = name
        bucket_ref = access_bucket(bucket_ref, lable, do_not_create)
    else
        identifier = lable
    end

    return bucket_ref, identifier
end

-- TODO --> We also need to programme in something that detects when tools break!
function Module:subtract(name, lable, to_remove) -- does not accept special items
    local bucket, is_special = bucket_functions.identify(name, lable)
    if is_special ~= nil then
        print(comms.robot_send("warning", "Ledger: attempted to delete something \"special\""))
        return false
    end

    local bucket_ref, identifier = generic_bucket_ref(self.ledger_proper, bucket, lable, name)
    local quantity = bucket_ref[identifier]

    if quantity == nil then
        print(comms.robot_send("warning", "Ledger: attempted to delete something that doesn't exist"))
        return false
    elseif quantity <= 0 then
        print(comms.robot_send("warning", "Ledger: attempted to delete something is already at 0"))
        return false
    end

    local calc = quantity - to_remove
    if calc < 0 then
        bucket_ref[identifier] = nil
        return true
    end
    bucket_ref[identifier] = math.max(calc, 0)
    return true
end

-- returns a list with all valid entries that follow this expansion
function Module:macroExpand(name, expansion_rule)
    if expansion_rule == "any_expansion" then
        error(comms.robot_send("fatal", "MetaLedger todo!"))
    elseif expansion_rule == "naive_contains" then
        error(comms.robot_send("fatal", "MetaLedger todo!"))
    elseif expansion_rule == "expand_bucket" then
        return self.ledger_proper[name]
    else
        error(comms.robot_send("fatal", "MetaLedger marcoExpand bad option!"))
    end
end

-- Faking hell, I can tell that this is going to crash the robot one day VVV

-- how many but from incomplete information dependent on macro expansion
function Module:tryDetermineHowMany(name, lable, check_type)
    local count = 0
    if name == "duplicate" then
        error(comms.robot_send("fatal", "unsupported"))
    elseif name ~= "nil" then
        local matches = self:macroExpand(name, check_type)
        for _, quantity in ipairs(matches) do
            count = count + quantity
        end
    else
        error(comms.robot_send("fatal", "todo"))
    end

    return count
end

function Module:howMany(name, lable) -- not implemented for special items, for now
    local bucket, is_special = bucket_functions.identify(name, lable)
    if is_special then
        print(comms.robot_send("warning", "trying to count a special item in ledger, thats bad"))
        return -1
    end

    local bucket, id = generic_bucket_ref(self.ledger_proper, bucket, lable, name, true)
    if bucket == nil then return 0 end
    local to_return = bucket[id]

    if to_return == nil then return 0 end
    return to_return
end

local ComparisonDiff = {
    name = nil,
    lable = nil,
    diff = 0
}
function ComparisonDiff:new(name, lable, diff)
    local new = deep_copy.copy(self, pairs)
    new.name = name
    new.lable = lable
    new.diff = diff

    return new
end


-- Only compares ledger proper, not special ledgers
function Module:compareWithLedger(other)

    local function inner_comparison(bucket, lable, name, other_quantity, own_ledger)
        local our_ref, our_id = generic_bucket_ref(own_ledger, bucket, lable, name, true)

        local own_quantity
        if our_ref == nil then own_quantity = nil
        else own_quantity = our_ref[our_id] end
        --
        if own_quantity == nil then own_quantity = 0 end

        local diff = own_quantity - other_quantity
        local diff = ComparisonDiff:new(name, lable, diff)
        return diff
    end

    local diff_table = {}
    for bucket_key, lable_table in pairs(other) do
        for lable, quantity in pairs(lable_table) do
            if bucket_key == "duplicate" then   -- quantities aren't quantities they are a inner lable[name] table
                -- luacheck: push ignore quantity (funny shadowing)
                local name_table = quantity
                for name, quantity in pairs(name_table) do
                    local diff = inner_comparison(bucket_key, lable, name, quantity, self.ledger_proper)
                    table.insert(diff_table, diff)
                end
                goto skip_over
            end -- else
            -- luacheck: pop

            local diff = inner_comparison(bucket_key, lable, nil, quantity, self.ledger_proper)
            table.insert(diff_table, diff)
        end
        ::skip_over::
    end

    return diff_table
end

-- We'll be assuming that name's always have a ':' in them and lables never have a ':' in them
--[[function Module:returnComplement(name_or_lable)
end--]]

return Module
