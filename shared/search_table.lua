local module = {}

local function print_buffer(tbl, buffer)
    for key, value in pairs(tbl) do
        if type(value) == "function" then
            -- table.insert(buffer, tostring(key) .. " is function")
        elseif type(value) == "table" then
            print_buffer(tbl, buffer)
        elseif type(value) == "string" or type(value) == "number" then
            table.insert(buffer, tostring(key) .. " = " .. tostring(value))
        else
            table.insert(buffer, tostring(key) .. " is unknown ")
        end
    end

    return buffer
end

function module.print_structure(obj, name)
    if type(obj) == "string" then print(comms.robot_send("info", name .. "(string): " .. obj)); return end
    if type(obj) == "number" then print(comms.robot_send("info", name .. "(number): " .. obj)); return end
    if type(obj) == "function" then print(comms.robot_send("info", name .. "(function): ")); return end

    if type(obj) == "table" then 
        local buffer = print_buffer(obj, {""})
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
