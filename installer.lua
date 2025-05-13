local os = require("os")
local filesystem = require("filesystem")
local io = require("io")

local args = {...}
local counter = 0
local branch = "master"

local function download(origin, where)
    local link = "https://raw.githubusercontent.com/anoiniman/auto_greger/refs/heads/" .. branch .. origin

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

local function check_in_args(arguments, check)
    for _, v in ipairs(arguments) do
        if v == check then return true end
    end
    return false
end

local function shared()
    if not filesystem.isDirectory("/usr/lib") then
        filesystem.makeDirectory("/usr/lib")
    end

    download("/shared/comms.lua", "/usr/lib/comms.lua")
    download("/shared/deep_copy.lua", "/usr/lib/deep_copy.lua")
    download("/shared/prio_insert.lua", "/usr/lib/prio_insert.lua")
end

local function robot_top_level()
    if not filesystem.isDirectory("/home/robot") then 
        filesystem.makeDirectory("/home/robot")
    end

    download("/robot/geolyzer_wrapper.lua", "self")
    download("/robot/geolyzer_ore_table.lua", "self")
    download("/robot/interactive.lua", "self")
    download("/robot/keep_alive.lua", "self")
    download("/robot/post_exit.lua", "self")

    download("/robot/robo_main.lua", "self")
    download("/robot/robo_routine.lua", "self")
end

local function robot_eval()
    if not filesystem.isDirectory("/home/robot/eval") then
       filesystem.makeDirectory("/home/robot/eval")
    end

    download("/robot/eval/build.lua", "self")
    download("/robot/eval/debug.lua", "self")
    download("/robot/eval/eval_main.lua", "self")
    download("/robot/eval/navigate.lua", "self")
end

local function robot_navigation()
    if not filesystem.isDirectory("/home/robot/nav_module") then
       filesystem.makeDirectory("/home/robot/nav_module")
    end

    download("/robot/nav_module/chunk_move.lua", "self")
    download("/robot/nav_module/map_obj.lua", "self")
    download("/robot/nav_module/MetaQuad.lua", "self")

    download("/robot/nav_module/nav_interface.lua", "self")
    download("/robot/nav_module/nav_obj.lua", "self")

    download("/robot/nav_module/rel_move.lua", "self")
end

local function robot_build_primitives()
    if not filesystem.isDirectory("/home/robot/build") then
       filesystem.makeDirectory("/home/robot/build")
    end

    download("/robot/build/coke_quad.lua", "self")
    download("/robot/build/hole_home.lua", "self")
end

local function robot_meta_build()
    if not filesystem.isDirectory("/home/robot/build/MetaBuild") then
       filesystem.makeDirectory("/home/robot/build/MetaBuild")
    end

    download("/robot/build/general_functions.lua", "self")
    download("/robot/build/MetaBuild/init.lua", "self")
    download("/robot/build/MetaBuild/MetaDoorInfo.lua", "self")
    download("/robot/build/MetaBuild/MetaSchematic.lua", "self")
    download("/robot/build/MetaBuild/SchematicInterface.lua", "self")
end

-- one day option to download different script folders etc, but not today
local function robot_reasoning()
    if not filesystem.isDirectory("/home/robot/reasoning") then
       filesystem.makeDirectory("/home/robot/reasoning")
    end

    download("/robot/reasoning/MetaRecipe.lua", "self")
    download("/robot/reasoning/MetaScript.lua", "self")
    download("/robot/reasoning/reasoning_obj.lua", "self")

    if not filesystem.isDirectory("/home/robot/reasoning/recipes") then
       filesystem.makeDirectory("/home/robot/reasoning/recipes")
    end

    if not filesystem.isDirectory("/home/robot/reasoning/recipes/stone_age") then
       filesystem.makeDirectory("/home/robot/reasoning/recipes/stone_age")
    end

    --download("/robot/reasoning/recipes/stone_age/essential01.lua", "self")

    if not filesystem.isDirectory("/home/robot/reasoning/scripts/debug") then
       filesystem.makeDirectory("/home/robot/reasoning/scripts/debug")
    end
    download("/robot/reasoning/scripts/debug/01.lua", "self")
end


if check_in_args(args, "--debug-branch") then branch = "debug" end

local is_all = check_in_args(args, "all") or check_in_args(args, "--all") or check_in_args(args, "-a")
if is_all or check_in_args(args, "shared") then shared() end

if args[1] == "robot" then
    if is_all or check_in_args(args, "top"  )    then    robot_top_level()          end
    if is_all or check_in_args(args, "eval" )    then    robot_eval()               end
    if is_all or check_in_args(args, "nav"  )    then    robot_navigation()         end
    if is_all or check_in_args(args, "bldp" )    then    robot_build_primitives()   end
    if is_all or check_in_args(args, "mbld" )    then    robot_meta_build()         end
    if is_all or check_in_args(args, "reas" )    then    robot_reasoning()          end

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
