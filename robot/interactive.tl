local record module end
-- Just noticed that this is basically a fancy future/promise implementation :sob:
local comms = require("comms")

local enum InteractiveType
    "generic_hold"
    "auto_build0"
    "auto_build1"
end

-- data table is the data we want to update interactivly
local interface Element
    id: integer

    interactive_type: InteractiveType
    human_readable: string
    data_table: any
end

local function element_new(interactive_type: InteractiveType, human_readable: string): Element
    return {
        interactive_type = interactive_type,
        human_readable = human_readable,
    }
end

--[[local function element_get_id(element: Element): integer
    return element.id
end--]]

local wait_list: {integer : Element} = {}
local incremental_id: integer = 0
--local incremental_id = math.mininteger

local function get_new_id(): integer -- now with this linear search will no longer be necessary O(1) baby, we could've
                                     -- also simply could've used an offset butt who cares
    if incremental_id > 0 then
        for index = 1, incremental_id, 1 do
            if wait_list[index] == nil then
                return index -- alows us to reuse id's UwU
            end
        end
    end

    incremental_id = incremental_id + 1
    return incremental_id
end

function module.add(interactive_type: InteractiveType, human_readable: string): integer
    local new_id = get_new_id()
    local new_element = element_new(interactive_type, human_readable)
    print(comms.robot_send("info", string.format("[%s] New ifs entry has been set: %s", new_id, human_readable)))
    wait_list[new_id] = new_element
    return new_id
end

function module.get_data_table(id: integer): any
    return wait_list[id].data_table
end

function module.del_data_table(id: integer)
    wait_list[id].data_table = nil
end

function module.del_element(id: integer)
    wait_list[id] = nil
end

function module.print_list()
    local empty: boolean = true
    for _, _ in pairs(wait_list) do empty = false; break end
    if empty then
        print(comms.robot_send("info", "--- Wait List is empty ---"))
        return
    end

    local buffer: {string} = {}
    table.insert(buffer, "--- Wait List print begin ---\n")
    for id, element in pairs(wait_list) do
        local print_table = {"id -- [",  id,  "] -- ",  element.interactive_type,  " -- \"",  element.human_readable,  "\"\n"}
        table.insert(buffer, table.concat(print_table as {string}))
    end
    table.insert(buffer, "--- Wait List print END ---\n")
    print(comms.robot_send("info", table.concat(buffer)))
end

-- gonna need to programe something in prompt side for this cool thing to happen, but can also just add
-- a debug FORCE SET DATA kind of thing
function module.request_form(_data: any, id: integer)
    local element = wait_list[id]
    local t = element.interactive_type
    if t == "auto_build0" then
        -- TODO, we gonna FORCE SET for now
        comms.robot_send("start-request", "")
    else
        error(comms.robot_send("fatal", "what are you doing lil' bro interactive.set_data_table"))
    end
end

local type auto_build0 = {integer, integer, integer}
local type auto_build1 = {string}
function module.set_data_table(add_data: any, id: integer): boolean
    local element = wait_list[id]
    if element == nil then
        print(comms.robot_send("error", "interactive.set_data_table, id: \"" .. id .. "\" doesn't exist"))
        return false
    end

    local t = element.interactive_type
    if t == "auto_build0" then
        local data: auto_build0 = add_data as auto_build0

        -- since we don't have the request systme implemented, just add an eval to throw data in
        if  data == nil or #data ~= 3 or tonumber(data[1]) == nil or tonumber(data[2]) == nil or tonumber(data[3]) == nil or
            data[3] > 4 or data[3] < 1
        then
            print(comms.robot_send("error", "invalid data"))
            return false
        end
        for i = 1, #data, 1 do
            data[i] = math.floor(tonumber(data[i]))
        end

        wait_list[id].data_table = data
        return true
    elseif t == "auto_build1" then
        local data: auto_build1 = add_data as auto_build1

        if data == nil or #data ~= 1 or tostring(data[1]) == nil then
            print(comms.robot_send("error", "invalid data"))
            return false
        end
        -- data[2] = tonumber(data[2])
        wait_list[id].data_table = data
        return true
    elseif t == "generic_hold" then
        return true
    else
        --enable the following error message if we force data to be handled through requests
        --error(comms.robot_send("fatal", "this is not possible, ahrk, gamma ray inside ram-stick -- error 6969"))
        print(comms.robot_send("error", "interactive.set_data_table, wooopsie doopsie, spell things better dum dum"))
    end
    return false
end

return module
