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
        new.block_array[1] = 0
    end

    return new
end

function BlockSet:add_block(new_block, x, z, y)
    -- First, check for out of bounds
    local pos_args = {x, z, y}
    for index, size_ptr in ipairs(self.size_array) do
        local pos = pos_args[index]
        if pos > size_ptr() then
            error(string.format("block out of bounds -- (%d > %d) [%d]", pos, size_ptr(), index))
        end
    end

    self:add_unchecked(new_block, x, z, y)
end

function BlockSet:addUnchecked(new_block, x, z, y)
    local index = (x - 1) + (z - 1) * self.size_x() + (y - 1) * self.size_z() * self.size_x()
    index = index + 1 -- lua shanenigans
    self.block_array[index] = new_block
end

function BlockSet:addLine(block, z, y, x1, x2)
    if x1 == nil or x2 == nil then x1 = 1; x2 = self.size_x() end
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
    return COPY(self)
end

-- renderer can definitively be improved
local block_size = rl.new("Vector3", 2, 2, 2)
function World:render()
    local blocks = self.blocks
    for index, block in ipairs(blocks.block_array) do
        if type(block) == "number" then goto continue end

        local y = index / (blocks.size_x() * blocks.size_z());
        index = index - (y * blocks.size_x() * blocks.size_z());

        local z = index / blocks.size_x();
        local x = index % blocks.size_x();

        local pos = rl.new("Vector3", x, y, z)
        rl.DrawCubeV(pos, block_size, rl.RED)

        ::continue::
    end
end

return World
