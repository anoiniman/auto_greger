-- local serialize = require("serialization")
-- local comms = require("comms")

local MSBuilder, Goal, Constraint, StructureDeclaration = table.unpack(require("reasoning.MetaScript"))

local desc = "Debug 01 - Build me a coke oven, you brat!"
local builder = MSBuilder:new_w_desc(desc)

--local serial = serialize.serialize(StructureDeclaration, true)
--print(comms.robot_send("info", serial))

local coke_oven = StructureDeclaration:new("coke_quad", 0, 0, 1)
local constraint = Constraint:newBuildingConstraint(coke_oven, nil)

local simple_goal = Goal:new(nil, constraint, 60, "CokeTest", true)
builder:addGoal(simple_goal)

local script = builder:build()

return script
