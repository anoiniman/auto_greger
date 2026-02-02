local nav_tracking = require("virtual.tests.navigation")
local RobotRep = require("virtual.RobotRep")
local World = require("virtual.World")
local test_interface = require("virtual.tests")

local a = require("virtual.Block")
local _, KnownBlocks = table.unpack(a)
local KnownItems = require("virtual.item.KnownItems")


local map_obj = require("nav_module.map_obj")
local reas = require("reasoning.reasoning_obj")
reas.load_preset()
map_obj.virtual_preset()


local command_list = {
    "debug inv force add_all",
    "start_reason",
    -- "debug inv print internal",
    -- "debug move east 4",
    -- "debug move north 2",
}

local function __f_fail (test)
    if test.step_count > 100 * 100 then return 1 end
    return 0
end

local __f_pass = nil


local world = World:empty(16, 16, 24, robot_rep)
local robot_rep = RobotRep:new(world)
world:setRobotRep(robot_rep)
robot_rep:setPosition(2, 13, 4)

world.block_set:addPrism(KnownBlocks:default(), 0, 3, 0, 15, 0, 15)

local test = test_interface:addTest(world, __f_pass, __f_fail)
test.command_list = command_list

test:trackObj(table.unpack(nav_tracking))
test:trackObj(
    {
        __f_pass = function (inv_obj)
            local inv = inv_obj.virtual_inventory
            -- local log_num = inv:howMany("Oak Log", "any:log")
            local sap_num = inv:howMany("Oak Sapling", "any:sapling")
            if sap_num > 20 then -- num of saplings required by goal saplings02
                return true
            end

            return false
        end
    },
    "inv_track1",
    "inv_obj",
    nil
)

local build_chunk = {0, 0}
world.block_set:instantiateBuilding("oak_tree_farm", build_chunk, 3, 4)
world.block_set:instantiateBuilding("small_oak_farm", build_chunk, 3, 2)

local cogo = reas.complete_goal
cogo("__g_hole_home01")
cogo("__g_firstnight")

local dogo = reas.delete_goal
dogo("__g_planks01")
dogo("__g_planks02")


map_obj.pretend_build("home", "oak_tree_farm", build_chunk, 4)
map_obj.pretend_build("home", "small_oak_farm", build_chunk, 2)

local oak_sapling = KnownItems:getByLabel("Oak Sapling")
local oak_wood = KnownItems:getByLabel("Oak Wood")
if oak_sapling == nil then error() end
robot_rep.inventory:addToSlot(oak_sapling, 4, 11)
robot_rep.inventory:addToSlot(oak_wood, 8, 16)


--[[local oak_generator = require("virtual.schematics.oak_tree")
local oak_schematic, oak_dictionary, oak_rel_offset = table.unpack(oak_generator.generate(KnownBlocks))
local oak_coords = {3, 10, 4}
for k, v in ipairs(oak_rel_offset) do
    oak_coords[k] = oak_coords[k] + v
end
world.block_set:parseNativeSchematic(
    oak_schematic,
    oak_dictionary,
    oak_coords,
    true
)--]]

return test
