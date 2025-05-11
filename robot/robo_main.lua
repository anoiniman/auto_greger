local robot_name = "sumire-chan"

-- import of globals
local io = require("io")

local term = require("term")
local text = require("text")
local serialize = require("serialization")

-- local imports
local comms = require("comms")
local robot_routine = require("robo_routine")

local block_read_bool = true
-- 0 = continue, 1 = stop
local watch_dog = 0
local history = {}

term.clear()
print(comms.robot_send("info", robot_name .. " -- Now Online!"))
term.setCursorBlink(false)

-- Very special commands I guess
function special_message_interpretation(message)
    local priority = message[1]
    local command = message[2]

    if command  == "wait" then
        watch_dog = 1
    elseif command == "resume" then
        watch_dog = 0
    elseif command == "run_auto" or command == "auto_run" or command == "auto" then 
        block_read_bool = false 
    elseif command == "block" then
        block_read_bool = true 
    else -- pass along to co-routine
        watch_dog = 0
        return message
    end
    return nil
end

-- global variable:
ROBO_MAIN_THREAD_SLEEP = 0.2

function robot_main()
    -- START
    comms.setup_listener()

    while true do
        os.sleep(ROBO_MAIN_THREAD_SLEEP)
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

        if watch_dog == 0 or message ~= nil then
            robot_routine.robot_routine(message)
        else
            -- Nothing
        end
    end -- While
end

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

-- Execution into main function always has to occur in the end due to how lua works
robot_main()
