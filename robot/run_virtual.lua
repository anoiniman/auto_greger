-- luacheck globals V_ENV INV_SIZE
local old_dofile = dofile
function dofile (path)
    path = string.gsub(path, "/home/robot/", "./")
    return old_dofile(path)
end

package.path = "../shared/?.lua;" .. package.path
package.path = "virtual/interface/?.lua;" .. package.path
package.path = "virtual/interface/?/init.lua;" .. package.path

package.path = "virtual/def/?.lua;" .. package.path

V_ENV = true
INV_SIZE = 32
local render = require("librender")
local robot_step = require("robo_main")

-- luacheck pop ignore

local deep_copy = require("deep_copy")
local World = require("virtual.World")
local RobotRep = require("virtual.RobotRep")

-- local TestInterface, tests = table.unpack{require("tests")}
local test_interface = require("virtual.tests")
local test_table = require("virtual.tests.test_table")


-- post_exit.do_presets()
-- post_exit.load_state({})

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


-- local test = require("virtual.tests.interface_test")
local test = require("virtual.tests.2interdependent_tasks")
test:initWorld()
--world:init()

local simulate_time = 0.33
local simulate_clock = os.clock()
local function evaluate_render(render_result)
    if render_result == 2 then 
        test.world.robot_rep:printInventory()
        table.insert(test.command_list, "debug inv print internal") -- temp
    elseif render_result == 3 then 
        print(test.world.robot_rep:getPosition())
        table.insert(test.command_list, "debug print nav") -- temp
    elseif render_result == 10 then
        paused = true
    elseif render_result == 11 then
        simulate_time = 1
    elseif render_result == 12 then
        simulate_time = 330 / 1000
    elseif render_result == 13 then
        simulate_time = 80 / 1000
    elseif render_result == 14 then
        simulate_time = 10 / 1000
    end
end


local function sleep(n)
    n = tonumber(n)
    if n == nil then return end
    --[[local str = tostring(n) .. "s"
    os.execute("sleep " .. str)--]]
    
    local arbitrary_tick_rate = 4
    local sim_steps = arbitrary_tick_rate * n
    for i = 0, sim_steps, 1 do
        step_ok = test:doStep(robot_step, false)
        if sim_steps % 20 == 0 then
            evaluate_render(render.render(test.world.render, test.world, test.world.renderRobot, test.world))
        end
    end
    evaluate_render(render.render(test.world.render, test.world, test.world.renderRobot, test.world))
end
-- luacheck push ignore
os.sleep = sleep


function FORCE_RENDER()
    local act_clock = os.clock()
    while act_clock + simulate_time > os.clock() do
        evaluate_render(render.render(test.world.render, test.world, test.world.renderRobot, test.world))
    end
end


local paused = false
local step_ok
while true do
    if not paused and (os.clock() > simulate_clock + simulate_time) then
        step_ok = test:doStep(robot_step)
        simulate_clock = os.clock()
    end

    local render_result = render.render(test.world.render, test.world, test.world.renderRobot, test.world)
    if render_result == 1 then break
    else evaluate_render(render_result) end
end

