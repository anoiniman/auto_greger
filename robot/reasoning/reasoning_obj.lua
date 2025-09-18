local reason_obj = {}

local comms = require("comms")
local deep_copy = require("deep_copy") -- luacheck: ignore
local computer = require("computer")

-- local MetaScriptTable = require("reasoning.MetaScript")
-- local MetaScript = MetaScriptTable[#MetaScriptTable]

-- TODO combing through the wait list
-- wait list of goals, force check / step them?

local scripts = {}
scripts[1] = dofile("/home/robot/reasoning/scripts/stone_age/01.lua")
-- local recipes = {}

-- TEMPORARY TODO, update cur_script programatically
local cur_script = scripts[1]


-- luacheck: globals REASON_WAIT_LIST
REASON_WAIT_LIST = {}
function REASON_WAIT_LIST:checkAndAdd(goal, old_lock_value)
    for _, element in ipairs(self) do
        if element[1] == goal then return end
    end
    if old_lock_value == nil then old_lock_value = 1 end

    -- recording lock_value like this doesn't work, because it gets made in-operable before anything else,
    -- so I don't know, where I can perserve it correctly TODO
    goal.constraint.const_obj.lock[1] = 4

    local time_stamp = computer.uptime()
    local inner_table = {goal.name, time_stamp, old_lock_value}
    table.insert(self, #self + 1, inner_table)
end
function REASON_WAIT_LIST:checkAndStep()
    if #REASON_WAIT_LIST == 0 then return nil end

    local selected_index = -1
    for index, element in ipairs(self) do
        if computer.uptime() - element[2] > 12 then -- wait 12 seconds and try again
            selected_index = index
            break
        end
    end
    if selected_index == -1 then return nil end

    local selected_element = table.remove(REASON_WAIT_LIST, selected_index)
    -- Now it is out of the table

    local goal_name = selected_element[1]
    local old_lock = selected_element[3]
    return cur_script:step(goal_name, old_lock)
end


-- Have the recipes be dynamically loaded-unloaded with doFile, rather than required
-- because, you, know there are a lot of recipes, do the same for scripts
-- But we can auto_doFile some debug shits, because we're nice I guess


-- the only thing we need to save is the locks of the goals lol
function reason_obj.get_data()
    local cur_script_desc = nil
    local script_tbl = {}
    for index, script in ipairs(scripts) do
        script_tbl[index] = {}
        if script == cur_script then
            cur_script_desc = script.desc
        end

        -- "loaded" is a temporary value that determins if we've already loaded this in the current session (when we load)
        -- (Just make sure to not "name" any script as "loaded")
        local table_of_goals = {meta = false}
        for _, goal in ipairs(script.goals) do
            -- table so that it is expandable in the future
            local lock_value = goal.constraint.const_obj.lock[1]
            local pe_executed = goal.pe_executed
            local inner_table = {lock_value, pe_executed}
            table_of_goals[goal.name] = inner_table
        end

        script_tbl[index][script.desc] = table_of_goals
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
    -- the fact that we only load the first index is temporary
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
        -- Uncommented when needed
        goal.pe_executed = inner_table[2]

        ::continue::
    end
end

function reason_obj.re_instantiate(big_table)
    save_table = big_table[1]
    local save_script_desc = big_table[2]

    -- useless block?
    local s_index = -1
    for index, script in ipairs(scripts) do
        if script.desc == save_script_desc then
            cur_script = scripts[index]
            s_index = index
            break
        end
    end
    if s_index == -1 then
        print(comms.robot_send("error", "error in loading script"))
        return
    end
    ---

    -- try_load_script(cur_script, s_index)
    try_load_script(cur_script, save_script_desc)
end


function reason_obj.list_scripts()
    for index, script in ipairs(scripts) do
        print(comms.robot_send("info", index .. " -- " .. script.desc))
    end
end

-- After a crash or an exit locks that in state '1' (being worked on) no longer represent well
-- their state since the command queue is not saved as well, so you need to reset these
-- locks (BE CAREFUL IF YOU ARE IN A CAVE/MINE OR SOME OTHER THING)
function reason_obj.reset_one_locks()
    for _, script in ipairs(scripts) do
        for _, goal in ipairs(script.goals) do
            local lock = goal.constraint.const_obj.lock
            if lock[1] == 1 then lock[1] = 0 end
        end
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

    local return_type, command_table = REASON_WAIT_LIST:checkAndStep()
    if command_table ~= nil then return return_type, command_table end

    return cur_script:step()
end

function reason_obj.print_print_dud()
    cur_script:printLatestDud()
end

function reason_obj.create_temp_dependency(recipe_name, recipe_mult)
    return cur_script:createTempDependency(recipe_name, recipe_mult)
end

return reason_obj
