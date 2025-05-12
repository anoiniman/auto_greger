local module = {}
-- Just noticed that this is basically a fancy future/promise implementation :sob:
-- Long term TODO -- uhhh, yeah, let's hope we don't run out of id's ehehhe

local math = require("math")

local deep_copy = require("deep_copy")
local comms = require("comms")

-- data table is the data we want to update interactivly
local MetaElement = {interactive_type = nil, human_readable = nil, data_table = nil}
function MetaElement:new(interactive_type, human_readable, data_table)
    --if type(id) ~= "table" then error("what are you, stupid?!") end
    local new = deep_copy.copy(self, pairs)
    --new.id = id
    new.interactive_type = interactive_type
    new.human_readable = human_readable
    return new
end

function MetaElement:getId()
    return self.id
end

-- fuck it this won't be a hashtable, it'll just be a regular array, we'll just linear search, don't be stupid
local wait_list = {}
local incremental_id = 0
--local incremental_id = math.mininteger

local function get_new_id() -- now with this linear search will no longer be necessary O(1) baby, we could've
                            -- also simply used an offset bu who cares
    incremental_id = incremental_id + 1
    return incremental_id
end

function module.add(interactive_type, human_readable, data_table) -- returns id
    local new_id = get_new_id() 
    local new_element = MetaElement:new(interactive_type, id, human_readable, data_table)
    wait_list[new_id] = new_element
    return id
end

function module.get_data_table(id)
    return wait_list[id]
end

function module.print_list()
    if #wait_list == 0 then
        print(comms.robot_send("info", "--- Wait List is empty ---"))
        return
    end

    for id, element in pairs(wait_list) do
        local print_table = {"id -- [",  id,  "] -- ",  element.interactive_type,  " -- \"",  human_readable,  "\""}
        local print_string = table.concat(print_table)
        print(comms.robot_send("info", print_string))
    end
end

-- gonna need to programe something in prompt side for this cool thing to happen, but can also just add
-- a debug FORCE SET DATA kind of thing
function module.request_form(data, id)
    local element = wait_list[id]
    local t = element.interactive_type
    if t == "auto_build" then
        -- TODO, we gonna FORCE SET for now
        comms.robot_send("start-request", "")
    else
        error(comms.robot_send("fatal", "what are you doing lil' bro interactive.set_data_table"))
    end
end

function module.set_data_table(data, id)
    local element = wait_list[id]
    local t = element.interactive_type
    if t == "auto_build" then
        -- since we don't have the request systme implemented, just add an eval to throw data in
    else
        --enable the following error message if we force data to be handled through requests
        --error(comms.robot_send("fatal", "this is not possible, ahrk, gamma ray inside ram-stick -- error 6969"))
        print(comms.robot_send("error", "interactive.set_data_table, wooopsie doopsie, spell things better dum dum"))
        return nil
    end
end

return module
