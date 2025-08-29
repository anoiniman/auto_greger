local keyboard = require("keyboard")

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
function Definition:new(value, exp_type)
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
    priority = Definition:new(nil, "number"),
    command = Definition:new(nil, {"function", "string"}),
    arguments = nil,
}

function CommandSchema:check()

end


function module.new_command_schema()

end

function module.inspect_raw(prio, command, arguments)
    if command == nil then command = "nil" end
    local buffer = {"\n"}
    table.insert(buffer, string.format("(p%d) Command: \"%s\" is invalid!\n", prio, command))
    local max_depth = 10; local depth = 0;
    local function recursive_append(tbl)
        if depth >= max_depth then return end
        depth = depth + 1
        table.insert(buffer, "{\n")
        for key, value in pairs(tbl) do
            table.insert(buffer, string.format("%s = ", tostring(key)))

            if type(value) == "table" then recursive_append(value); goto skip_comma
            elseif type(value) == "function" then table.insert(buffer, "function")
            elseif type(value) == "boolean" or type(value) == "string" or type(value) == "number" then
                table.insert(buffer, tostring(value))
            else table.insert(buffer, "other") end

            table.insert(buffer, ", ")
            ::skip_comma::
        end
        table.insert(buffer, "}\n")
    end
    if type(command) == "table" then
        table.insert(buffer, "<command>\n")
        recursive_append(command)
    end

    table.insert(buffer, "<arguments>\n")
    recursive_append(arguments)

    print(comms.robot_send("error", table.concat(buffer)))
    local counter = 0
    while true do
        os.sleep(0.1)
        if counter >= 60 or keyboard.isKeyDown(keyboard.keys.q) then break end
        counter = counter + 0.1
    end
end

function module.raw_break_appart(cmd_tbl)
    local prio = table.remove(cmd_tbl, 1)
    local command = table.remove(cmd_tbl, 1)

    return prio, command, cmd_tbl
end

return module
