local nav_tracking = require("virtual.tests.navigation")
local RobotRep = require("virtual.RobotRep")
local World = require("virtual.World")
local test_interface = require("virtual.tests")

local a = require("virtual.Block")
local _, KnownBlocks = table.unpack(a)
local KnownItems = require("virtual.item.KnownItems")

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
        end,
    }
)

world.block_set:instantiateBuilding("oak_tree_farm", {0, 0}, 3, 4)

return test
