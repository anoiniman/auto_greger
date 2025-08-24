local deep_copy = require("deep_copy")
local comms = require("comms")
local inv = require("inventory.inv_obj")

local RawQuestItem = {
    lable = nil,
    name = nil,
    count = nil,
}
function RawQuestItem:new(lable, name, count)
    local new = deep_copy.copy(self, pairs)
    new.lable = lable or "nil"
    new.name = name or "nil"

    if count == nil then
        print(comms.robot_send("warning", "count warning:\n" .. debug.traceback()))
    end
    new.count = count or -1
    return new
end

-- This is basically a table of simplified ItemConstraint but that will be treated differently by the resolution system etc etc.
local OosConstraint = {
    quest_item_tbl = nil,
    lock = {0},
}

function OosConstraint:new(rq_table) -- maybe this internal thing will never be used
    local new = deep_copy.copy(self, pairs)
    new.quest_item_tbl = rq_table
    return new
end

--[[function OosConstraint:finishUp()
end--]]

-- These quests are always do_once, we'll need a special lock value to represent this being done because of weirdness
-- this means that the Oos finisher thing should not mees with the lock,or at the very list force lock it to 5
function OosConstraint:check() -- so this was easy?
    local do_once = false
    if self.lock[1] == 1 or self.lock[1] == 4 then
        return nil, nil -- Hold It
    end
    if self.lock[1] == 5 then return 0, nil end

    if self.lock[1] == 3 then
        if do_once then return 0, nil end -- This condition is "cleared", but there is nothing to do
        -- else set the lock back to 0, and allow the checks to go through unmolested
        self.lock[1] = 0
    end

    for _, def in ipairs(self.quest_item_tbl) do
        local real_quantity = inv.how_many_total(def.lable, def.name)
        if real_quantity < def.count then
            return 1, {name = self.name, lable = self.lable}
        end
    end

    -- Then when we've got everything, make sure we have everything on our inventory and go to the oos, if not everything is on
    -- our inventory, then take the current inv.load_out, deep_copy it, modify it to add the items we need, and go for it
    -- and make our thing very high priority

    -- check if the current layout got what we need
    local cur_loadout = inv.get_cur_loadout()

    for _, o_def in ipairs(self.quest_item_tbl) do
        for l_def in ipairs(cur_loadout) do
            if o_def.lable == l_def[1] and o_def.name == l_def[2] then -- there is a match
                def_existed = true

                if o_def.count > l_def[3] then -- the def doesn't have enough oomph
                    l_def[3] = o_def.count
                end
                goto continue
            end
            -- else if it doesn't match keep looking for a match
        end -- for

        -- if no match was found, add a new definition to cur_loadout
        local new_def = {o_def.lable, o_def.name, o_def.count, o_def.count}
        table.insert(cur_loadout, new_def)

        ::continue::
    end
    local new_loadout = cur_loadout

    local all_ready = true
    for _, def in ipairs(self.quest_item_tbl) do -- check the cur in inv
        local real_quantity = inv.how_many_internal(def.lable, def.name)
        if real_quantity < def.count then
            return 1, {c_type = "OosLogisticTransfer" , loadout = new_loadout}
        end
    end

    return 1, {c_type = "OosFinish"} -- it is impossible for the robot to know that the game has accepts its attempt, so.... don't fail
    self.lock[1] = 5
    -- error(comms.send_unexpected(true))
end

return {OosConstraint, RawQuestItem}
