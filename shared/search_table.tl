local comms = require("comms")
local record module end

local type AnyTable = {string | integer : any}
local function print_buffer(tbl: AnyTable, buffer: {string}, ref_buffer: AnyTable): {string}
    for key, value in pairs(tbl) do
        if ref_buffer[key] ~= nil then -- this loop detection is terrible, we really ought to build trees
            local inner = ref_buffer[key] as {any}
            for _, o_value in ipairs(inner) do
                if value == o_value then -- loop detected
                    table.insert(buffer, tostring(key) .. " = Loop Detected\n")
                    return buffer
                end
            end
            table.insert(ref_buffer[key] as {any}, value)
        else
            ref_buffer[key] = {value}
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

function module.print_structure<T>(obj: T, name: string)
    if name == nil then name = "DEFAULT NAME" end

    if type(obj) == "string" then print(comms.robot_send("info", name .. "(string): " .. obj as string)); return end
    if type(obj) == "number" then print(comms.robot_send("info", name .. "(number): " .. obj as string)); return end
    if type(obj) == "boolean" then print(comms.robot_send("info", name .. "(boolean): " .. obj as string)); return end
    if type(obj) == "function" then print(comms.robot_send("info", name .. "(function): ")); return end

    if type(obj) == "table" then
        local buffer = print_buffer(obj as AnyTable, {"\n"}, {obj as AnyTable} as AnyTable)
        print(comms.robot_send("info", name .. table.concat(buffer)))
        return
    end
end

-- it's le recursive! totally not a cludge! (this means this can't compare tables together :P)
function module.ione<T>(tbl: {any}, particle: T): boolean
    if tbl == nil then return false end
    if type(tbl) ~= "table" then
        if type(particle) == "table" then
            NLOG("fatal", "Particulate is table:\n" .. debug.traceback())
        end
        return tbl == particle
    end

    for _, element in ipairs(tbl) do
        if type(element) == "table" then
            LOG("error", "Attempted recursion on table_check on:\n" .. debug.traceback())
            if module.ione(element as {any}, particle) then return true end
        end
        if particle == element then return true end
    end
    return false
end
global CMP_OTT: function<T>({any}, T): boolean = module.ione -- Compare Object to Table


return module
