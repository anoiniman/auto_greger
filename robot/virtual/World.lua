-- luacheck: globals COPY, ignore deep_copy
local deep_copy = require("deep_copy")
local component = require("component")
local fake_pointer = require("fake_pointer")

local a = require("virtual.Block")
local Block, KnownBlocks = table.unpack(a)
local sides_api = require("sides")

local render_api = require("librender")


-- inner_array format: for a 3*3*2 universe
-- {
--    x1,z1,y1, x2,z1,y1, x3,z1,y1
--    x1,z2,y1, x2,z2,y1, x3,z2,y1
--    x1,z3,y1, x2,z3,y1, x3,z3,y1
--    --
--    x1,z1,y2, x2,z1,y2, x3,z1,y2
--    x1,z2,y2, x2,z2,y2, x3,z2,y2
--    x1,z3,y2, x2,z3,y2, x3,z3,y2

local BlockSet = {
    size_array = {
        fake_pointer.mut(8), -- x
        fake_pointer.mut(8), -- z
        fake_pointer.mut(8), -- y
    },
    size_x = nil,
    size_z = nil,
    size_y = nil,

    block_array = nil,
}
BlockSet.size_x = BlockSet.size_array[1]
BlockSet.size_z = BlockSet.size_array[2]
BlockSet.size_y = BlockSet.size_array[3]

-- There is something wierd with the "fake pointers" that the value is not getting updated
function BlockSet:new(size_x, size_z, size_y)
    local pos_args = {size_x, size_z, size_y}
    local new = COPY(self)
    new.size_x = new.size_array[1]
    new.size_z = new.size_array[2]
    new.size_y = new.size_array[3]

    for index, size_ptr in ipairs(new.size_array) do
        if pos_args[index] ~= nil then fake_pointer.replace(size_ptr, pos_args[index])
        else fake_pointer.replace(size_ptr, 8) end

        fake_pointer.lock(new.size_array[index])
    end
    local array_size = new.size_x() * new.size_z() * new.size_y()

    new.block_array = {}
    for i = 1, array_size, 1 do
        new.block_array[i] = 0
    end

    return new
end

function BlockSet:getCoords(index)
    index = index - 1

    local y = math.floor(index / (self.size_x() * self.size_z()))
    index = math.floor(index - (y * self.size_x() * self.size_z()))

    local z = math.floor(index / self.size_x())
    local x = (index % self.size_x())

    return x, z, y
end

function BlockSet:getIndex(x, z, y)
    -- local index = (x - 1) + (z - 1) * self.size_x() + (y - 1) * self.size_z() * self.size_x()
    local index = x + z * self.size_x() + y * self.size_z() * self.size_x()
    index = index + 1 -- lua shanenigans
    return index
end

function BlockSet:removeBlock(x, z, y)
    local index = self:getIndex(x, z, y)
    self.block_array[index] = nil
end

function BlockSet:addBlock(new_block, x, z, y)
    -- First, check for out of bounds
    local pos_args = {x, z, y}
    for index, size_ptr in ipairs(self.size_array) do
        local pos = pos_args[index]
        if pos > size_ptr() then
            error(string.format("block out of bounds -- (%d > %d) [%d]", pos, size_ptr(), index))
        end
    end

    self:addUnchecked(new_block, x, z, y)
end

function BlockSet:addUnchecked(new_block, x, z, y)
    -- print(self.size_x(), self.size_z(), self.size_y())
    -- print(x,z,y)

    local index = self:getIndex(x, z, y)
    -- print(index)
    -- print(self:getCoords(index))
    -- io.read()

    self.block_array[index] = new_block
    -- render_api.setIntArray(self.block_array, index, new_block);
end

function BlockSet:addLine(block, z, y, x1, x2)
    if x1 == nil or x2 == nil then x1 = 1; x2 = self.size_x() end
    -- for xindex = x1, x2, 1 do self:addBlock(block, xindex, z, y) end
    for xindex = x1, x2, 1 do self:addUnchecked(block, xindex, z, y) end
end

function BlockSet:addRectangle(block, y, z1, z2, x1, x2)
    for zindex = z1, z2, 1 do self:addLine(block, zindex, y, x1, x2) end
end

function BlockSet:addPrism(block, y1, y2, z1, z2, x1, x2)
    for yindex = y1, y2, 1 do self:addRectangle(block, yindex, z1, z2, x1, x2) end
end

local dic = {
    c = KnownBlocks:getByLabel("Cobblestone") or KnownBlocks:default(),
    b = KnownBlocks:getByLabel("kdfjs") or KnownBlocks:default(),
    d = KnownBlocks:getByLabel("Chest") or KnownBlocks:default(),
}

local schem = {
    {
    "dcccbcccc",
    "cdccbcccc",
    "ccdcbcccc",
    "cccdbcccc",
    "ccccdcccc",
    "ccccbdccc",
    "ccccbcdcc",
    "ddddddddd",
    }
}

function BlockSet:parseNativeSchematic(schematic_table, dictionary, offset_table)
    local x_offset, z_offset, y_offset = table.unpack(offset_table)
    x_offset = x_offset or 0
    z_offset = z_offset or 0
    y_offset = y_offset or 0

    for yindex, slice in ipairs(schematic_table) do
        yindex = yindex + y_offset
        for zindex, column in ipairs(slice) do
            zindex = zindex + z_offset

            local xindex = x_offset
            for char in string.gmatch(column, ".") do
                local block = dictionary[char]
                -- local block = Block:default()
                if char ~= '-' then self:addUnchecked(block, xindex, zindex, yindex) end
                xindex = xindex + 1
            end
        end
    end

end

-- How about we backport our bitmap map loader, with the height being mesured with the
-- r: channel, and blocktype by the g:channel, and the b channel reserved for later,
-- prob no need for an alpha channel
local World = {
    blocks = BlockSet:new(24, 24, 24),
    test_conditions = nil,
    robot_rep = nil,

    render_check = 0,
}

function World:default()
    local new = COPY(self)
    new.blocks:addPrism(Block:default(), 0, 2, 0, 2, 0, 2)
    return new
end

function World:empty(x_size, z_size, y_size, robot_rep)
    local new = COPY(self)
    new.blocks = BlockSet:new(x_size, z_size, y_size)
    new.robot_rep = robot_rep
    return new
end

function World:fromSchematic(schematic, dictionary, robot_rep)
    local new = COPY(self)
    local x_size, z_size, y_size
    x_size = -1
    z_size = -1
    y_size = #schematic
    for _, slice in pairs(schematic) do
        if #slice > z_size then z_size = #slice end
        for _, str in pairs(slice) do
            if string.len(str) > x_size then x_size = string.len(str) end
        end
    end

    new.blocks = BlockSet:new(x_size, z_size, y_size)
    new.blocks:parseNativeSchematic(schematic, dictionary)

    new.robot_rep = robot_rep
    return new
end

function World:setRobotRep(robot_rep)
    self.robot_rep = robot_rep
end

function World:init()
    local x, z, y = self.robot_rep:getPosition()
    render_api.init_robot(x, z, y)
    component.setRobotRep(self.robot_rep)
end

function World:getBlockRelSide(side)
    local ori = self.robot_rep.orientation

    local cardinal_side
    if side == sides_api["front"] then
        cardinal_side = ori
    elseif side == sides_api["back"] then
        if ori == "north" then cardinal_side = "south"
        elseif ori == "east" then cardinal_side = "west"
        elseif ori == "south" then cardinal_side = "north"
        elseif ori == "west" then cardinal_side = "east" end
    elseif side == sides_api["right"] then
        if ori == "north" then cardinal_side = "east"
        elseif ori == "east" then cardinal_side = "south"
        elseif ori == "south" then cardinal_side = "west"
        elseif ori == "west" then cardinal_side = "north" end
    elseif side == sides_api["left"] then
        if ori == "north" then cardinal_side = "west"
        elseif ori == "east" then cardinal_side = "north"
        elseif ori == "south" then cardinal_side = "east"
        elseif ori == "west" then cardinal_side = "south" end

    elseif side == sides_api["top"] then
        cardinal_side = "top"
    elseif side == sides_api["bottom"] then
        cardinal_side = "bottom"
    end

    if cardinal_side == nil then
        error("Failed to set cardinal side succesefully")
    end


    local x, z, y = self.robot_rep:getPosition()
    if      cardinal_side == "north"    then    z = z - 1
    elseif  cardinal_side == "south"    then    z = z + 1
    elseif  cardinal_side == "east"     then    x = x + 1
    elseif  cardinal_side == "west"     then    x = x - 1

    elseif  cardinal_side == "top"      then    y = y + 1
    elseif  cardinal_side == "bottom"   then    y = y - 1
    end

    return self:getBlockAbs(x, z, y), {x, z, y}
end

function World:getBlockAbs(x, z, y)
    local index = self.blocks:getIndex(x, z, y)
    return self.blocks.block_array[index]
end

function World:placeBlock(block, x, z, y)
    self.blocks:addBlock(block, x, z, y)
end

function World:removeBlock(x, z, y)
    self.blocks:removeBlock(x, z, y)
end


function World:simulate()

end

function World:render()
    local blocks = self.blocks
    for index, block in pairs(blocks.block_array) do
        -- print(index)
        if type(block) == "number" then goto continue end
        local x, z, y = self.blocks:getCoords(index)
        --print(x,z,y)
        --io.read()

        render_api.render_world(x, z, y, block.color)
        ::continue::
    end
end

function World:renderRobot()
    local x, z, y = self.robot_rep:getPosition()
    -- x = x - 1; z = z - 1; y = y - 1;

    local result = render_api.render_robot(x, z, y, self.render_check)
    if result == 1 then -- this means we where told to wait until we get a clear signal
        self.render_check = 1
    else
        self.render_check = 0
    end
end


return World
