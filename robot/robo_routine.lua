local module = {}

-- import of globals
local math = require("math")

--[[local text = require("text")
local serialize = require("serialization")
local comms = require("comms")--]]

local eval = require("eval.eval_main")

---------------------------------------

-- task_list is updated by reference
-- linear search should be good enough, surely
-- "-1" is max prio
local function prio_insert(task_list, message)
    -- case task_list is empty
    if #task_list == 0 then
        table.insert(task_list, message)
        return
    end

    local prio = message[1]
    if prio == -1 or prio == -2 then
        table.insert(task_list, message)
        return
    end

    -- prob fine to break since -1 is always added towards the end and we linear search
    for i=1, #task_list, 1 do
        local element = task_list[i]
        local value = element[1]
        if (value == -1) or (prio <= value) then
            local one_or_bigger = math.max(i-1, 1) -- protect against underflows
            table.insert(task_list, one_or_bigger, message)
            return
        end
    end

    -- in case this prio we want to insert is bigger than everything
    table.insert(task_list, message)
end

-- Dangerous global value
-- luacheck: globals INTERACTED
INTERACTED = false

local task_list = {} -- for sure table (table)
local cur_task = nil
-- message = priority + command + arguments
-- task_list == table of messages as a priority queue
function module.robot_routine(message)
    --print("I am not dead!")
    cur_task = nil
    if message ~= nil then
        prio_insert(task_list, message)
        --message = nil
    end


    local extend_queue = nil

    -- ugly cludge, fix later
    local where = #task_list
    while where > 0 do
        cur_task = task_list[#task_list]

        if cur_task ~= nil and #cur_task ~= 0 then
            if cur_task[1] == -2 then
                if INTERACTED then
                    INTERACTED = false
                    extend_queue = eval.eval_command(cur_task)
                    table.remove(task_list, where)
                else
                    where = where - 1
                end
            else
                extend_queue = eval.eval_command(cur_task)
                table.remove(task_list, where)
                break
            end
        else
            task_list[#task_list] = nil
            break
        end
    end

    --if extend_queue ~= nil then table.insert(task_list, extend_queue) end
    if extend_queue ~= nil then
        if type(extend_queue[1]) ~= "table" then
            prio_insert(task_list, extend_queue)
        else
            for _, element in ipairs(extend_queue) do
                prio_insert(task_list, element)
            end
        end
    end
end

return module
