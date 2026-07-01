global interface ComponentType end -- you'll have to "as" this into the thing you actually want

global interface StackInfo
    damage: integer
    maxDamage: integer
    size: integer
    maxSize: integer
    id: integer | nil
    name: string
    label: string
    hasTag: boolean
end

global interface InventoryController is ComponentType
    getInventorySize: function(integer): integer | nil, string | nil
    getStackInSlot: function(integer, integer): StackInfo
    getStackInInternalSlot: function(integer): StackInfo
    dropIntoSlot: function(integer, integer, ?integer): boolean, string | nil
    suckFromSlot: function(integer, integer, ?integer): boolean
    equip: function(): boolean
end

global interface AnalyzeResult
    hardness: number
    harvestLevel: integer
    harvestTool: string
    metadata: integer
    name: string
end

global interface Geolyzer is ComponentType
    scan: function( -- Note: incomplete, return type is not declared, and neither is options table
        x: integer, z: integer, y?: integer, w?: integer, d?: integer, h?: integer, ignoreReplaceable: boolean | {any}
    ): {any}
    analyze: function(side: integer, options?: {any}): AnalyzeResult
    canSeeSky: function(): boolean
    isSunVisible: function(): boolean
end

-- store(side:number, slot:number, dbAddress:string, dbSlot:number):boolean
-- etc.

global interface Crafting is ComponentType
    craft: function(integer): boolean
end

local record Component 
    getPrimary: function(string): ComponentType
end

--[[function Component.getPrimary(str: string): ComponentType
    if str == "inventory_controller" then
        return
    else error("str: " .. str .. " <Not acounted for>") end
end--]]

return Component

