local deep_copy = require("deep_copy")
local fake_pointer = require("fake_pointer")

local Block = {
    lable = "Dirt",
    passable = false,
}
function Block:default()
    return deep_copy.copy(self)
end


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

function BlockSet:new(size_x, size_z, size_y)
    local pos_args = {size_x, size_z, size_y}

    local new = COPY(self)
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
    -- local index = (x - 1) + (z - 1) * self.size_x() + (y - 1) * self.size_z() * self.size_x()
    local index = x + z * self.size_x() + y * self.size_z() * self.size_x()
    index = index + 1 -- lua shanenigans
    self.block_array[index] = new_block
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

function BlockSet:parseNativeSchematic(schematic_table, dictionary, _iterator)
    for yindex, slice in ipairs(schematic_table) do for zindex, column in ipairs(slice) do
        local xindex = 0
        for char in string.gmatch(str, ".") do
            local block = dictionary[char]
            if char ~= '-' then self:addUnchecked(block, xindex, zindex, yindex) end
        end
    end end
end

local World = {
    blocks = BlockSet:new(),
    test_conditions = nil,
    robot = nil,
}

function World:default()
    local new = COPY(self)
    new.blocks:addPrism(Block:default(), 1, 2, 1, 4, 1, 4)
    return new
end

local my_red = rl.new("Color", 230, 41, 55, 212)
local block_size = 1
local scale = block_size * 0.1
local block_sizeV = rl.new("Vector3", 1, 1, 1)
function World:render()
    local blocks = self.blocks
    -- rl.DrawCubeV(rl.new("Vector3", 0, 0, 0), rl.new("Vector3", 10, 10, 10), rl.RED)

    for index, block in pairs(blocks.block_array) do
        if type(block) == "number" then goto continue end
        index = index - 1

        local y = math.floor(index / (blocks.size_x() * blocks.size_z()))
        index = math.floor(index - (y * blocks.size_x() * blocks.size_z()))

        local z = math.floor(index / blocks.size_x())
        local x = (index % blocks.size_x())

        -- print(string.format("x: %f, z: %f, y: %f", x, z, y))

        local pos = rl.new("Vector3", 
            x*block_size + scale * x,
            y*block_size + scale * y,
            z*block_size + scale * z
        )
        rl.DrawCubeV(pos, block_sizeV, my_red)
        -- rl.DrawCubeWiresV(pos, block_sizeV, rl.BLUE)

        ::continue::
    end
end

return World
