local reason_obj = {}

local comms = require("comms")
local deep_copy = require("deep_copy") -- luacheck: ignore

local MetaScriptTable = require("reasoning.MetaScript")
local MetaScript = MetaScriptTable[#MetaScriptTable]

-- TODO combing through the wait list
-- if element.useBuilding ~= nil and element:useBuilding("check")

-- luacheck: globals REASON_WAIT_LIST
REASON_WAIT_LIST = {}
function REASON_WAIT_LIST:checkAndAdd(build)
    for _, element in ipairs(self) do
        if element == build then return end
    end
    table.insert(self, build)
end


-- Have the recipes be dynamically loaded-unloaded with doFile, rather than required
-- because, you, know there are a lot of recipes, do the same for scripts
-- But we can auto_doFile some debug shits, because we're nice I guess

local scripts = {}
scripts[1] = dofile("/home/robot/reasoning/scripts/debug/06.lua")
-- local recipes = {}

-- TEMPORARY TODO, update cur_script programatically
local cur_script = scripts[1]

-- the only thing we need to save is the locks of the goals lol
function reason_obj.get_data()
    local cur_script_desc = nil
    local script_tbl = {}
    for index, script in ipairs(scripts) do
        if script == cur_script then
            cur_script_desc = script.desc
        end

        -- "loaded" is a temporary value that determins if we've already loaded this in the current session (when we load)
        -- (Just make sure to not "name" any script as "loaded")
        local table_of_goals = {meta = false}
        for _, goal in ipairs(script.goals) do
            -- table so that it is expandable in the future
            local lock_value = goal.constraint.const_obj.lock[1]
            local inner_table = {goal.constraint.const_obj.lock[1]}
            table_of_goals[goal.name] = inner_table
        end

        script_tbl[script.desc] = table_of_goals
    end
    if cur_script_desc == nil then
        print(comms.robot_send("error", "Saving reas_obj, couldn't find index to cur_script??? defaulting to \"default\""))
        cur_script_desc = "default"
    end

    local big_table = {
        script_tbl,
        cur_script_desc
    }
    return big_table
end

local save_table
local function try_load_script(real_script, desc)
    local goal_table = save_table[1][desc]
    if goal_table.loaded then
        print(comms.robot_send("debug", "Tried to load a script that was already loaded!"))
        return
    end

    goal_table.loaded = true
    for _, goal in ipairs(real_script.goals) do
        local inner_table = goal_table[goal.name]
        if inner_table == nil then
            print(comms.robot_send("warning", "Loading Script state, goal name unmatched in save file, did you add a new goal?"))
            goto continue
        end
        goal.constraint.const_obj.lock[1] = inner_table[1]

        ::continue::
    end
end

function reason_obj.re_instantiate(big_table)
    save_table = big_table[1]
    local save_script_desc = big_table[2]

    local s_index = -1
    for index, script in ipairs(scripts) do
        if script.desc == save_script_desc then
            cur_script = scripts[index]
            success = true
            break
        end
    end
    if s_index == -1 then
        print(comms.robot_send("error", "error in loading script"))
        return
    end
    try_load_script(cur_script, s_index)
end


function reason_obj.list_scripts()
    for index, script in ipairs(scripts) do
        print(comms.robot_send("info", index .. " -- " .. script.desc))
    end
end

function reason_obj.force_load(index)
    cur_script = scripts[index]
    if cur_script ~= nil then
        print(comms.robot_send("info", "selected script: " .. index .. " -- " .. cur_script.desc))
    else
        print(comms.robot_send("error", "(doesn't exist) script with index: " .. index))
    end
end

local loaded = false
function reason_obj.step_script()
    if not loaded then
        reason_obj.force_load(1)
        loaded = true
    end
    return cur_script:step()
end

return reason_obj
