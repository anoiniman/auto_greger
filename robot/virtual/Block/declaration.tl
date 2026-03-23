local type UniversalItemInfo = require("virtual.item.UniversalInfo")
local type ETypeEnum = require("virtual.item.ETypeEnum")
local Position = require("virtual.Position")
local ItemInfo = require("virtual.item.ItemInfo")

local type BlockColor = {string, integer, integer, integer, integer}
local record BlockColorHelper is {string | integer} 
    new: function(string, integer, integer, integer, ? integer): BlockColor
    default: function(): BlockColor
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

local interface InteractionState end
-- TODO: redisign whole ass thing, so that the interaction between blocks and world can actually be modelled
-- by the type system, for now we simply declare a fake World type to fool teal, not great

local record World
    tick_num: integer
    getBlockAbs: function (any...): Block
    record block_set
        parseNativeSchematic: function (any...): any...
    end
end

local type Interactable = function(?World, ?Block)
local record Block
    item_info: UniversalItemInfo
    gInfo: GInfo
    meta_type: BlockMetaTypeEnum
    dropped_items: {ItemInfo}

    color: BlockColor
    passable: boolean
    shape: ShapeEnum

    right_click: Interactable
    block_break: Interactable
    on_place: Interactable
    tick: function(?any, ?Block, Position): string | nil

    t_state: InteractionState


    new: function(Block, string, string, BlockColor, boolean, BlockMetaTypeEnum, ETypeEnum, integer): Block
    default: function(Block): Block
    redBlock: function(Block): Block
    
    pickUpOneItemStack: function(Block)
    dropOneItemStack: function(Block, ItemInfo)
    getDrop: function(Block): UniversalItemInfo

    use: function(Block, ItemInfo): boolean
    isAir: function(Block): boolean
end
-- viewport = ViewportBehaviour:default(),

local record KnownBlocks
    blocks: {Block}
    air: function(KnownBlocks): integer
    default: function(KnownBlocks): Block
    register: function(KnownBlocks, Block)
    getByLabel: function(KnownBlocks, string): Block | nil
    getByItemInfo: function(KnownBlocks, ItemInfo): Block | nil
end

-- return {Block, KnownBlocks, BlockColor, BlockColorHelper, InteractionState, World}
return Block, KnownBlocks, BlockColor, BlockColorHelper, InteractionState, World
