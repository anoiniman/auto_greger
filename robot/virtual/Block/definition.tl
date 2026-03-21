local deep_copy = require("deep_copy")

local type UniversalItemInfo = require("virtual.item.UniversalInfo")
local type ETypeEnum = require("virtual.item.ETypeEnum")

local ItemInfo = require("virtual.item.ItemInfo")
local KnownItems = require("virtual.item.KnownItems")

local function newColor(name, r, g, b, a)
    a = a or 212
    return {name, r, g, b, a}
end

local interface GInfo
    color: integer
    hardness: number
    harvestLevel: integer
    harvestTool: ETypeEnum
    metadata: integer
    name: string
end

local default_ginfo <total>: GInfo = {
    color = 6666666,
    hardness = 0.66,
    harvestLevel = 0,
    harvestTool = "shovel",
    metadata = 0,
    name = "minecraft:grass",
}

local record Block
    item_info: UniveralInfo
    gInfo: GInfo
    dropped_items: {ItemInfo}

    color: BlockColor
end

local Block = {
    item_info = ItemInfo:defaultItem(),
    ginfo = {
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

local record KnownBlocks
    blocks: {Block}
    air: function(): integer
    default: function(): Block
    register: function(Block)
    getByLabel: function(string): Block | nil
    getByItemInfo: function(ItemInfo): Block | nil
end

return {Block, KnownBlocks, BlockColor}
