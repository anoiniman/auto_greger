local reason_obj = {}

local comms = require("comms")
local deep_copy = require("deep_copy")

local MetaRecipe = require("reasoning.MetaRecipe")
local MSBuilder, Goal, Requirement = require("reasoning.MetaScript")

-- Have the recipes be dynamically loaded-unloaded with doFile, rather than required
-- because, you, know there are a lot of recipes, do the same for scripts
-- But we can auto_doFile some debug shits, because we're nice I guess

local scripts = {}
scripts[1] = dofile("/home/robot/reasoning/scripts/debug/01.lua")
-- local recipes = {}

local cur_script = nil
function reason_obj.reason()
    error(comms.robot_send("fatal", "TODO! reason_obj.reason"))
end

function reason_obj.list_scripts()
    for index, script in ipairs(scripts) do
        print(comms.robot_send("info", index .. " -- " .. script.desc))
    end
end

function reason_obj.force_load(index)
    cur_script = scripts[index]
    if cur_script ~= nil then
        print(comms.robot_send("info", "selected script: " .. index .. " -- " .. desc))
    else
        print(comms.robot_send("error", "(doesn't exist) script with index: " .. index))
    end
end

function reason_obj.step_script()
    cur_script. 
end

return reason_obj
