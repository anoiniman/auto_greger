local module = {}

-- import of globals
local math = require("math")

local text = require("text")
local serialize = require("serialization")

local comms = require("comms")
local eval = require("eval.eval_main")

---------------------------------------

-- task_list is updated by reference
-- linear search should be good enough, surely
-- "-1" is max prio
function prio_insert(task_list, message)
    -- case task_list is empty
    if #task_list == 0 then
        table.insert(task_list, message)
        return
    end

    local prio = message[1]
    if prio == -1 then
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

local task_list = {} -- for sure table (table)
local cur_task = nil
-- message = priority instruction + command + arguments
-- task_list == table of messages as a priority queue
function module.robot_routine(message)
    --print("I am not dead!")
    cur_task = nil
    if message ~= nil then
        print("Pre-Prio Insert, message: " .. serialize.serialize(message, true))
        prio_insert(task_list, message)
        message = nil
    end
    if #task_list > 0 then
        cur_task = table.remove(task_list)
        print("Cur_Task: " .. serialize.serialize(cur_task, true))
    end

    local extend_queue = nil
    if cur_task ~= nil and #cur_task ~= 0 then
        print("Pre-Eval")
        extend_queue = eval.eval_command(cur_task)
        print("Post-Eval")
    end

    --if extend_queue ~= nil then table.insert(task_list, extend_queue) end
    if extend_queue ~= nil then 
        print("Attempting to extend_queue")
        prio_insert(task_list, extend_queue) 
    end
end

return module
