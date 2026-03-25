require("deep_copy")
local Position = require("virtual.Position")

local UniversalItemInfo = require("virtual.item.UniversalInfo")
local ItemInfo = require("virtual.item.ItemInfo")
local KnownItems = require("virtual.item.KnownItems")

local type ETypeEnum = require("virtual.item.ETypeEnum")

local declaration = require("virtual.Block.declaration")
local BlockColor, InteractionState = table.unpack(declaration)

--[[local ViewportBehaviour = {

}--]]

local record BlockColorHelper
    new: function(string, integer, integer, integer, ? integer): BlockColor
    default: function(): BlockColor
end

function BlockColorHelper.new(name: string, r: integer, g: integer, b: integer, a?: integer): BlockColor
    a = a or 212
    return {name, r, g, b, a}
end

local default_color <const>: BlockColor = BlockColorHelper.new("Default", 63, 121, 124, 212)
function BlockColorHelper.default(): BlockColor
    return default_color
end

local interface GInfo
    color: integer
    hardness: number
    harvestLevel: integer
    harvestTool: ETypeEnum
    metadata: integer
    name: string
end

local enum ShapeEnum
    "Cube"
end

-- What about entities????
local enum BlockMetaTypeEnum
    "solid"
    "entity"
    "replaceable"
    "liquid"
    "passable"
    "air"
end


local type Interactable = function(?World, ?Block)
local record Block
    item_info: UniversalItemInfo
    ginfo: GInfo
    meta_type: BlockMetaTypeEnum
    dropped_items: {ItemInfo}

    color: BlockColor
    passable: boolean
    shape: ShapeEnum

    right_click: function(Block, ItemInfo)
    block_break: Interactable
    on_place: Interactable
    tick: function(?any, ?Block, Position): string | nil

    t_state: InteractionState

    new: function(Block, string, string, BlockColor, ?boolean, ?BlockMetaTypeEnum, ?ETypeEnum, ?integer): Block
    default: function(Block): Block
    redBlock: function(Block): Block
    
    pickUpOneItemStack: function(Block): ItemInfo
    dropOneItemStack: function(Block, ItemInfo): nil
    getDrop: function(Block): UniversalItemInfo

    use: function(Block, ItemInfo): boolean
    isAir: function(Block): boolean
end
-- viewport = ViewportBehaviour:default(),

local record World
    tick_num: integer
    getBlockAbs: function (any...): Block
    record block_set
        parseNativeSchematic: function (any...): any...
    end
end

local record KnownBlocks
    blocks: {Block}
    air: function(KnownBlocks): integer
    default: function(KnownBlocks): Block
    register: function(KnownBlocks, Block): nil
    getByLabel: function(KnownBlocks, string): Block | nil
    getByItemInfo: function(KnownBlocks, UniversalItemInfo): Block | nil
end

local default_ginfo: GInfo = {
    color = 6666666,
    hardness = 0.66,
    harvestLevel = 0,
    harvestTool = "shovel",
    metadata = 0,
    name = "minecraft:grass",
}

local default_block: Block = {
    item_info = UniversalItemInfo:defaultUniversalInfo(),
    ginfo = default_ginfo,
    dropped_items = {},

    color = default_color,
    passable = false,
    shape = "Cube",

    right_click = nil,
    block_break = nil,

    tick = nil,
    t_state = nil,
    on_place = nil,
    -- viewport = ViewportBehaviour:default(),
}

-- TODO: redesign this so that instead of giving name:label we give directly a UniversalItemInfo
-- basically this involves reversing the current processes where regestering a block registers an item,
-- instead we'd register an item BEFORE registering a block
function Block:new(
    name: string,
    label: string,
    color: BlockColor,
    passable?: boolean,
    meta_type?: BlockMetaTypeEnum,
    harvestTool?: ETypeEnum,
    harvestLevel?: integer
): Block
    local new = COPY(default_block) as Block
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

function Block:default(): Block
    return COPY(default_block) as Block
end

local red_block: Block = {} as Block
function Block:redBlock(): Block
    return COPY(red_block) as Block
end

function Block:pickUpOneItemStack(): ItemInfo
    return table.remove(self.dropped_items)
end

function Block:dropOneItemStack(item: ItemInfo): nil
    table.insert(self.dropped_items, item)
    return nil
end

-- Get what block drops if broken
function Block:getDrop(): UniversalItemInfo
    if self.block_break ~= nil then return self.block_break() end
    return self.item_info
end

-- First we try specific block interactions, then we try tool only interactions
function Block:use(with_what: ItemInfo): boolean
    if self.right_click ~= nil then return self:right_click(with_what) end
    if with_what ~= nil then return with_what:use() end

    return false
end

-- luacheck: push ignore
-- TODO, maybe one day implement uhhh blocks being air idk maybe
function Block:isAir(): boolean
    return false
end
-- luacheck: pop

local type any_func = function(any...): any...
local record BlockFactory
    passable: boolean
    meta_type: BlockMetaTypeEnum
    harvestTool: ETypeEnum
    harvestLevel: integer
    record f_opt
        right_click: (any_func  | nil)
        block_break: (any_func | nil)
    end
end
BlockFactory.passable = false
BlockFactory.meta_type = "solid"
BlockFactory.harvestTool = "shovel"
BlockFactory.harvestLevel = 0

BlockFactory.f_opt.right_click = nil
BlockFactory.f_opt.block_break = nil

function BlockFactory:make(name: string, label: string, color: BlockColor): Block
    local new = Block:new(name, label, color, self.passable, self.meta_type, self.harvestTool, self.harvestLevel)
    for k, _ in pairs(self.f_opt as {any : any}) do (self.f_opt as {any: any})[k] = nil end
    return new
end

function BlockFactory:opt(right_click: any_func | nil, block_break: any_func | nil): BlockFactory
    self.f_opt.right_click = right_click
    self.f_opt.block_break = block_break
    return self
end

function BlockFactory:update(tbl: {any : any})
    for key, value in pairs(tbl) do
        (self as {any : any})[key] = value
    end
end

local temp = Block:new("red", "red", BlockColorHelper.new("colorRed", 33, 0, 0, 222), false)
for k, v in pairs(temp as {any : any}) do (red_block as {any : any})[k] = v end

local function break_grass()
    error("TODO return dirt item")
end

-- TODO separate block declrations into separate files, maybe
local function newColor(a: string, b: integer, c: integer, d: integer, e?: integer): BlockColor
    return BlockColorHelper.new(a,b,c,d,e)
end

local gray1 = newColor("Gray1", 33, 33, 33, 246)
-- local grass_green = newColor("GrassGreen", 164, 249, 149, 212)
local grass_green = newColor("GrassGreen", 71, 81, 64, 212)
local _leaf_green = newColor("LeafGreen", 49, 168, 43, 124)

-- For now, placing things like saplings will not check if block below is grass/dirt etc.
KnownBlocks.blocks = {
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

function KnownBlocks:air(): integer
    return 0
end

function KnownBlocks:default(): Block
    return self.blocks[1]
end

function KnownBlocks:register(block: Block): nil
    local found_block = self:getByItemInfo(block.item_info)
    if not (found_block is nil) then return end

    table.insert(self.blocks, block)
    return nil
end

function KnownBlocks:getByLabel(label: string): Block | nil
    for _, block in ipairs(self.blocks) do
        local iblock_info = block.item_info
        if iblock_info.label == label then return COPY(block) as Block end
    end
    return nil
end

function KnownBlocks:getByItemInfo(item_info: UniversalItemInfo): Block | nil
    for _, block in ipairs(self.blocks) do
        local iblock_info = block.item_info
        if iblock_info:isSame(item_info) then return COPY(block) as Block end
    end
    return nil
end

return {Block, KnownBlocks, BlockColorHelper, World}
