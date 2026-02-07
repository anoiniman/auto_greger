local deep_copy = require("deep_copy")
local ItemInfo = require("virtual.item.ItemInfo")
local KnownItems = require("virtual.item.KnownItems")

local oak_sapling = require("virtual.Block.oak_sapling")

--[[local ViewportBehaviour = {

}--]]

local function newColor(name, r, g, b, a)
    a = a or 212
    return {name, r, g, b, a}
end


-- In implementing sapling falling from leaves, orthographic projection into the floor
-- and "fall" in the nearest possible item
local Block = {
    item_info = ItemInfo:defaultItem(),
    ginfo = {
        color = 6666666,
        hardness = 0.66,
        harvestLevel = 0,
        harvestTool = "shovel",
        metadata = 0,
        name = "minecraft:grass",
    },
    dropped_items = {},

    -- color = newColor("Default", 57, 117, 90, 212),
    color = newColor("Default", 63, 121, 124, 212),
    passable = false,
    shape = "Cube",

    right_click = nil,
    block_break = nil,

    tick = nil,
    t_state = nil,
    on_place = nil,
    -- viewport = ViewportBehaviour:default(),
}

function Block:new(name, label, color, passable, meta_type, harvestTool, harvestLevel)
    local new = COPY(self)
    new.item_info.name = name
    new.item_info.label = label
    KnownItems:register(new.item_info)

    new.color = color
    -- print(label, passable)
    new.passable = passable or false
    new.meta_type = meta_type or "solid"

    new.ginfo.name = name
    new.ginfo.harvestTool = harvestTool or "shovel"
    new.ginfo.harvestLevel = harvestLevel or 0
    return new
end

function Block:default()
    return COPY(self)
end

local red_block = {}
function Block:redBlock()
    return COPY(red_block)
end

function Block:pickUpOneItemStack()
    return table.remove(self.dropped_items)
end

function Block:dropOneItemStack(item)
    table.insert(self.dropped_items, item)
end

-- Get what block drops if broken
function Block:getDrop()
    if self.block_break ~= nil then return self.block_break() end
    return self.item_info
end

-- First we try specific block interactions, then we try tool only interactions
function Block:use(with_what)
    if self.right_click ~= nil then return self:right_click(with_what) end
    if with_what ~= nil then return with_what:use() end

    return false
end


-- luacheck: push ignore
-- TODO, maybe one day implement uhhh blocks being air idk maybe
function Block:isAir()
    return false
end
-- luacheck: pop

local BlockFactory = {
    passable = false,
    meta_type = "solid",
    harvestTool = "shovel",
    harvestLevel = 0,

    f_opt = {
        right_click = nil,
        block_break = nil,
    }
}
function BlockFactory:make(name, label, color)
    local new = Block:new(name, label, color, self.passable, self.meta_type, self.harvestTool, self.harvestLevel)
    for k, _ in pairs(self.f_opt) do self.f_opt[k] = nil end
    return new
end

function BlockFactory:opt(right_click, block_break)
    self.f_opt.right_click = right_click
    self.f_opt.block_break = block_break
    return self
end

function BlockFactory:update(tbl)
    for key, value in pairs(tbl) do
        self[key] = value
    end
end

local temp = Block:new("red", "red", newColor("colorRed", 33, 0, 0, 222), false)
for k, v in pairs(temp) do red_block[k] = v end

local function break_grass()
    error("TODO return dirt item")
end

-- TODO separate block declrations into separate files, maybe

local gray1 = newColor("Gray1", 33, 33, 33, 246)
-- local grass_green = newColor("GrassGreen", 164, 249, 149, 212)
local grass_green = newColor("GrassGreen", 71, 81, 64, 212)
local leaf_green = newColor("LeafGreen", 49, 168, 43, 124)

-- For now, placing things like saplings will not check if block below is grass/dirt etc.
local known_blocks = {
    Block:default(),
    BlockFactory:opt(nil, break_grass):make("minecraft:grass", "Grass", grass_green),
    BlockFactory:make("minecraft:dirt", "Dirt", grass_green),
    BlockFactory:make("minecraft:cobblestone", "Cobblestone", gray1),

    BlockFactory:make("minecraft:chest", "Chest", newColor("chest", 120, 12, 42, 212)),
    -- BlockFactory:make("minecraft:oak_sapling", "Oak Sapling", newColor(120, 12, 42, 212)),
    BlockFactory:make("", "", newColor("What", 133, 133, 133, 212)),
    -- BlockFactory:make("minecraft:oak_leaves", "Oak Leaves", leaf_green),
    BlockFactory:make("minecraft:log", "Oak Wood", newColor("OakLogBrown", 68, 53, 29, 212)),
    BlockFactory:make("minecraft:plank", "Oak Plank", newColor("OakPlankBrown", 147, 135, 91, 212)),
}

local KnownBlocks = {
    blocks = known_blocks,
}

function KnownBlocks:air()
    return 0
end

function KnownBlocks:default()
    return self.blocks[1]
end

function KnownBlocks:register(block)
    local found_block = self:getByItemInfo(block.item_info)
    if found_block == nil then
        table.insert(KnownBlocks.blocks, block)
    end
end

function KnownBlocks:getByLabel(label)
    for _, block in ipairs(self.blocks) do
        local iblock_info = block.item_info
        if iblock_info.label == label then return COPY(block) end
    end

    return nil
end

function KnownBlocks:getByItemInfo(item_info)
    for _, block in ipairs(self.blocks) do
        local iblock_info = block.item_info
        if iblock_info:isSame(item_info) then return COPY(block) end
    end
end

local function unpackComplexBlock(meta_block)
    -- local block_table = KnownBlocks.blocks
    for _, block in ipairs(meta_block:provideAndGet(Block, KnownBlocks, newColor)) do
        -- table.insert(block_table, block)
        KnownBlocks:register(block)
    end
end

-- posteriorily group similar recipes together with the same name and table them together
unpackComplexBlock(oak_sapling)


return {Block, KnownBlocks}
