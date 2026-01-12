local nav_tracking = require("virtual.tests.navigation")
local RobotRep = require("virtual.RobotRep")
local World = require("virtual.World")
local test_interface = require("virtual.tests")

local a = require("virtual.Block")
local _, KnownBlocks = table.unpack(a)

local command_list = {
    "debug inv force add_all",
    "debug inv print internal",
    "debug move east 4",
    "debug move north 2",
}

local counter = 0
local function __f_pass (test)
    if #test.command_list == 0 then counter = counter + 1 end
    if counter == 20 then return true end
    return false
end

local world = World:empty(16, 16, 24, robot_rep)
local robot_rep = RobotRep:new(world)
world:setRobotRep(robot_rep)
robot_rep:setPosition(8, 8, 4)

world.blocks:addPrism(KnownBlocks:default(), 0, 3, 0, 15, 0, 15)

local test = test_interface:addTest(world, __f_pass, __f_fail, command_list)
test:trackObj(table.unpack(nav_tracking))

return test
