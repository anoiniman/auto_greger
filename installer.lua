local os = require("os")
local filesystem = require("filesystem")
local io = require("io")

local args = {...}
local counter = 0
local branch = "master"


local function simple_hash(path)
    local file = io.open(path, "r")
    local str = file:read("*a")
    file:close()

    local hash_value = -3750763034362895579  -- FNV offset basis
    local fnv_prime = 1099511628211     -- FNV prime
    for i = 1, #str do
        local char = str:sub(i, i)
        hash_value = hash_value ~ string.byte(char) -- XOR with the byte (silly LLM was using bit.xor)
        hash_value = hash_value * fnv_prime         -- Multiply by the prime
    end
    return hash_value
end

local function download(origin, where)
    local link = "https://raw.githubusercontent.com/anoiniman/auto_greger/refs/heads/" .. branch .. origin

    local tmp_path = "/tmp/" .. counter .. ".lua"
    os.execute("wget -f " .. link .. " " .. tmp_path .. " > /dump.txt")

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

    local are_equal = false
    if (args[1] ~= "-f" and args[2] ~= "-f") then
        local original_checksum = simple_hash(where)
        local new_checksum = simple_hash(tmp_path)
        are_equal = (original_checksum == new_checksum and filesystem.size(where) == filesystem.size(tmp_path))
    end

    if are_equal then
        print("File: \"" .. where .. "\" doesn't need update")
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
    download("/shared/search_i_table.lua", "/usr/lib/search_i_table.lua")
    download("/shared/simple_hash.lua", "/usr/lib/simple_hash.lua")
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
    download("/robot/overloads.lua", "self")
end

local function robot_eval()
    if not filesystem.isDirectory("/home/robot/eval") then
       filesystem.makeDirectory("/home/robot/eval")
    end

    download("/robot/eval/eval_main.lua", "self")

    download("/robot/eval/build.lua", "self")
    download("/robot/eval/debug.lua", "self")
    download("/robot/eval/navigate.lua", "self")
    download("/robot/eval/interactive.lua", "self")
    download("/robot/eval/tasks.lua", "self")

    download("/robot/eval/AutoBuildMetaInfo.lua", "self")
end

local function robot_navigation()
    if not filesystem.isDirectory("/home/robot/nav_module") then
       filesystem.makeDirectory("/home/robot/nav_module")
    end

    --download("/robot/nav_module/base_sweep.lua", "self")
    download("/robot/nav_module/chunk_move.lua", "self")
    download("/robot/nav_module/door_move.lua", "self")

    download("/robot/nav_module/map_obj.lua", "self")
    download("/robot/nav_module/MetaQuad.lua", "self")

    download("/robot/nav_module/nav_obj.lua", "self")
    download("/robot/nav_module/rel_move.lua", "self")
    download("/robot/nav_module/simple_elevator.lua", "self")
    download("/robot/nav_module/nav_to_building.lua", "self")

    if not filesystem.isDirectory("/home/robot/nav_module/nav_interface") then
       filesystem.makeDirectory("/home/robot/nav_module/nav_interface")
    end
    download("/robot/nav_module/nav_interface/init.lua", "self")
    download("/robot/nav_module/nav_interface/strategies.lua", "self")

end

local function robot_build_primitives()
    if not filesystem.isDirectory("/home/robot/build") then
       filesystem.makeDirectory("/home/robot/build")
    end
    download("/robot/build/coke_quad.lua", "self")
    download("/robot/build/hole_home.lua", "self")
    download("/robot/build/oak_tree_farm.lua", "self")
    download("/robot/build/spruce_tree_farm.lua", "self")
    download("/robot/build/sp_storeroom.lua", "self")

    if not filesystem.isDirectory("/home/robot/build/bd_storeroom") then
       filesystem.makeDirectory("/home/robot/build/bd_storeroom")
    end
    download("/robot/build/bd_storeroom/storeroom_north.lua", "self")
    download("/robot/build/bd_storeroom/storeroom_south.lua", "self")
end

local function robot_meta_build()
    if not filesystem.isDirectory("/home/robot/build/MetaBuild") then
       filesystem.makeDirectory("/home/robot/build/MetaBuild")
    end

    download("/robot/build/general_functions.lua", "self")
    download("/robot/build/generic_hooks.lua", "self")

    download("/robot/build/MetaBuild/init.lua", "self")
    download("/robot/build/MetaBuild/MetaDoorInfo.lua", "self")
    download("/robot/build/MetaBuild/MetaSchematic.lua", "self")
    download("/robot/build/MetaBuild/SchematicInterface.lua", "self")
    download("/robot/build/MetaBuild/BuildInstruction.lua", "self")
end

-- one day option to download different script folders etc, but not today
local function robot_reasoning()
    if not filesystem.isDirectory("/home/robot/reasoning") then
       filesystem.makeDirectory("/home/robot/reasoning")
    end

    download("/robot/reasoning/reasoning_obj.lua", "self")

    if not filesystem.isDirectory("/home/robot/reasoning/MetaRecipe") then
       filesystem.makeDirectory("/home/robot/reasoning/MetaRecipe")
    end

    download("/robot/reasoning/MetaRecipe/init.lua", "self")
    download("/robot/reasoning/MetaRecipe/MetaDependency.lua", "self")

    if not filesystem.isDirectory("/home/robot/reasoning/MetaScript") then
       filesystem.makeDirectory("/home/robot/reasoning/MetaScript")
    end
    download("/robot/reasoning/MetaScript/init.lua", "self")

    if not filesystem.isDirectory("/home/robot/reasoning/MetaScript/Constraint") then
       filesystem.makeDirectory("/home/robot/reasoning/MetaScript/Constraint")
    end

    download("/robot/reasoning/MetaScript/Constraint/init.lua", "self")
    download("/robot/reasoning/MetaScript/Constraint/BuildingConstraint.lua", "self")
    download("/robot/reasoning/MetaScript/Constraint/ItemConstraint.lua", "self")

    if not filesystem.isDirectory("/home/robot/reasoning/recipes") then
       filesystem.makeDirectory("/home/robot/reasoning/recipes")
    end
    download("/robot/reasoning/recipes/sweep_gathering_general.lua", "self")

    if not filesystem.isDirectory("/home/robot/reasoning/recipes/stone_age") then
       filesystem.makeDirectory("/home/robot/reasoning/recipes/stone_age")
    end
    if not filesystem.isDirectory("/home/robot/reasoning/recipes/debug") then
       filesystem.makeDirectory("/home/robot/reasoning/recipes/debug")
    end
    download("/robot/reasoning/recipes/debug/01.lua", "self")

    --download("/robot/reasoning/recipes/stone_age/essential01.lua", "self")
    download("/robot/reasoning/recipes/stone_age/gathering01.lua", "self")
    download("/robot/reasoning/recipes/stone_age/gathering_tree.lua", "self")

    if not filesystem.isDirectory("/home/robot/reasoning/scripts/debug") then
       filesystem.makeDirectory("/home/robot/reasoning/scripts/debug")
    end
    download("/robot/reasoning/scripts/debug/01.lua", "self")
    --download("/robot/reasoning/scripts/debug/02.lua", "self")
    --download("/robot/reasoning/scripts/debug/03.lua", "self")
    --download("/robot/reasoning/scripts/debug/04.lua", "self")
    download("/robot/reasoning/scripts/debug/05.lua", "self")
end

local function robot_inventory()
    if not filesystem.isDirectory("/home/robot/inventory") then
       filesystem.makeDirectory("/home/robot/inventory")
    end

    download("/robot/inventory/external_inv_obj.lua", "self")
    download("/robot/inventory/inv_obj.lua", "self")
    download("/robot/inventory/item_buckets.lua", "self")
    download("/robot/inventory/special_cases.lua", "self")

    download("/robot/inventory/VirtualInventory.lua", "self")
    download("/robot/inventory/MetaExternalInventory.lua", "self")
    download("/robot/inventory/MetaLedger.lua", "self")
    download("/robot/inventory/SpecialDefinition.lua", "self")
end

local function robot_complex_algorithms()
    if not filesystem.isDirectory("/home/robot/complex_algorithms") then
       filesystem.makeDirectory("/home/robot/complex_algorithms")
    end

    download("/robot/complex_algorithms/nav_build.lua", "self")
    download("/robot/complex_algorithms/road_build.lua", "self")

    download("/robot/complex_algorithms/quarry.lua", "self")
    download("/robot/complex_algorithms/fill_rect.lua", "self")
    download("/robot/complex_algorithms/foundation_fill.lua", "self")
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
    if is_all or check_in_args(args, "inv"  )    then    robot_inventory()          end
    if is_all or check_in_args(args, "algo" )    then    robot_complex_algorithms() end

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
