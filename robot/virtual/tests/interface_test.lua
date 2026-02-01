local nav_tracking = require("virtual.tests.navigation")
local RobotRep = require("virtual.RobotRep")
local World = require("virtual.World")
local test_interface = require("virtual.tests")

local a = require("virtual.Block")
local _, KnownBlocks = table.unpack(a)
local KnownItems = require("virtual.item.KnownItems")

local oak_generator = require("virtual.schematics.oak_tree")


local command_list = {
    "debug inv force add_all",
    "debug inv print internal",
    -- "debug move east 4",
    -- "debug move north 2",
}

local counter = 0
local function __f_pass (test)
    if #test.command_list == 0 then counter = counter + 1 end
    if counter == 4 then return true end
    return false
end

local world = World:empty(16, 16, 24, robot_rep)
local robot_rep = RobotRep:new(world)
world:setRobotRep(robot_rep)
robot_rep:setPosition(2, 13, 4)

local oak_schematic, oak_dictionary, oak_rel_offset = table.unpack(oak_generator.generate(KnownBlocks))
local oak_coords = {3, 10, 4}
for k, v in ipairs(oak_rel_offset) do
    oak_coords[k] = oak_coords[k] + v
end

world.block_set:addPrism(KnownBlocks:default(), 0, 3, 0, 15, 0, 15)
world.block_set:parseNativeSchematic(
    oak_schematic,
    oak_dictionary,
    oak_coords,
    true
)
-- world.block_set:instantiateBuilding("oak_tree_farm", {0, 0}, 3, 4)
-- world.block_set:instantiateBuilding("sp_storeroom", {0, 0}, 3, 1)

local test = test_interface:addTest(world, __f_pass, __f_fail, command_list)
test:trackObj(table.unpack(nav_tracking))

local oak_sapling = KnownItems:getByLabel("Oak Sapling")
local oak_wood = KnownItems:getByLabel("Oak Wood")
if oak_sapling == nil then error() end
robot_rep.inventory:addToSlot(oak_sapling, 4, 8)
robot_rep.inventory:addToSlot(oak_wood, 8, 32)

return test
