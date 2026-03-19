local output_dir = "./output/"

local dry = true
local function compile_file(i_file, o_file)
    if tostring(i_file) == nil or tostring(o_file) == nil then 
        error(string.format("bad file name: %s, %s", i_file, o_file))
    end

    local str = string.format("tl gen %s -c -o %s", i_file, o_file)
    if not dry then os.execute(str)
    else print(str) end
end

local function compile_dir(input_str)
    local input_dir = string.format("./%s/", input_str)
    local output_dir = string.format("./output/%s/", input_str)

    local dir_handle = io.open(output_dir, "r")
    if dir_handle == nil then print(output_dir) end
    io.read()

    for file in io.popen("ls -- " .. input_dir):lines() do
        if string.find(file, ".lua") then compile_file(input_dir .. file, output_dir .. file)
        elseif not string.find(file, ".so") and not string.find(".sh") then compile_dir(input_str .. "/" .. file) end
    end
end

compile_dir("robot")
