local type ETypeEnum = require("virtual.item.ETypeEnum")

local interface UniversalInfo
    maxDamage: integer
    maxSize: integer

    name: string
    label: string
    interface EquipmentData
        e_type: ETypeEnum
        level: integer
    end
    equipment_data: EquipmentData

    use: function ()
end

return UniversalInfo
