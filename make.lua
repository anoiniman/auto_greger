local output_dir = "output"
local include_dir = ""

local pwd = io.popen("pwd"):lines()()

local root_dir = {}
for slice in string.gmatch(pwd, "([^".."/".."]+)") do
    table.insert(root_dir, slice)
end
-- print(table.concat(root_dir, "/"))

local function find_root_dir()
    -- TODO not the smartest way to go about this but good enough
    if #root_dir == 0 then 
        error(string.format(
            "Tried walking back from pwd: %s\n\z
            but couldn't find make.lua, what now? Are you in the right directory?", pwd
        )) 
    end

    local root_dir_str = "/" .. table.concat(root_dir, "/")
    local cur_file = string.format("%s/make.lua", root_dir_str)
    local handle = io.open(cur_file, "r")
    if handle == nil then
        table.remove(root_dir, #root_dir)
        return find_root_dir()
    end
    handle:close()
    return root_dir_str
end
root_dir = find_root_dir()
print("root_dir: " .. root_dir)

local dry = false
local verbose = false

local force_recompile = false
local only_check = false
local ask_for_permission = false
local quiet_mode = false

local file_mode = nil

local args = {...}

local function set_file_mode(cur_index)
    local next_index = cur_index + 1
    local file_name = args[next_index]
    if file_name == nil then error("Error no file_name provided for option -f/--file") end

    file_mode = file_name
    print("set_file_mode = " .. file_mode)
end

for index, arg in ipairs(args) do
    if string.find(arg, "^%-") and not string.find(arg, "^%-%-") then
        if string.find(arg, "a") then ask_for_permission = true end
        if string.find(arg, "B") then force_recompile = true end
        if string.find(arg, "f") then set_file_mode(index) end
        if string.find(arg, "v") then verbose = true end
        if string.find(arg, "q") then quiet_mode = true end
    end

    if arg == "--check" then only_check = true
    elseif arg == "--dry" then dry = true
    elseif arg == "--ask" then ask_for_permission = true
    elseif arg == "--file" then set_file_mode(index)
    elseif arg == "--force" then force_recompile = true end
end

print("dry: " .. tostring(dry))
print("force_recompile: " .. tostring(force_recompile))
print("only_check: " .. tostring(only_check))
if ask_for_permission then
    io.write("[y/N]? ")
    local reply = string.upper(io.read())
    if reply == "N" or reply ~= "Y" then return end
end
if dry then io.write("DRY RUN -> PRESS ENTER TO CONFIRM"); io.read() end
if force_recompile then verbose = true end
if verbose then quiet_mode = false end

local function vprint(...)
    if verbose then print(...) end
end
local function qprint(...)
    if not quiet_mode then print(...) end
end

local function get_file_mod_date(file_name)
    local file_handle = io.open(file_name, "r")
    if file_handle == nil then return 0
    else file_handle:close() end

    local unix_time = tonumber(io.popen("stat --format=\"%Y\" " .. file_name):lines()()) -- ugly lol
    return unix_time
end

local function file_op(i_file, o_file, func)
    if tostring(i_file) == nil or tostring(o_file) == nil then
        error(string.format("bad file name: %s, %s", i_file, o_file))
    end

    local i_time = get_file_mod_date(i_file)
    local o_time = get_file_mod_date(o_file)
    vprint("i_time: " .. i_time)
    vprint("o_time: " .. o_time)

    if not dry and not only_check and not force_recompile and o_time >= i_time then return end
    func()
end

local function compile_file(i_file, o_file)
    local exec_str
    if only_check then 
        exec_str = string.format("%s/tl -p %s gen %s -c -o %s", root_dir, include_dir, i_file, o_file)
    else 
        exec_str = string.format("%s/tl %s gen %s -c -o %s", root_dir, include_dir, i_file, o_file) 
    end

    local function func()
        if not dry then os.execute(exec_str) end
        qprint(exec_str)
    end

    file_op(i_file, o_file, func)
end

local function copy_file(i_file, o_file)
    local exec_str = string.format("cp %s %s", i_file, o_file)
    local function func()
        if not only_check and not dry then os.execute(exec_str) end
        qprint(exec_str)
    end

    file_op(i_file, o_file, func)
end

local function compile_dir(input_name)
    local input_dir = string.format("%s/%s/", root_dir, input_name)
    local output_dir = string.format("%s/%s/%s/", root_dir, output_dir, input_name)

    local dir_handle = io.open(output_dir, "r")
    if dir_handle == nil then os.execute("mkdir " .. output_dir)
    else dir_handle:close() end

    for file in io.popen("ls -- " .. input_dir):lines() do
        if string.find(file, ".tl") then compile_file(input_dir .. file, output_dir .. file)
        elseif string.find(file, ".lua") then copy_file(input_dir .. file, output_dir .. file)
        elseif  not string.find(file, ".so")
                and not string.find(file, ".sh")
                and not string.find(file, ".fs")
        then
            compile_dir(input_name .. "/" .. file)
        end
    end
end

local function prepare_include(dir_name)
    local dir_path = string.format("%s/%s/", root_dir, dir_name)
    include_dir = string.format("%s -I %s ", include_dir, dir_path)

    for file in io.popen("ls -- " .. dir_path):lines() do
        if
                not string.find(file, ".lua")
                and not string.find(file, ".tl")
                and not string.find(file, ".so")
                and not string.find(file, ".sh")
                and not string.find(file, ".fs")
        then
            prepare_include(dir_name .. "/" .. file)
        end
    end
end

--[[local function clean_dir(dir_name)
    local dir_path = string.format("./%s/", dir_name)
    for file in io.popen("ls -- " .. dir_path):lines() do
        os.execute("rm -i " .. dir_name
    end
end--]]

prepare_include("shared")
prepare_include("robot")
if file_mode == nil then
    compile_dir("robot")
else
    local file_i_path = string.format("%s/%s", pwd, file_mode)
    local file_o_path = string.format("%s/%s", pwd, string.gsub(file_mode, "%..*", ".lua"))
    compile_file(file_i_path, file_o_path)
end

if dry then print("Dry run concluded") end
