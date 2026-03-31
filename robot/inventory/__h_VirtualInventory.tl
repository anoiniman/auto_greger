require("__h_Item")

global interface VirtualInventory
    equip_info: EquipmentInfo
    inv_size: integer
    table_size: integer

    inv_type: string
    inv_table: {string | integer}
end

global interface ComparisonDiff
    item: ItemDefinition
    diff: integer
end

