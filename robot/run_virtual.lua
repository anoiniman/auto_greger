-- luacheck globals V_ENV INV_SIZE

package.path = "../shared/?.lua;" .. package.path
package.path = "virtual/interface/?.lua;" .. package.path
package.path = "virtual/interface/?/init.lua;" .. package.path

package.path = "virtual/def/?.lua;" .. package.path

V_ENV = true
INV_SIZE = 32
local render = require("librender")

local robot_step = require("robo_main")
local post_exit = require("post_exit")

-- luacheck pop ignore

local deep_copy = require("deep_copy")
local World = require("virtual.World")
local RobotRep = require("virtual.RobotRep")

-- local TestInterface, tests = table.unpack{require("tests")}
local test_interface = require("virtual.tests")
local test_table = require("virtual.tests.test_table")



--[[local world = World:default()
local robot_rep = RobotRep:new(world)
robot_rep:setPosition(3, 3, 3)
world:setRobotRep(robot_rep)--]]

print("------------ RAY LIB ---------------")
print()
render.init()
print()
print("------------ RAY LIB ---------------")
print()


local test = require("virtual.tests.interface_test")
test:initWorld()
--world:init()

local function sleep(n)
    n = tonumber(n)
    if n == nil then return end
    --[[local str = tostring(n) .. "s"
    os.execute("sleep " .. str)--]]
    local ntime = os.clock() + n
    repeat
        render.render(test.world.render, test.world, test.world.renderRobot, test.world)
    until os.clock() > ntime
end
-- luacheck push ignore
os.sleep = sleep


local act_clock
local act_time = 0.5
function FORCE_RENDER()
    act_clock = os.clock()

    while act_clock + act_time > os.clock() do
        render.render(test.world.render, test.world, test.world.renderRobot, test.world)
    end
end


local simulate_time = 0.33
local simulate_clock = os.clock()

local step_ok
local render_ok = 2
while render_ok == 2 do
    if os.clock() > simulate_clock + simulate_time then
        step_ok = test:doStep(robot_step)
        simulate_clock = os.clock()
    end

    render_ok = render.render(test.world.render, test.world, test.world.renderRobot, test.world)
end

