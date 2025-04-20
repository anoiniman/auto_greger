local os = require("os")
local filesystem = require("filesystem")
local io = require("io")

local args = {...}
local counter = 0

function download(origin, where)
    local link = "https://raw.githubusercontent.com/anoiniman/auto_greger/refs/heads/main" .. origin

    local tmp_path = "/tmp/" .. counter .. ".lua"
    os.execute("wget -f " .. link .. " " .. tmp_path)

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
    download("/robot/geolyzer_wrapper.lua", "/home/robot/geolyzer_wrapper.lua")
    download("/robot/nav_module.lua", "/home/robot/nav_module.lua")
    download("/robot/robo_main.lua", "/home/robot/robo_main.lua")
    --download("/robot/robo_main_dbg.lua", "/home/robot/robo_main_dbg.lua")
    --download("/robot/robo_main_dbg2.lua", "/home/robot/robo_main_dbg2.lua")
elseif args[1] == "controller" then
    if not filesystem.isDirectory("/home/controller") then 
        filesystem.makeDirectory("/home/controller")
    end
    download("/controller/draw_things.lua", "/home/controller/draw_things.lua")
    download("/controller/listener.lua", "/home/controller/listener.lua")
    download("/controller/prompt.lua", "/home/controller/prompt.lua")
else
    args[1] = "nil"
    print("Not recognized argument: \"" .. args[1] .. "\"")
end
