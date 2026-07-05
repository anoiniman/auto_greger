require("Position")
require("deep_copy")
require("build.MetaBuild.DoorInfo")
require("build.MetaBuild.__h_Symbol")
require("build.MetaBuild.__h_ConstructBuildTask")

local task_helper = require("Task")

global enum CBuildOption
    "top_to_bottom"
end

local interface BaseFormat is {{string}} default: {string} end
local type SubSegment = {string, Pos2D}
local type SegmentArray = {integer : {SubSegment}}

global interface BaseBuildPrimitive
    name: string
    dictionary: {string : TransSymbol}
    options: {CBuildOption} | nil

    human_readable: {{string}} | nil
    pos_offset: Pos3D

    base_table: BaseFormat | nil
    segments: {integer : SegmentArray}
    doors: {DoorInfo}
    iter: function(self): (function(): integer | nil, {string} | nil)
end

global interface BuildPrimitive is StateGenerator<BuildState>
    base: BaseBuildPrimitive
    c_task: ConstructBuildTask
end

local record module end

function module.new_build_primtive(
    base_prim: BaseBuildPrimitive,
    gen: function(integer): BuildState,
    use_function: function(BuildState, TaskBlockType): string | nil
): BuildPrimitive
    local prototype = task_helper.new_prototype(-1, use_function)
    return {
        base = base_prim,
        state_generator = gen,
        
        task_prototype = prototype
    }
end


local function check_human_map(base_table: {{string}}, name: string): integer
    for _, base in pairs(base_table) do
        local map = base[2]
        if #map > 7 then
            comms.robot_send("error", "In human map -- Build: \"" .. name .. "\" -- Too Many Lines!")
            return -1
        end

        for index, line in ipairs(map) do
            if string.len(line) > 7 then
                comms.robot_send(
                    "error",
                    string.format("In human map -- Build: \"%s\" -- Line: \"%d\" -- Line is way too big!", name, index)
                )
                return index
            end
        end

        ::continue::
    end

    return 0
end

local function rotate_and_translate(primitive: BaseBuildPrimitive, quad_num: integer, chunk_height: integer): boolean
    local base_table = primitive.base_table
    local segments = primitive.segments
    local origin_block = primitive.origin_block

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

function module.init(primitive: BuildPrimitive, quad: integer, chunk_height: integer): boolean
    local old_origin_block = COPY(primitive.base.origin_block, ipairs)
    local result = rotate_and_translate(primitive.base, quad, chunk_height)
    if not result then return false end

    local base_table = primitive.base.base_table

    primitive.c_task.sinterface = sinterface_helper.new()
    -- its ok to retain this after dumping the primitive because of GC, I think
    sinterface_helper.init(sinterface, primitive.dictionary, primitive.origin_block)
    special_blocks = sinterface_helper.get_special_blocks(sinterface)

    if check_human_map(base_table, primitive.name) ~= 0 then -- sanity check
        return false
    end

    -- the sparse array

    -- ATTENTION: VVVVVVVVVVVVVVVVVVVVVVVVV
    -- if returning the length of the MetaSchematic tables is faulty, we'll need to count the height of ngs here
    -- thanks to the magic of lua bogus arguments are ok!
    if module.primitive.iter == nil then
        for index, table_obj in ipairs(base_table) do
            sinterface_helper.parse_string_arr(sinterface, table_obj, index)
            --max_index = max_index + 1
        end
    else
        for index, table_obj in primitive:iter(base_table) do -- it is expected that table object does not include meta-data
            sinterface_helper.parse_string_arr(sinterface, table_obj, index)
            -- print(comms.robot_send("debug", "Metasetup) we looped once m8"))
            --max_index = max_index + 1
        end
    end

    -- TODO move this to its own little function when appropriate
    if module.contains_option( "top_to_bottom") then
        print("top_bottomed")
        sinterface.stack.logical_y = #sinterface.schematic
    end

    is_nil = false

    local result = module.translate_special( quad, chunk_height, old_origin_block)
    if not result then return false end

    return true
end

function module.require_build(name: string, chunk: ChunkCoord, quad: integer, chunk_height: integer): Build | nil
    local new: Build = {} as Build

    --[[if primitive_cache[name] ~= nil then
        new.primitive = primitive_cache[name]:new() -- very important
        module.initPrimitive(build)
        return true
    end--]]

    local path: string
    if V_ENV then path = "./build/" .. name .. ".lua"
    else path = "/home/robot/build/" .. name .. ".lua" end
    local primitive: BuildPrimitive = nil

    local conditional: boolean
    if V_ENV then conditional = filesystem.exists(path)
    else conditional = filesystem.exists(path) and not filesystem.isDirectory(path) end

    if conditional then
        primitive = dofile(path) as BuildPrimitive
    else
        print(comms.robot_send("error", "MetaBuild -- require -- No such build with name: \"" .. name .. "\""))
        return nil
    end
    
    module.init(primitive, quad, chunk_height)

    new.name = primitive.base.name
    new.build_task = task_helper.new_task(primitive, -1) as BuildTask

    new.chunk = chunk
    new.quad = quad
    new.doors = doors

    -- module.init_primitive(new)
    return new
end


return module
