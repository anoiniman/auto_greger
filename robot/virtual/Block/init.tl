local implementation = require("virtual.Block.implementation")
local Block, KnownBlocks, _BlockColorHelper, _World = table.unpack(implementation)

local decl = require("virtual.Block.declaration")
local _, _, MetaBlock = table.unpack(decl)

local oak_sapling = require("virtual.Block.oak_sapling")

local function unpackComplexBlock(meta_block: MetaBlock)
    local array = meta_block:getBlockArray()
    for _, block in ipairs(array) do
        KnownBlocks:register(block as Block)
    end
end

-- posteriorily group similar recipes together with the same name and table them together
unpackComplexBlock(oak_sapling)

return {Block, KnownBlocks}
