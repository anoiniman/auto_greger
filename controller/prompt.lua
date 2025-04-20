local term = require("term")
local io = require("io")
local text = require("text")
local table = require("table")

local comms = require("comms")

term.clear()
term.setCursorBlink(true)

-- when we recieve things we recieve them as strings, when we send'em we send 'em as string + table

function own_terminal()
    while true do
        term.write("# ")
        local proompt = io.read()
        if proompt == "comm" then
            comm_terminal()
        end
    end
end

function calculate_prio(command)
    if command == "debug" then return -1 end

    return 50
end

function comm_terminal()
    -- space separeted string input into table
    while true do
        term.write("> ")
        local prompt = io.read()
        local array = text.tokenize(prompt)

        local prio = -1
        if array == nil or tonumber(array[1]) ~= nil then -- calculate prio if prio is not given as first string
            -- Do nothing, since prio is already inside the array
        else
            prio = calculate_prio(array[1]) -- some special commands will have higher prio
            table.insert(array, 1, prio)
        end

        if array ~= nil and #array > 0 and array[1] ~= "s" then
            comms.controller_send(array)
        elseif array[1] == "s" then
            --print("ERROR! badly formated?")
        else
            print("ERROR! badly formated?")
        end

        os.sleep(0.1)
        local something, _, message_string = comms.recieve()
        if something == true then print(message_string) end
    end
end

own_terminal()
