-- luacheck: globals MATERIAL_CONDITION_TABLE
local comms = require("comms")
local deep_copy = require("deep_copy")


MATERIAL_CONDITION_TABLE = {} -- accidental har har
local mct = MATERIAL_CONDITION_TABLE

local tool_types = {
    "sword",
    "pickaxe"
    "axe",
    "shovel",
    "hoe",

    "wrench",
    -- etc. (TODO)
}
local function default_func() return false end

local MetaCondition = {
    name = "DEFAULT",
    cond_type = nil,

    func_state = nil,
    cond_func = nil,
}
local function newMC(name, cond_type, func_state, func)
    local new = deep_copy.copy(MetaCondition)
    new.name = name
    new.cond_type = cond_type

    new.func_state = func_state
    new.cond_func = func
    return new
end

local function enoughMaterial(material_name, needed_ammount)
    local mc_name = "0mc_" .. material_name
    local cond_type = "enough_material"

    return newMC(mc_name, cond_type, needed_ammount)
end

local MetaMaterial = {
    lable = "DEFUALT",
    conditions = "true",
}
local function newMM(lable, conditions)
    local new = deep_copy.copy(MetaMaterial)
    new.lable = lable
    new.conditions = conditions or "true"
    return new
end

-- Forget setting the conditionals through here dawg, don't be stupid

local tool_materials = {
    {
    "flint"
    }, -- 1
    {
    "bronze",
    "iron",
    "copper",
    }, -- 2
    {
    "alumite",
    "steel",
    }, -- 3
}

return {tool_materials, tool_types}
