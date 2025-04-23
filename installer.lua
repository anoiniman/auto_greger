local os = require("os")
local filesystem = require("filesystem")
local io = require("io")

local args = {...}
local counter = 0

function download(origin, where)
    local link = "https://raw.githubusercontent.com/anoiniman/auto_greger/refs/heads/main" .. origin

    local tmp_path = "/tmp/" .. counter .. ".lua"
    os.execute("wget -f " .. link .. " " .. tmp_path)

    if where == "self" then
        where = "/home" .. origin
    end

    if not filesystem.exists(where) then
        local result, err = filesystem.rename(tmp_path, where)
        if result == nil then
            print("Error: " .. err)
            return
        end
        print("File: \"" .. where .. "\" is installed!")
        return
    end
    
    if filesystem.size(where) == filesystem.size(tmp_path) and (args[1] ~= "-f" and args[2] ~= "-f") then
        print("File: \"" .. where .. "\" doesn't need update")
        --cur_file.close()
        return
    end
    print("e")

    filesystem.remove(where)
    local result, err = filesystem.rename(tmp_path, where)
    if result == nil then 
        print("Error:" .. err) 
        return
    end
    print("File: \"" .. where .. "\" is updated!")

    counter = counter + 1
end

if not filesystem.isDirectory("/usr/lib") then
    filesystem.makeDirectory("/usr/lib")
end

download("/shared/comms.lua", "/usr/lib/comms.lua")

if args[1] == "robot" then
    if not filesystem.isDirectory("/home/robot") then 
        filesystem.makeDirectory("/home/robot")
    end

    download("/robot/geolyzer_wrapper.lua", "self")
    --download("/robot/nav_module.lua", "self")
    download("/robot/robo_main.lua", "self")
    download("/robot/robo_routine.lua", "self")
    
    if not filesystem.isDirectory("/home/robot/eval") then
       filesystem.makeDirectory("/home/robot/eval")
    end
    download("/robot/eval/eval_main.lua", "self")
    download("/robot/eval/debug.lua", "self")
    download("/robot/eval/navigate_chunk.lua", "self")

    if not filesystem.isDirectory("/home/robot/nav_module") then
       filesystem.makeDirectory("/home/robot/nav_module")
    end

    download("/robot/nav_module/nav_obj.lua", "self")
    download("/robot/nav_module/nav_interface.lua", "self")
    download("/robot/nav_module/chunk_move.lua", "self")

elseif args[1] == "controller" then
    if not filesystem.isDirectory("/home/controller") then 
        filesystem.makeDirectory("/home/controller")
    end
    download("/controller/draw_things.lua", "self")
    download("/controller/listener.lua", "self")
    download("/controller/prompt.lua", "self")
else
    args[1] = "nil"
    print("Not recognized argument: \"" .. args[1] .. "\"")
end
