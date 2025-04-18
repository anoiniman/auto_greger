local term = require("term")
local io = require("io")
local text = require("text")
local table = require("table")

local comms = require("comms")

term.clear()
term.setCursorBlink(true)
own_terminal()

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

function comm_terminal()
    -- space separeted string input into table
    while true do
        term.write("> ")
        local prompt = io.read()
        local array = text.tokenize(prompt)

        local prio = -1
        if tonumber(array[1]) ~= nil then -- calculate prio if prio is not given as first string
            -- Do nothing, since prio is already inside the array
        else
            prio = calculate_prio(array[1]) -- some special commands will have higher prio
            table.insert(array, 1, prio)
        end

        if #array > 0 then
            comms.controller_send(array)
        else
            print("ERROR! badly formated?")
        end
    end
end

function calculate_prio(command)
    if command == "debug" then return -1 end

    return 50
end
