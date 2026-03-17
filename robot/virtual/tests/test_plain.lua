local nav_tracking = require("virtual.tests.navigation")
local RobotRep = require("virtual.RobotRep")
local World = require("virtual.World")
local test_interface = require("virtual.tests")

local a = require("virtual.Block")
local _, KnownBlocks = table.unpack(a)
local KnownItems = require("virtual.item.KnownItems")

local oak_generator = require("virtual.schematics.oak_tree")


local command_list = {
}

-- local world = World:empty(16+4, 16+4, 24, robot_rep, {3, 3, 0})
local world = World:empty(92, 92, 12, robot_rep)
local robot_rep = RobotRep:new(world)
world:setRobotRep(robot_rep)
robot_rep:setPosition(0, 0, 2)

local z_size = 90
local x_size = 90
world.block_set:addPrism(KnownBlocks:default(), 1, 1, 0, z_size, 0, x_size)

local test = test_interface:addTest(world, __f_pass, __f_fail, command_list, __f_init)

local oak_schematic, oak_dictionary, oak_rel_offset = table.unpack(oak_generator.generate(KnownBlocks))
local function geco(coords)
    for k, v in ipairs(oak_rel_offset) do
        coords[k] = coords[k] + v
    end

    return coords
end

local function doco(coords)
    coords = geco(coords)
    world.block_set:parseNativeSchematic(
        oak_schematic,
        oak_dictionary,
        coords,
        true
    )
end

-- doco({3, 10, 4})
-- doco({5, 6, 4})

local yindex = 2
local cur_coords = {}
for i = 1, 200, 1 do
    local coords = {math.random(6, x_size - 6), math.random(6, z_size - 6), 2}
    for _, other in ipairs(cur_coords) do
        local dist = math.abs(coords[1] - other[1]) + math.abs(coords[2] - other[2])
        if dist < 8 then goto continue end
    end
    doco(coords)
    table.insert(cur_coords, coords)
    
    ::continue::
end


return test
