-- luacheck: globals COPY, ignore deep_copy
local deep_copy = require("deep_copy")
local component = require("component")
local fake_pointer = require("fake_pointer")

local a = require("virtual.Block")
local Block, KnownBlocks = table.unpack(a)
local sides_api = require("sides")

local MetaBuild = require("build.MetaBuild")

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

    tick_array = {},
    block_array = nil,
    world = nil
}
BlockSet.size_x = BlockSet.size_array[1]
BlockSet.size_z = BlockSet.size_array[2]
BlockSet.size_y = BlockSet.size_array[3]

-- There is something wierd with the "fake pointers" that the value is not getting updated
function BlockSet:new(size_x, size_z, size_y, world)
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
        -- new.block_array[i] = 0
    end

    new.world = world
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

function BlockSet:checkAndRemoveTickBlock(index)
    local jindex
    for j, entry in ipairs(self.tick_array) do
        local i = entry[2]
        if i == index then jindex = j end
    end
    if jindex == nil then return end
    
    -- self.tick_array[jindex] = nil
    table.remove(self.tick_array, jindex)
end

-- TODO: when block is removed, items that are in its "dropped" "inventory" need to be further "dropped" down
function BlockSet:removeBlock(x, z, y)
    local index = self:getIndex(x, z, y)
    
    --[[local block = self.block_array[index]
    print(block.item_info.label)--]]

    if self.block_array[index].tick ~= nil then self:checkAndRemoveTickBlock(index) end

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

    local index = self:getIndex(x, z, y)
    local old_block = self.block_array[index]
    if type(old_block) ~= "number" then
        self:removeBlock(x, z, y)
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

    new_block = COPY(new_block)
    if type(new_block) ~= "number" and new_block.tick ~= nil then 
        new_block.on_place(self.world, new_block)
        table.insert(self.tick_array, {new_block, index})
    end
    -- if type(new_block) ~= "number" then print(new_block.item_info.label) end

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

function BlockSet:tick(world)
    -- print(#self.tick_array)
    local delete_table = nil
    for _, entry in ipairs(self.tick_array) do
        local block = entry[1]
        local x, z, y = self:getCoords(entry[2])
        -- local state = entry[3]

        local pos = {x, z, y}

        local result = block.tick(world, block, pos)
        if result ~= nil then
            if result == "destroy_self" then
                if delete_table == nil then delete_table = {} end
                table.insert(delete_table, pos)
            else
                error("result unknown: " .. result)
            end
        end
    end

    if delete_table ~= nil then
        for _, pos in ipairs(delete_table) do
            self:removeBlock(table.unpack(pos))
        end
    end

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

local function block_in_list(block, list)
    if list == nil then return false end
    if type(block) ~= "number" then
        for _, other_block in ipairs(list) do
            if  type(other_block) ~= "number"
                and block.item_info:isSame(other_block.item_info) 
            then 
                return true 
            end
        end
    else
        for _, other_block in ipairs(list) do
            if type(other_block) == "number" then return true end
        end
    end

    return false
end

local function is_char_special(char)
    return char == '-' or char == '*' or char == '+' or char == '?'
end

function BlockSet:parseNativeSchematic(schematic_table, dictionary, offset_table, unchecked, replace_list, black_list)
    local x_offset, z_offset, y_offset = table.unpack(offset_table)
    x_offset = x_offset or 0
    z_offset = z_offset or 0
    y_offset = y_offset or 0

    local add_function
    if unchecked then add_function = self.addUnchecked
    else add_function = self.addBlock end

    for yindex, slice in ipairs(schematic_table) do
        yindex = yindex + y_offset
        for zindex, column in ipairs(slice) do
            zindex = zindex + z_offset

            local xindex = x_offset
            for char in string.gmatch(column, ".") do
                local block = dictionary[char]
                -- local block = Block:default()
                if not is_char_special(char) then
                    if block == nil then error(string.format("Dic entry for: \"%s\" is nil", char)) end

                    local block_index = self:getIndex(xindex, zindex, yindex)
                    local old_block = self.block_array[block_index]
                    local in_list = block_in_list(old_block, replace_list)

                    if black_list == nil then
                        add_function(self, block, xindex, zindex, yindex)
                    elseif black_list == true and not in_list then
                        add_function(self, block, xindex, zindex, yindex)
                    elseif black_list == false and in_list then -- white-list
                        add_function(self, block, xindex, zindex, yindex)
                    end
                end
                xindex = xindex + 1
            end
        end
    end
end

function BlockSet:instantiateBuilding(name, chunk_tbl, height, quad_num)
    local build = MetaBuild:new()
    build:require(name, chunk_tbl)
    build:setupBuild(quad_num, height)

    -- TODO: for now this will work with only base tables, no segments plz, thats boring to code
    local primitive = build.primitive
    local schematic_table = primitive.base_table
    local dictionary = primitive.dictionary2 -- special dicttionary just for this use
    local offset_table = primitive.origin_block

    if dictionary == nil then error("Remember to adapt the building table you want to use: " .. name) end
    self:parseNativeSchematic(schematic_table, dictionary, offset_table, true)
end

-- How about we backport our bitmap map loader, with the height being mesured with the
-- r: channel, and blocktype by the g:channel, and the b channel reserved for later,
-- prob no need for an alpha channel
local World = {
    -- block_set = BlockSet:new(24, 24, 24),
    block_set = nil,
    test_conditions = nil,
    robot_rep = nil,

    tick_num = 0,
    render_check = 0,
}

function World:default()
    local new = COPY(self)
    new.block_set = BlockSet:new(24, 24, 24, self)
    new.block_set:addPrism(Block:default(), 0, 2, 0, 2, 0, 2)
    return new
end

function World:empty(x_size, z_size, y_size, robot_rep)
    local new = COPY(self)
    new.block_set = BlockSet:new(x_size, z_size, y_size, self)
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

    new.block_set = BlockSet:new(x_size, z_size, y_size, self)
    new.block_set:parseNativeSchematic(schematic, dictionary)

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
        if type(side) == "table" then
            for k, v in pairs(side) do print(k, v) end
        end

        error(string.format(
            "Failed to set cardinal side succesefully: ori was: %s, side was: %s",
            tostring(ori),
            tostring(side)
            ))
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

-- Added a cast in order to make sure that a number value is interpreted as nil
function World:getBlockAbs(x, z, y)
    local index = self.block_set:getIndex(x, z, y)
    local block = self.block_set.block_array[index]
    if type(block) == "number" then block = nil end

    --[[if block ~= nil then
        for k, v in pairs(block) do print(k, v) end
    end--]]

    return block
end

function World:placeBlock(block, x, z, y)
    self.block_set:addBlock(block, x, z, y)
end

function World:removeBlock(x, z, y)
    self.block_set:removeBlock(x, z, y)
end


function World:simulate()
    self.tick_num = self.tick_num + 1
    self.block_set:tick(self)
end

function World:render()
    local blocks = self.block_set
    for index, block in pairs(blocks.block_array) do
        -- print(index)
        if type(block) == "number" then goto continue end
        local x, z, y = self.block_set:getCoords(index)
        -- print(x,z,y)
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
