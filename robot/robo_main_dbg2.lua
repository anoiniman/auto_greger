-- import of globals
local math = require("math")
local io = require("io")

local robot = require("robot")
local term = require("term")
local text = require("text")
local serialize = require("serialization")

-- local imports
local comms = require("comms")
local nav = require("nav_module")
local geolyzer = require("geolyzer_wrapper")

local command = nil
--local robot_routine = coroutine.create(robot_routine_func)
local robot_routine = nil

local block_read_bool = true
-- 0 = continue, 1 = stop
local watch_dog = 0
local history = {}

term.clear()
print(comms.robot_send("info", "Now Online!"))
term.setCursorBlink(false)


