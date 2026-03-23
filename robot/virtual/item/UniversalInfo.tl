local type ETypeEnum = require("virtual.item.ETypeEnum")

local record UniversalInfo
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

local default_universal_info = {
    maxDamage = -1,
    maxSize = 64,

    name = "default:name",
    label = "Default Label",
    equipment_data = {
        e_type = "none",
        level = -1,
    },

    use = nil,
}

function UniversalInfo:defaultUniversalInfo(): UniversalInfo
    return default_universal_info
end

function UniversalInfo:isSame(other: UniversalInfo): boolean
    return self.label == other.label and self.name == other.name
end

return UniversalInfo
