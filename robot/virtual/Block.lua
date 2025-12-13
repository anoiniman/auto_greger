local deep_copy = require("deep_copy")
local ViewportBehaviour = {

}


local Block = {
    name = "minecraft:dirt",
    lable = "Dirt",
    -- color = rl.new("Color", 102, 191, 255, 212),
    -- color = rl.new("Color", 48, 212, 138, 212),
    passable = false,
    shape = "Cube",

    right_click = nil,
    breaking_block = nil,
    -- viewport = ViewportBehaviour:default(),
}

function Block:new(name, lable, color, passable)
    local new = deep_copy.copy(self)
    new.name = name
    new.lable = lable
    new.color = color
    new.passable = passable or false
    return new
end

function Block:default()
    return deep_copy.copy(self)
end

local color = {}
function color.new() end

local known_blocks = {
    Block:default(),
    Block:new("minecraft:cobblestone", "Cobblestone", color.new(33, 33, 33, 212)),
    Block:new("minecraft:chest", "Chest", color.new(120, 12, 42, 212)),
    Block:new("minecraft:oak_sapling", "Oak Sapling", color.new(120, 12, 42, 212)),
    Block:new("", "", color.new(133, 133, 133, 212)),
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
