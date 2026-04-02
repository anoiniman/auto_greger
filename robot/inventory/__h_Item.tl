global enum ToolType
    ""
    "pickaxe"
    "axe"
    "shovel"
    "sword"
    "hoe"

    "__gt_mallet"
    "__gt_hammer"
    "__gt_wrench"
    "__gt_file"
    "__gt_screwdriver"
    "__gt_saw"
    "__gt_crowbar"
    "__gt_soldering_iron"
end

--[[global enum ToolLevel
    "1"
    "2"
    "3"
    "4"
end--]]
global type ToolLevel = integer

local record helper end

global interface ItemDefinition
    disc: integer 

    label: string | nil
    name: string | nil
    size: integer | nil

    stack_size: integer
end

global interface FullDefinition is ItemDefinition
where self.disc == 10
    label: string
    name: string
    size: integer
end

global interface CategoryQuery is ItemDefinition
where self.disc == 11
    label: nil
    size: nil
    name: string
end

global interface LabelQuery is ItemDefinition
where self.disc == 12
    label: string
    name: nil
    size: nil
end
function helper.new_label_query(label: string): LabelQuery
    return {label = label} 
end

global interface ItemQuery is ItemDefinition
where self.disc == 13
    label: string
    name: string
    size: nil
end
function helper.new_item_query(label: string, name: string): ItemQuery
    return {label = label, name = name}
end


global interface EquipmentInfo is ItemDefinition
    label: string
    name: string
    size: integer

    tool_type: ToolType
    equiped_level: integer
    stack_size: integer
end

local record tool_materials is {{string}} end
for i = 1, 4, 1 do
    tool_materials[i] = {}
end
tool_materials[1] = {
    "flint"
}
tool_materials[2] = {
    "bronze",
    "iron",
    "copper",
}
tool_materials[3] = {
    "obzinite",
    "steel",
}

function helper.get_tool_materials(): tool_materials
    return tool_materials
end

return helper
