local deep_copy = require("deep_copy")
local comms = require("comms")

local module = {}

local valid_types = {
    "number",
    "string",
    "function",
    "gtable",
    "lock"
}

local function check_type_exist(exp_type)
    if valid_types[exp_type] == nil then

        return false
    end
    return true
end

local Definition = {
    value = nil,
    exp_type = nil,
}
function Defintion:new(value, exp_type)
    local new = deep_copy.copy(self, pairs)

    if type(exp_type) == "table" then
        for _, inner_type in ipairs(exp_type) do
            if not check_type_exist(inner_type) then
                return nil
            end
        end
    else
        if not check_type_exist(exp_type) then return nil end
    end

    new.value = value
    new.exp_type = exp_type

    return new
end


local CommandSchema = {
    priority = Definition:new(nil, "number")
    command = {exp,
    arguments = nil,
}

function CommandSchema:check()

end


function module.new_command_schema()

end


return module
