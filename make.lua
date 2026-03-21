local output_dir = "./output"
local include_dir = ""

local dry = false
local debug_mode = false

local force_recompile = false
local only_check = false
local ask_for_permission = false

local args = {...}
for _, arg in ipairs(args) do
    if string.find(arg, "-") and not string.find(arg, "--") then
        if string.find(arg, "B") then force_recompile = true end
        if string.find(arg, "a") then ask_for_permission = true end
    end

    if arg == "--check" then only_check = true
    elseif arg == "--ask" then ask_for_permission = true end
end

print("force_recompile: " .. tostring(force_recompile))
print("only_check: " .. tostring(only_check))
if ask_for_permission then
    io.write("[y/N]? ")
    local reply = string.upper(io.read())
    if reply == "N" or reply ~= "Y" then return end
end

local function dprint(...)
    if debug_mode or force then print(...) end
end

local function get_file_mod_date(file_name)
    local file_handle = io.open(file_name, "r")
    if file_handle == nil then return 0
    else file_handle:close() end

    local unix_time = tonumber(io.popen("stat --format=\"%Y\" " .. file_name):lines()()) -- ugly lol
    return unix_time
end

local function compile_file(i_file, o_file)
    if tostring(i_file) == nil or tostring(o_file) == nil then
        error(string.format("bad file name: %s, %s", i_file, o_file))
    end

    local i_time = get_file_mod_date(i_file)
    local o_time = get_file_mod_date(o_file)
    dprint("i_time: " .. i_time)
    dprint("o_time: " .. o_time)

    if not only_check and not force_recompile and o_time >= i_time then return end

    local str
    -- if only_check then str = string.format("./tl check %s", i_file)
    if only_check then str = string.format("./tl -p %s gen %s -c -o %s", include_dir, i_file, o_file)
    else str = string.format("./tl %s gen %s -c -o %s", include_dir, i_file, o_file) end

    if not dry then os.execute(str) end
    print(str)
end

local function compile_dir(input_name)
    local input_dir = string.format("./%s/", input_name)
    local output_dir = string.format("%s/%s/", output_dir, input_name)

    local dir_handle = io.open(output_dir, "r")
    if dir_handle == nil then os.execute("mkdir " .. output_dir)
    else dir_handle:close() end

    for file in io.popen("ls -- " .. input_dir):lines() do
        if string.find(file, ".lua") then compile_file(input_dir .. file, output_dir .. file)
        elseif  not string.find(file, ".so")
                and not string.find(file, ".sh")
                and not string.find(file, ".fs")
        then
            compile_dir(input_name .. "/" .. file)
        end
    end
end

local function prepare_include(dir_name)
    local dir_path = string.format("./%s/", dir_name)
    include_dir = string.format("%s -I %s ", include_dir, dir_path)

    for file in io.popen("ls -- " .. dir_path):lines() do
        if
                not string.find(file, ".lua")
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
compile_dir("robot")
