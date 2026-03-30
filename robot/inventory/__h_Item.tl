global enum ToolType
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

global enum ToolLevel
    "1"
    "2"
    "3"
    "4"
end

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

global interface ItemQuery is ItemDefinition
where self.disc == 12
    label: string
    name:  nil
    size: nil
end

local record helper end

return helper
