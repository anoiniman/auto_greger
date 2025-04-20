-- import of globals
local math = require("math")
local io = require("io")

local robot = require("robot")
local term = require("term")
local text = require("text")
local serialize = require("serialization")

-- local imports
local comms = require("comms")
local nav = require("nav_module")
local geolyzer = require("geolyzer_wrapper")

local command = nil
--local robot_routine = coroutine.create(robot_routine_func)
local robot_routine = nil

local block_read_bool = true
-- 0 = continue, 1 = stop
local watch_dog = 0
local history = {}

term.clear()
print(comms.robot_send("info", "Now Online!"))
term.setCursorBlink(false)


-- I want brackets back {}

-- Very special commands I guess
function special_message_interpretation(message)
    local priority = message[1]
    local command = message[2]

    if command  == "wait" then
        watch_dog = 1
    elseif command == "resume" then
        watch_dog = 0
    elseif command == "run_auto" then 
        block_read_bool = false 
    else -- pass along to co-routine
        watch_dog = 0
        wait_for_yield()
        coroutine.resume(robot_routine, message)
    end
end

function wait_for_yield()
    while true do
        os.sleep(0.1)
        if coroutine.status(robot_routine) == "suspended" then
            return
        end
    end
end


-- task_list is updated by reference
-- linear search should be good enough, surely
-- "-1" is max prio
function prio_insert(task_list, message)
    -- case task_list is empty
    if #task_list == 0 then
        table.insert(task_list, message)
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

function eval_command(command, argument)
    if command == "echo" then
        local text = serialize.serialize(argument, true)
        print(comms.robot_send("response", text))
    elseif command == "debug" then
        if argument[1] == "geolyzer" then
            if argument[2] ~= nil then -- expects sides api derived num
                geolyzer.debug_print(argument[2]) 
            end
        elseif argument[1] == "move" then
            nav.debug_move("north", 1, false)
        else
            print(comms.robot_send("error", "non-recongized argument for debug"))
        end
    end
    return nil
end

-- message = priority instruction + command pair
-- task_list == table of messages as a priority queue
function robot_routine_func()
    local message = nil -- prob table (tuple)
    local task_list = {} -- for sure table (table)

    while true do
        local cur_task = nil
        if message ~= nil then
            prio_insert(task_list, message)
            message = nil
        end
        if #task_list > 0 then
            cur_task = table.remove(message)
        end

        local extend_queue = eval_command(cur_task)
        --if extend_queue ~= nil then table.insert(task_list, extend_queue) end
        if extend_queue ~= nil then prio_insert(task_list, extend_queue) end
    
        message = coroutine.yield()
    end
end

robot_routine = coroutine.create(robot_routine_func)

function blocking_prompt() -- Return Command
    term.write("> ")
    term.setCursorBlink(true)
    local read = io.read()
    print("")
    term.setCursorBlink(false)

    --table.insert(history, read)
    local post_read = text.tokenize(read)

    if post_read == nil or #post_read < 1 or #post_read > 2 then
        print("Invalid command lenght: \"" .. read .. "\"")
        return nil
    elseif #post_read == 1 then 
        table.insert(post_read, nil)
    end

    table.insert(post_read, 1, -1)

    return post_read -- Special command to stop blocking "run_auto"
end

function robot_main()
    -- START
    --robot_routine.resume()
    coroutine.resume(robot_routine)

    while true do
        os.sleep(0.1)
        local block_message = nil

        if block_read_bool == true then
            local block = blocking_prompt()
            if block ~= nil then
                block_message = block
            end
        end

        local rec_state, addr, message
        if block_message == nil then
            rec_state, addr, message = comms.recieve()
        else
            rec_state, addr, message = true, "self", block_message
        end

        if rec_state == true then
            if addr ~= "self" then
                print(comms.robot_send("error", "Non-Tunnel Communication NOT IMPLEMENTED!"))
            else
                special_message_interpretation(message)
            end
        end

        if watch_dog == 0 then
            coroutine.resume(robot_routine)
        else
            -- Nothing
        end
    end -- While
end


-- Execution into main function always has to occur in the end due to how lua works
robot_main()
