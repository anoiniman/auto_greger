local term = require("term")
local io = require("io")
local text = require("text")
local table = require("table")
local keyboard = require("keyboard")

local comms = require("comms")

term.clear()
term.setCursorBlink(true)

-- when we recieve things we recieve them as strings, when we send'em we send 'em as string + table

local exit_own = false
local exit_comm = false

local function calculate_prio(command)
    if command == "debug" then return -1 end

    return 50
end

local function simple_print(msg_tbl)
        local first_tbl = { "<| ", msg_tbl[1], " |> | ", msg_tbl[2] }
        local to_print = table.concat(first_tbl)

        print(to_print)
end

local function print_mode()
    while not keyboard.isKeyDown(keyboard.keys.q) do
        os.sleep(0.33) -- luacheck: ignore
        local r_table = comms.recieve()
        local something, _, msg_tbl = r_table[1], r_table[2], r_table[3]
        if something == true then simple_print(msg_tbl) end
    end
end

local function comm_terminal()
    comms.setup_listener()
    -- space separeted string input into table
    while not exit_comm do
        term.write("> ")
        local prompt = io.read()
        local array = text.tokenize(prompt)

        local prio = -1 -- luacheck: ignore
        -- luacheck: ignore
        if array == nil or tonumber(array[1]) ~= nil then -- calculate prio if prio is not given as first string
            -- Do nothing, since prio is already inside the array
        else
            prio = calculate_prio(array[1]) -- some special commands will have higher prio
            table.insert(array, 1, prio)
        end

        if array ~= nil and #array > 0  then
            if array[2] == "exit" then
                exit_comm = true
            elseif array[2] == "s" or array[2] == nil then
                -- luacheck: ignore
            elseif array[2] == "print_mode" then
                print_mode()
            else
                comms.controller_send(array)
            end
        else
            print("ERROR! badly formated?")
        end

        local r_table = comms.recieve()
        local something, _, msg_tbl = r_table[1], r_table[2], r_table[3]
        if something == true then simple_print(msg_tbl) end

        os.sleep(0.1)
    end
end

local function own_terminal()
    while not exit_own do
        exit_own = false
        term.write("# ")
        local proompt = io.read()
        if proompt == "comm" then
            comm_terminal()
        elseif proompt == "exit" then
            exit_own = true
        end
    end
end

own_terminal()
