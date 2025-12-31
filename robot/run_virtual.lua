-- #!/bin/bash
-- package.path = "../testing/virtual/?.lua;" .. package.path
package.path = "../shared/?.lua;" .. package.path
package.path = "virtual/interface/?.lua;" .. package.path
package.path = "virtual/interface/?/init.lua;" .. package.path

package.path = "virtual/def/?.lua;" .. package.path
-- package.path = "virtual/def/?/init.lua;" .. package.path

V_ENV = true
local render = require("librender")

-- local robot_step = require("robo_main")
local function sleep(n)
    local n = tonumber(n)
    if n == nil then return end

    local str = tostring(n) .. "s"
    os.execute("sleep " .. str)
end
os.sleep = sleep


local depp_copy = require("deep_copy")
local World = require("virtual.World")
local RobotRep = require("virtual.RobotRep")

-- local TestInterface, tests = table.unpack{require("tests")}
local test_interface = require("virtual.tests")
local test_table = require("virtual.tests.test_table")


local world = World:default()
local robot_rep = RobotRep:new(world)
robot_rep:setPosition(3, 3, 3)
world:setRobotRep(robot_rep)

print("------------ RAY LIB ---------------")
print()
render.init()
print()
print("------------ RAY LIB ---------------")
print()


world:init()

local render_ok = 2
while render_ok == 2 do
    step_ok = World:simulate(robot_step)
    render_ok = render.render(world.render, world, world.renderRobot, world)
end

