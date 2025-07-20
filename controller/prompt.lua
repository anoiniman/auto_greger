local io = require("io")
local term = require("term")
local text = require("text")

local computer = require("computer")
local keyboard = require("keyboard")

local deep_copy = require("deep_copy")
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
    local print_clock = 0
    while not keyboard.isKeyDown(keyboard.keys.q) do
        if computer.uptime() - print_clock > 0.2 then
            do_recieve()
            print_clock = computer.uptime()
        end
    end
end

local ppObj = require("common_pp_format")
local valid_command_table = {
    ppObj = ppObj
}

local function do_recieve()
    local r_table = comms.recieve()
    local something, _, msg_tbl = r_table[1], r_table[2], r_table[3]
    if something ~= true then return end

    local msg_type = msg_tbl[1]
    if msg_type == "command" or msg_type == "exec" or msg_type == "execute" then
        local copy = deep_copy.copy(msg_tbl)
        table.remove(copy, 1)

        local table_name = table.remove(copy, 1)
        local f_table = valid_command_table[table_name]
        if f_table == nil then
            simple_print({"internal_error", table.concat({"table (name): ", table_name, " -- the table name is invalid"})})
        end

        local func_name = table.remove(copy, 1)
        local func = f_table[func_name]
        if func == nil then
            simple_print({"internal_error", table.concat({"command (name): ", func_name, " -- the func name is invalid"})})
        end

        local serial_obj = copy[1]
        if type(serial_obj) == "table" then -- we assume that a table will be a deconstituted class-object
            local reconstituted_obj = table_name:new()
            for key, value in pairs(serial_obj) do
                reconstituted_obj[key] = serial_obj[value]
            end
            copy[1] = reconstituted_obj
        elseif serial_obj == "nil" then table.remove(copy, 1) end -- a nice hack

        local result, err = pcall(func, table.unpack(copy)) -- we'll prob never check for actual returns n' shiet
        if not result then 
            simple_print(
                {"internal_error", table.concat({"error executing command (name): ", table_name, "\n(error)", err})}
            ) 
        end
    else
        simple_print(msg_tbl)
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


        os.sleep(0.1)
    end
    exit_comm = false
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
