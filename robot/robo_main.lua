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


function wait_for_yield()
    while true do
        os.sleep(0.1)
        if coroutine.status(robot_routine) == "suspended" then
            return
        end
    end
end

-- Very special commands I guess
function special_message_interpretation(message)
    local priority = message[1]
    local command = message[2]

    if command  == "wait" then
        watch_dog = 1
    elseif command == "resume" then
        watch_dog = 0
    elseif command == "run_auto" or command == "auto_run" then 
        block_read_bool = false 
    elseif command == "block" then
        block_read_bool = true 
    else -- pass along to co-routine
        watch_dog = 0
        wait_for_yield()
        coroutine.resume(robot_routine, message)
    end
end

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

function eval_command(command_argument)
    local prio = table.remove(command_argument, 1)
    local command = table.remove(command_argument, 1)
    local argument = command_argument

    local serial_argument = serialize.serialize(argument, true)
    print("Debug -- Attempting to Eval: \"" .. command .. ", " .. serial_argument)
    if command == "echo" then
        local text = serialize.serialize(argument, true)
        print("Debug -- Attempting to Echo")
        print(comms.robot_send("response", text))
    elseif command == "debug" then
        if argument[1] == "geolyzer" then
            local side = argument[2]
            if side == nil then -- expects sides api derived num
                side = 0 -- defaults to down
            end
            geolyzer.debug_print(side) 
        elseif argument[1] == "move" then
            local move = argument[2]
            local how_much = argument[3]
            local forget = argument[4]
            if move == nil then
                print(comms.robot_send("error", "nil direction in debug move"))
                return nil
            end
            if how_much == nil then
                how_much = 1    
            end
            if forget == nil then
                forget = false
            end

            print("attempting to move")
            nav.debug_move(move, how_much, forget)
        elseif argument[1] == "surface_move" then
            local x = argument[2]
            local z = argument[3]

            if x == nil or z == nil then
                print(comms.robot_send("error", "nil objective chunk in debug surface_move"))
                return nil
            end
            local chunk = {x,z}
            nav.setup_navigate_chunk(chunk)
            return {50, "navigate_chunk", "surface"}
        else
            print(comms.robot_send("error", "non-recogized argument for debug"))
        end
    elseif command == "navigate_chunk" then
        local what_kind = argument[1]
        if what_kind == nil then
            print(comms.robot_send("error", "navigate chunk, non-recognized \"what kind\""))
            return nil
        end
        local finished = nav.navigate_chunk()
        if not finished then
            return {50, command, what_kind}
        end
    end
    return nil
end

-- message = priority instruction + command + arguments
-- task_list == table of messages as a priority queue
function robot_routine_func()
    local message = nil -- prob table (tuple)
    local task_list = {} -- for sure table (table)
    local cur_task = nil

    print("I am not dead!")
    while true do
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
            extend_queue = eval_command(cur_task)
            print("Post-Eval")
        end

        --if extend_queue ~= nil then table.insert(task_list, extend_queue) end
        if extend_queue ~= nil then 
            print("Attempting to extend_queue")
            prio_insert(task_list, extend_queue) 
        end
        --print("Attempting to yield")
    
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
    print(#post_read)

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
    comms.setup_listener()
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
            local recieve_table = comms.recieve()
            rec_state = recieve_table[1]
            addr = recieve_table[2]
            message = recieve_table[3]
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
