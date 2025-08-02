local comms = require("comms")
local module = {}

local function print_buffer(tbl, buffer, ref_buffer)
    for key, value in pairs(tbl) do
        if ref_buffer[key] ~= nil then
            if type(ref_buffer[key]) ~= "table" then ref_buffer[key] = {ref_buffer[key]} end
            for _, o_value in ipairs(ref_buffer[key]) do
                if value == o_value then -- loop detected
                    table.insert(buffer, key .. " = Loop Detected\n")
                    return buffer
                end
            end
            table.insert(ref_buffer[key], value)
        else
            ref_buffer[key] = value
        end

        if type(value) == "function" then
            -- table.insert(buffer, tostring(key) .. " is function")
        elseif type(value) == "table" then
            print_buffer(tbl, buffer, ref_buffer)
        elseif type(value) == "string" or type(value) == "number" or type(value) == "boolean" then
            table.insert(buffer, tostring(key) .. " = " .. tostring(value) .. "\n")
        else
            table.insert(buffer, tostring(key) .. " is unknown\n")
        end
    end

    return buffer
end

function module.print_structure(obj, name)
    if name == nil then name = "DEFAULT NAME" end

    if type(obj) == "string" then print(comms.robot_send("info", name .. "(string): " .. obj)); return end
    if type(obj) == "number" then print(comms.robot_send("info", name .. "(number): " .. obj)); return end
    if type(obj) == "boolean" then print(comms.robot_send("info", name .. "(boolean): " .. obj)); return end
    if type(obj) == "function" then print(comms.robot_send("info", name .. "(function): ")); return end

    if type(obj) == "table" then
        local buffer = print_buffer(obj, {"\n"}, {obj})
        print(comms.robot_send("info", name .. table.concat(buffer)))
        return
    end
end

-- it's le recursive! totally not a cludge! (this means this can't compare tables together :P)
function module.ione(tbl, particle)
    if tbl == nil or type(tbl) ~= "table" then return false end

    for _, element in ipairs(tbl) do
        if type(element) == "table" then
            if module.ione(element, particle) then return true end
        end
        if particle == element then return true end
    end
    return false
end


return module
