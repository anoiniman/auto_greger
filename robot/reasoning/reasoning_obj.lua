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

--[[
local MetaRecipe = require("reasoning.MetaRecipe")
local MSBuilder, Goal, Requirement = table.unpack(require("reasoning.MetaScript"))
--]]

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
