local oak_sapling = {}

function oak_sapling:provideAndGet(Block, newColor)
    -- function Block:new(name, label, color, passable, meta_type, harvestTool, harvestLevel)
    local oak_sapling_blue = newColor("OakSaplingBlue", 90, 147, 143, 212)
    local oak_sap = Block:new(
       "minecraft:sapling",
       "Oak Sapling", 
       oak_sapling_blue,
       false,
       "solid",
       "shovel",
       0
   )
   -- TODO: implementing ticking behaviour
   oak_sap.tick = function()

   end
    
    return {oak_sap}
end

return oak_sapling
