local deep_copy = require("deep_copy")
local ItemInfo = require("virtual.item.ItemInfo")

local ViewportBehaviour = {

}

local function newColor(name, r, g, b, a) 
    return {name, r, g, b, a} 
end

-- In implementing sapling falling from leaves, orthographic projection into the floor
-- and "fall" in the nearest possible item
local Block = {
    item_info = ItemInfo:defaultBlock()
    dropped_items = {}

    color = newColor("Default", 48, 212, 138, 212),
    passable = false,
    shape = "Cube",

    right_click = nil,
    breaking_block = nil,
    -- viewport = ViewportBehaviour:default(),
}

function Block:new(name, lable, color, passable)
    local new = COPY(self)
    new.item_info.name = name
    new.item_info.lable = lable
    new.color = color
    new.passable = passable or false
    return new
end

function Block:default()
    return deep_copy.copy(self)
end

function Block:pickUpOneItem()
    return table.remove(self.dropped_items)
end

function Block:dropOneItem(item)
    table.insert(self.dropped_items, item)
end


local gray = newColor("Gray1", 33, 33, 33, 242)

local known_blocks = {
    Block:default(),
    Block:new("minecraft:cobblestone", "Cobblestone", gray),
    Block:new("minecraft:chest", "Chest", newColor(120, 12, 42, 212)),
    Block:new("minecraft:oak_sapling", "Oak Sapling", newColor(120, 12, 42, 212)),
    Block:new("", "", newColor(133, 133, 133, 212)),
}

local KnownBlocks = {
    blocks = known_blocks,
}

function KnownBlocks:get_by_lable(lable)
    for _, block in ipairs(self.blocks) do
        if block.lable == lable then return block end
    end
    return self.blocks[1]
end

return {Block, KnownBlocks}
