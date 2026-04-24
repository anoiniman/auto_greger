--local math = require("math")
--local serialize = require("serialization")
local filesystem = require("filesystem")

local comms = require("comms")
local deep_copy = require("deep_copy")

local nav = require("nav_module.nav_obj")

local general_functions = require("build.general_functions")
local SchematicInterface = require("build.MetaBuild.SchematicInterface")
local VirtualInventory = require("inventory.VirtualInventory")


local primitive_cache = {}  -- as you might have noticed this value exists outside the MetaTable(s)
                            -- so it exists as a singleton all "inheritors" of the MetaTable have the same
                            -- reference for "build_cache"

local enum BuildOption
    "top_to_bottom"
end

local record module end
global interface Build
    name: string
    options: {BuildOption} | nil
    what_chunk: Pos2D

    build_task: BuildTask | nil
    doors: {Door}
    special_blocks: {SpecialSchematicChunk}

    primitive: BuildPrimitive
    sinterface: SchematicInteface
end

function module.contains_option(build: Build, check: BuildOption): boolean
    if build.options == nil then return false end
    for _, value in ipairs(build.options as {BuildOption}) do
        if value == check then return true end
    end
    return false
end

local type C = CoordinateType
--[[function module.new(): Build
    return {
        name = "NONE",
        option = nil,
        what_chunk = nil as Pos2D,

        build_task = nil,
        doors = nil as {Door}
        special_blocks = nil as {SpecialSchematicChunk},
    }
end--]]

function module.require(name: string, what_chunk: Pos2D): Build
    local new: Build = {} as Build

    if primitive_cache[name] ~= nil then
        new.primitive = primitive_cache[name]:new() -- very important
        module.initPrimitive(build)
        return true
    end
    if name == nil then name = "nil" end

    local path
    if V_ENV then path = "./build/" .. name .. ".lua"
    else path = "/home/robot/build/" .. name .. ".lua" end
    local build_table = nil -- luacheck: ignore

    local conditional
    if V_ENV then conditional = filesystem.exists(path)
    else conditional = filesystem.exists(path) and not filesystem.isDirectory(path) end

    if conditional then
        build_table = dofile(path)
    else
        print(comms.robot_send("error", "MetaBuild -- require -- No such build with name: \"" .. name .. "\""))
        return false
    end

    new.primitive = new_table:new() -- very important
    new.name = new.primitive.name
    new.extra_sauce = new.primitive.extra_sauce -- effective change of ownership
    new.new_task = new.primitive.new_task

    new.what_chunk = what_chunk

    -- THIS WAS REMOVED IN ORDER TO PERSERVE RAM
    --primitive_cache[name] = build_table
    module.init_primitive(new)
    return true
end


function module.get_special_coords(build: Build, what_symbol: SpecialSymbol, index: integer): Pos3D
    local coords, _ = general_functions.count_occurence_of_symbol(what_symbol, index, build.special_blocks)
    return {coords[1] as C.X, coords[2] as C.Z, coords[3] as C.Y} -- this is effectifly a deep_copy
end

function module.get_dist_to_special(build: Build, what_symbol: SpecialSymbol, index: integer): integer
    local coords, _ = general_functions.count_occurence_of_symbol(what_symbol, index, build.special_blocks)
    local x, z, y = coords[1], coords[2], coords[3]
    local cabs_x = build.what_chunk[1] * 16
    local cabs_z = build.what_chunk[2] * 16

    x = x + cabs_x
    z = z + cabs_z
    local cur_abs = nav.get_abs()
    local dist_x = math.abs(x - cur_abs[1])
    local dist_z = math.abs(z - cur_abs[2])
    local dist_y = math.abs(y - nav.get_height())

    local man_dist = dist_x + dist_z + dist_y
    return man_dist
end

function module.init_primitive(build: Build)
    module.primitive.parent = build
end

function module.rotate_and_translate_primitive(build: Build, quad_num: integer, logical_chunk_height: integer): boolean
    local base_table = build.primitive.base_table
    local segments = build.primitive.segments
    local origin_block = build.primitive.origin_block

    origin_block[3] = origin_block[3] + logical_chunk_height -- y

    if quad_num == 1 then
        general_functions.mirror_x(base_table, segments)

        origin_block[1] = origin_block[1] + 8 -- x
        origin_block[2] = origin_block[2] + 1 -- z
    elseif quad_num == 2 then
        origin_block[1] = origin_block[1] + 1
        origin_block[2] = origin_block[2] + 1
    elseif quad_num == 3 then
        general_functions.mirror_z(base_table, segments)

        origin_block[1] = origin_block[1] + 1
        origin_block[2] = origin_block[2] + 8
    elseif quad_num == 4 then
        general_functions.mirror_x(base_table, segments)
        general_functions.mirror_z(base_table, segments)

        origin_block[1] = origin_block[1] + 8 -- x
        origin_block[2] = origin_block[2] + 8
    else
        print(comms.robot_send("error", "MetaBuild rotatePrimitive impossible quad_num: " .. quad_num))
        return false
    end
    return true
end

-- no need to rotate since they are already pre-rotated from before
function module.translate_special(quad_num: integer, logical_chunk_height: integer, primitive_offset: Pos3D): boolean
    local special_table = self.special_blocks

    --[[print(string.format("Name is: %s", self.name))
    local a_special = special_table[1]
    local str = string.format("Special was: [%s] (%s, %s) h:%s", a_special[1], a_special[2], a_special[3], a_special[4])
    print(str)
    io.read()--]]

    local function case_one(special)
        special[2] = special[2] + 8 -- x
        special[3] = special[3] + 1 -- z
    end
    local function case_two(special)
        special[2] = special[2] + 1 -- x
        special[3] = special[3] + 1 -- z
    end
    local function case_three(special)
        special[2] = special[2] + 1 -- x
        special[3] = special[3] + 8 -- z
    end
    local function case_four(special)
        special[2] = special[2] + 8 -- x
        special[3] = special[3] + 8 -- z
    end

    local case_function
    if quad_num == 1 then
        case_function = case_one
    elseif quad_num == 2 then
        case_function = case_two
    elseif quad_num == 3 then
        case_function = case_three
    elseif quad_num == 4 then
        case_function = case_four
    else
        print(comms.robot_send("error", "MetaBuild rotateSpecial impossible quad_num: " .. quad_num))
        return false
    end


    for _, special in ipairs(special_table) do
        special[4] = special[4] + logical_chunk_height - 1 -- adds height to le thing (- 1 because idk you just need to)
        case_function(special)

        special[2] = special[2] + primitive_offset[1]
        special[3] = special[3] + primitive_offset[2]
        special[4] = special[4] + primitive_offset[3]
    end

    --[[local special = special_table[1]
    local str = string.format("Special now is: [%s] (%s, %s) h:%s", special[1], special[2], special[3], special[4])
    print(str)
    print()
    io.read()--]]

    return true
end

--[[function Module:translatePrimitive(quad_num)

end--]]

function module.dump_primitive(build: Build)
    build.primitive = nil
end

function module.setup_build(build: Build, what_quad: integer, chunk_height: integer): boolean
    local old_origin_block = COPY(self.primitive.origin_block, ipairs)
    local result = module.rotate_and_translate_primitive(build, what_quad, chunk_height)
    if not result then return false end

    local base_table = build.primitive.base_table

    if build.sinterface == nil then
        build.sinterface = sinterface_helper.new()
    end
    -- its ok to retain this after dumping the primitive because of GC, I think
    sinterface_helper.init(build.sinterface, build.primitive.dictionary, build.primitive.origin_block)
    build.special_blocks = sinterface_helper.get_special_blocks(build.sinterface)

    if module.check_human_map(build, base_table, build.primitive.name) ~= 0 then -- sanity check
        return false
    end

    -- Build the sparse array

    -- ATTENTION: VVVVVVVVVVVVVVVVVVVVVVVVV
    -- if returning the length of the MetaSchematic tables is faulty, we'll need to count the height of buildings here
    -- thanks to the magic of lua bogus arguments are ok!
    if module.primitive.iter == nil then
        for index, table_obj in ipairs(base_table) do
            sinterface_helper.parse_string_arr(build.sinterface, table_obj, index)
            --max_index = max_index + 1
        end
    else
        for index, table_obj in build.primitive:iter(base_table) do -- it is expected that table object does not include meta-data
            sinterface_helper.parse_string_arr(build.sinterface, table_obj, index)
            -- print(comms.robot_send("debug", "MetaBuild:setupBuild() we looped once m8"))
            --max_index = max_index + 1
        end
    end

    -- TODO move this to its own little function when appropriate
    if module.contains_option(build, "top_to_bottom") then
        print("top_bottomed")
        build.sinterface.build_stack.logical_y = #build.sinterface.schematic
    end

    build.is_nil = false

    local result = module.translate_special(build, what_quad, chunk_height, old_origin_block)
    if not result then return false end

    return true
end


-- build state == 1 chunk wide state
function module.finalize_build(build: Build, doors: {Door})
    build.doors = doors -- lame cludge for now, fix later TODO

    for index, func in ipairs(self.post_build_s_init) do
        self.post_build_state[index] = func(self)
    end

    build.sinterface = nil -- :)
    
    if V_ENV then
        local test_interface = require("virtual.tests")
        local num_of_builds = tostring(test_interface:getNumOfChildren({"build"}, build.name))

        -- TODO: uh oh, this needs to be handled differently now
        if true then
            print("Warning -- this is outdated, this code needs to be updated" .. debug.traceback())
            return
        end
        for index, state in ipairs(build.post_build_state) do
            local path = {"build", self.name, num_of_builds, "pb_state"}
            test_interface:registerObject(state, tostring(index), path)
        end
    end
    -- print(comms.robot_send("debug", "finalizedBuild"))
end

function module.get_inventories(build: Build): {ExternalInventory} | nil
    if build.build_task == nil then return nil end
    return bt_helper.get_attached_inventories(build.build_task)
end

function module.run_build_check(build: Build, quantity_goal: integer): CheckResult
    -- self:useBuilding(nil, "only_check", nil, quantity_goal, nil, nil)
    return bt_helper.run_check(build.build_task)
end

local max_depth: integer = 3
local function recursive_append(tbl: {any}, buffer: {string}, depth: integer)
    if depth >= max_depth then return end
    depth = depth + 1
    table.insert(buffer, "{\n")
    for key, value in pairs(tbl) do
        table.insert(buffer, string.format("%s = ", tostring(key)))

        if type(value) == "table" then recursive_append(value as {any}, buffer, depth); goto skip_comma
        elseif type(value) == "function" then table.insert(buffer, "function")
        elseif type(value) == "boolean" or type(value) == "string" or type(value) == "number" then
            table.insert(buffer, tostring(value))
        else table.insert(buffer, "other") end

        table.insert(buffer, ", ")
        ::skip_comma::
    end
    table.insert(buffer, "}\n")
end


function module.create_and_return_ledger(build: Build): VirtualInventory
    -- We could try to pre-add-up every block by looping through the sinterface multiple times, and only
    -- then increment the ledger entries, or we could just loop once and increment the ledger entries
    -- 1-by-1, I don't know what solution is best, so I'll just use the easier one
    local tmp_ledger = vinv_helper.new(64)

    local result, status, instruction
    while true do -- TODO got to think about this
        error("TODO")
        result, status, instruction = self:doBuild()
        if not result then error(comms.robot_send("fatal", "Failed to doBuild in createLedger, name is -- " .. self.name)) end
        if status == "done" then break end

        local block_name = instruction.block_info.name
        local block_lable = instruction.block_info.lable

        tmp_ledger:addOrCreate(block_lable, block_name, 1)
    end

    return tmp_ledger
end

function module.check_human_map(base_table: {{string}}, name: string): integer
    local watch_dog = false
    for _, base in pairs(base_table) do
        if base[1] == "def" then -- I wish there was a re-usable way to write this logic, but no pass by ref, no luck
            if watch_dog == false then
                watch_dog = true
            else
                goto continue
            end
        end

        local map = base[2]
        if #map > 7 then
            comms.robot_send("error", "In human map -- Build: \"" .. name .. "\" -- Too Many Lines!")
            return -1
        end

        for index, line in ipairs(map) do
            if string.len(line) > 7 then
                comms.robot_send("error", "In human map -- Build: \"" .. name .. "\" -- Line: \"" .. tostring(index) .. "\" -- Line is way too big!")
                return index
            end
        end

        ::continue::
    end

    return 0
end

return module
