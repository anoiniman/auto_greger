local module = {}

-- import of globals
local math = require("math")

local serialize = require("serialization")
--[[local text = require("text")--]]
local comms = require("comms")

local eval = require("eval.eval_main")

---------------------------------------

-- task_list is updated by reference
-- linear search should be good enough, surely
-- "-1" is max prio
local function prio_insert(task_list, message)
    local prio = message[1]
    if prio == nil then
        print(comms.robot_send("error", "prio is nil, from message (it'll be ignored), message is:"))
        local serial = serialize.serialize(message, true)
        print(comms.robot_send("error", serial))
        return
    end

    -- case task_list is empty
    if #task_list == 0 then
        table.insert(task_list, message)
        return
    end

    if prio == -1 or prio == -2 then
        table.insert(task_list, message)
        return
    end

    -- prob fine to return since -1 is always added towards the end and we linear search
    for index, element in ipairs(task_list) do
        local value = element[1]
        if (value == -1) or (prio < value) then
            table.insert(task_list, index, message)
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

    local extend_queue = {} -- yes, its an array alloc every loop who cares
    -- ugly cludge, fix later
    local where = #task_list

    local gate_delay = nil
    while where > 0 do
        cur_task = task_list[where]

        if cur_task ~= nil and #cur_task ~= 0 then
            if cur_task[1] == -2 then
                if INTERACTED then
                    gate_delay = false
                    local maybe_extend = eval.eval_command(cur_task)
                    if maybe_extend ~= nil then table.insert(extend_queue, maybe_extend) end
                    table.remove(task_list, where)
                    where = where - 1
                else
                    where = where - 1
                end
            else
                local maybe_extend = eval.eval_command(cur_task)
                if maybe_extend ~= nil then table.insert(extend_queue, maybe_extend) end
                table.remove(task_list, where)
                break
            end
        else
            task_list[where] = nil
            break
        end
    end
    if gate_delay ~= nil then
        INTERACTED = gate_delay
    end

    --if extend_queue ~= nil then table.insert(task_list, extend_queue) end
    if #extend_queue > 0 then
        for _, element in ipairs(extend_queue) do
            prio_insert(task_list, element)
        end
    end
end

return module
