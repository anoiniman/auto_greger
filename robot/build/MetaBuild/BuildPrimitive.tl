require("Position")
require("deep_copy")
require("build.MetaBuild.DoorInfo")
require("build.MetaBuild.__h_Symbol")
require("build.MetaBuild.__h_ConstructBuildTask")

local task_helper = require("Task")

global enum BuildOption
    "top_to_bottom"
end

global interface BuildState is TaskState end
global interface BuildTask is Task end

local interface BaseFormat is {{string}} default: {string} end
local type SubSegment = {string, Pos2D}
local type SegmentArray = {integer : {SubSegment}}

global interface BaseBuildPrimitive
    name: string
    dictionary: {string : TransSymbol}
    options: {BuildOption} | nil

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

function rotate_and_translate(primitive: BuildPrimitive, quad_num: integer, chunk_height: integer): boolean
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
    local old_origin_block = COPY(primitive.origin_block, ipairs)
    local result = rotate_and_translate(primitive, quad, chunk_height)
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

    local result = module.translate_special(build, quad, chunk_height, old_origin_block)
    if not result then return false end

    return true
end

return module
