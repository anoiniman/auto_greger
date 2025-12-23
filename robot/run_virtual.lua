-- #!/bin/bash
-- package.path = "../testing/virtual/?.lua;" .. package.path
package.path = "../shared/?.lua;" .. package.path
package.path = "virtual/interface/?.lua;" .. package.path
package.path = "virtual/def/?.lua;" .. package.path

V_ENV = true
local render = require("librender")
local robot_step = require("robo_main")

local depp_copy = require("deep_copy")
local World = require("virtual.World")
local TestInterface, tests = table.unpack{require("tests")}

local world = World:default()
render.init()

local render_ok = 2
while render_ok == 2 do
    step_ok = World:simulate(robot_step)
    render_ok = render.render(world.render, world)
end

