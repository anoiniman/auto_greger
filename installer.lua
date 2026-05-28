-- RESERVED
-- RESERVED

local os = require("os")
local filesystem

local args = {...}
local branch = "master"

local dry_mode = false
local function execute(str)
    if dry_mode == true then print(string.format("os.execute(%s)", str))
    else os.execute(str) end
end

local function simple_hash(str)
    local hash_value = -3750763034362895579  -- FNV offset basis
    local fnv_prime = 1099511628211     -- FNV prime
    for i = 1, #str do
        local char = str:sub(i, i)
        hash_value = hash_value ~ string.byte(char) -- XOR with the byte (silly LLM was using bit.xor)
        hash_value = hash_value * fnv_prime         -- Multiply by the prime
    end
    return hash_value
end

local function file_hash(path)
    local file = io.open(path, "r")
    local str = file:read("*a")
    file:close()
    return simple_hash(str)
end

local function self_hash()
    local file = io.open("./installer.lua", "r")
    file:read("l")

    local str = file:read("*a")
    file:close()
    return simple_hash(str)
end


-- values: "gen" and "install"
local command_pos
local do_what

for index, arg in ipairs(args) do
    command_pos = index

    if string.find(arg, "^%-") and not string.find(arg, "^%-%-") then end

    if arg == "--dry" then
        dry_mode = true
    end

    if arg == "gen" then 
        do_what = "gen" 
        break
    end

    if arg == "install" then
        local err_state
        err_state, filesystem = pcall(require, "filesystem")
        if err_state == false or filesystem == nil then error("Cannot Install -- Not in OpenComputers Environment") end
        do_what = "install"
        break
    end

    if arg == "help" then
        do_what = "help"
        break
    end
end

if do_what == nil then
    print(
       "\z
        auto_gregger installer utility \n\n\z
        Usage: ./installer [OPTIONS] [COMMAND]\n\n\z

        OPTIONS:\n\z
        \0 -h, --help .. Print help\n\z
        \0 --dry .. Do a dry run

        Commands:\n\z
        \t gen .. Generate dynamic download+check code (to be used from development environemnt)\n\z
        \t install .. Download files into opencomputers computer/robot whatever\n\z
        \t checksum .. Check downloaded files with known checksums, optionally reinstall bad files\n\n\z

        See './installer help <command>' for more information on a specific command.
       "
    )
    return
end

local function get_file_mod_date(file_name)
    local file_handle = io.open(file_name, "r")
    if file_handle == nil then return 0
    else file_handle:close() end

    local unix_time = tonumber(io.popen("stat --format=\"%Y\" " .. file_name):lines()()) -- ugly lol
    return unix_time
end

if do_what == "gen" then
    local info_string = "module.info_tbl={"
    local dir_string = "module.dir_tbl={"

    local function record_file_info(var_name)
        local dirs_table = {}
        local file_paths, file_dates, file_hashes = {}, {}, {}
        local function recursive_append_dir(input_dir)
            for file in io.popen("ls -- " .. input_dir):lines() do
                if string.find(file, "%.lua$") then 
                    local path = input_dir .. "/" .. file
                    table.insert(file_paths, path)
                    table.insert(file_dates, get_file_mod_date(path))
                    table.insert(file_hashes, file_hash(path))
                elseif not string.find(file, "%..*$") then
                    local new_dir = input_dir .. "/" .. file
                    if var_name == "robot" then table.insert(dirs_table, new_dir) end
                    recursive_append_dir(new_dir)
                end
            end
        end

        info_string = info_string .. string.format("[\"%s\"]={", var_name)
        recursive_append_dir("./output/" .. var_name)
        for index, path in ipairs(file_paths) do
            local date = file_dates[index]
            local hash = file_hashes[index]
            local entry_str = string.format("{\"%s\",\"%s\",\"%s\"},", path, date, hash)
            info_string = info_string .. entry_str
        end
        info_string = info_string .. "},"

        for _, dir_path in ipairs(dirs_table) do
            dir_string = dir_string .. string.format("\"%s\",", dir_path)
        end
    end

    record_file_info("shared")
    record_file_info("robot")
    -- add "controller" eventually
    info_string = info_string .. "};"
    dir_string = dir_string .. "};"

    os.execute(string.format("sed -i '2c%s' ./install_info.lua", dir_string))
    os.execute(string.format("sed -i '3c%s' ./install_info.lua", info_string))

    local cmp_hash_str = "local cmp_hash = " .. tostring(self_hash())
    os.execute(string.format("sed -i '1c%s' ./installer.lua", cmp_hash_str))
end

if do_what == "install" then
    local force_download = false

    local s_hash = self_hash()
    print("cmp_hash = " .. cmp_hash)
    print("s_hash = " .. s_hash)

    if cmp_hash ~= cmp_hash2 then
        print("ERROR -- cmp_hash ~= s_hash -- [press enter]")
        io.read()
        error("self_hash not equal")
    end

    local abort_counter = 0
    local function download(from, to)
        local link = "https://raw.githubusercontent.com/anoiniman/auto_greger/refs/heads/" .. branch .. from

        local tmp_path = "/tmp/" .. "a.lua"
        os.execute(string.format("wget -f %s %s > /dump.txt", link, tmp_path))

        if to == "--robot" then
            to = "/home/robot" .. from
        end

        if not filesystem.exists(to) then
            local result, err = filesystem.rename(tmp_path, to)
            if result == nil then
                print("Error: " .. err)
                return false
            end
            print(string.format("+%s"), to)
            return true
        end

        local are_equal = false
        if not force_download then
            local from_checksum = file_hash(to)
            local new_checksum = file_hash(tmp_path)
            are_equal = (from_checksum == new_checksum and filesystem.size(to) == filesystem.size(tmp_path))
        end

        if are_equal then
            return true
        end

        filesystem.remove(to)
        local result, err = filesystem.rename(tmp_path, to)
        if result == nil then
            print("Error:" .. err)
            return false
        end
        print(string.format("-+%s", to))

        return true
    end

    if not download("/install_info.lua", "/home") then
        error("Failed to download install_info.lua file -- fatal -- check your internet connection")
    end

    local install_info = loadfile("/home/install_info.lua")
    local function download_module(name)
        local module_info = install_info.info_tbl[name]
        if module_info == nil then 
            error(
                string.format("Module: \"%s\" does not exist in install_info.lua :P --\n\z
                if in release branch -> contact maintainer\n\z
                else it's your problem lmao")
            )
        end

        for _, entry in ipairs(module_info) do
            download(entry.path)
        end
    end

    for index = command_pos + 1, #args, 1 do
        local arg = args[index]

        if string.find(arg, "^%-") and not string.find(arg, "^%-%-") then
            if string.find(arg, "f") then force_download = true end
        end
        if string.find(arg, "--branch=") then 
            branch = string.sub(arg, 8)
        elseif string.find(arg, "--force") then force_download = true end
    end

    for index = command_pos + 1, #args, 1 do
        local arg = args[index]

        if string.find(arg, "^%-") and not string.find(arg, "^%-%-") then end
        if arg == "robot" or arg == "controller" or arg == "shared" then
            download_module(arg)
        end
        if arg == "all" or arg == "a" then
            download_module("robot")
            download_module("controller")
            download_module("shared")
        end
    end

end
