local reason_obj = {}

local comms = require("comms")
local deep_copy = require("deep_copy") -- luacheck: ignore

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
scripts[1] = dofile("/home/robot/reasoning/scripts/debug/01.lua")
-- local recipes = {}

local cur_script = nil

-- TODO there might be a big problem with the naive method of saving things and the waiting list which contains
-- references to things like Goals and Recipes, but we'll see
function reason_obj.get_data()
    local cur_script_index
    local no_func_scripts = {}
    for index, script in ipairs(scripts) do
        if script == cur_script then
            cur_script_index = index
        end
        table.insert(no_func_scripts, deep_copy.copy_no_functions(script))
    end
    if cur_script_index == nil then
        print(comms.robot_send("error", "Saving reas_obj, couldn't find index to cur_script??? defaulting to 1"))
        cur_script_index = 1
    end

    local big_table = {
        no_func_scripts,
        cur_script_index
    }
    return big_table
end

function reason_obj.re_insantiate(big_table)
    scripts = big_table[1]
    cur_script = scripts[big_table[2]]
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
