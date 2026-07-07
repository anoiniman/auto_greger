require("Position")
require("deep_copy")
require("build.MetaBuild.DoorInfo")
-- require("build.MetaBuild.__h_init")
require("build.MetaBuild.__h_Symbol")
require("build.MetaBuild.__h_ConstructBuildTask")

local filesystem = require("filesystem")

local comms = require("comms")
local task_helper = require("Task")
local general_functions = require("build.general_functions")
local sinterface_helper = require("build.MetaBuild.SchematicInterface")
local build_helper = require("build.MetaBuild")

global enum CBuildOption
    "top_to_bottom"
end

global interface BaseBuildPrimitive
    name: string
    dictionary: {string : TransSymbol}
    options: {CBuildOption} | nil

    human_readable: {{string}} | nil
    pos_offset: Pos3D

    base_table: BaseFormat
    segments: SegmentArray
    doors: {DoorInfo}
    iter: function(self): (function(): integer | nil, {string} | nil)
end

global interface BuildPrimitive is StateGenerator<BuildState>
    base: BaseBuildPrimitive
    c_task: Task
end

local record module end

function module.new_build_primtive(
    base_prim: BaseBuildPrimitive,
    gen: function(integer): BuildState,
    use_function: function(BuildState, TaskBlockType, ?{string : any}): string | nil
): BuildPrimitive
    local prototype = task_helper.new_prototype(-1, "BuildPrimitive", use_function)
    return {
        base = base_prim,
        state_generator = gen,
        
        task_prototype = prototype
    }
end


local function check_human_map(base_table: {{string}}, name: string): integer
    for _, base in ipairs(base_table) do
        if #base > 7 then
            comms.robot_send("error", "In human map -- Build: \"" .. name .. "\" -- Too Many Lines!")
            return -1
        end

        for index, line in ipairs(base) do
            if string.len(line) > 7 then
                comms.robot_send(
                    "error",
                    string.format("In human map -- Build: \"%s\" -- Line: \"%d\" -- Line is way too big!", name, index)
                )
                return index
            end
        end
    end

    return 0
end

local function rotate_and_translate(primitive: BaseBuildPrimitive, quad_num: integer, chunk_height: integer): boolean
    local base_table = primitive.base_table
    local segments = primitive.segments
    local pos_offset = primitive.pos_offset

    pos_offset[3] = pos_offset[3] + chunk_height -- y

    if quad_num == 1 then
        general_functions.mirror_x(base_table, segments)

        pos_offset[1] = pos_offset[1] + 8 -- x
        pos_offset[2] = pos_offset[2] + 1 -- z
    elseif quad_num == 2 then
        pos_offset[1] = pos_offset[1] + 1
        pos_offset[2] = pos_offset[2] + 1
    elseif quad_num == 3 then
        general_functions.mirror_z(base_table, segments)

        pos_offset[1] = pos_offset[1] + 1
        pos_offset[2] = pos_offset[2] + 8
    elseif quad_num == 4 then
        general_functions.mirror_x(base_table, segments)
        general_functions.mirror_z(base_table, segments)

        pos_offset[1] = pos_offset[1] + 8 -- x
        pos_offset[2] = pos_offset[2] + 8
    else
        print(comms.robot_send("error", "MetaBuild rotatePrimitive impossible quad_num: " .. quad_num))
        return false
    end
    return true
end

function module.init(primitive: BuildPrimitive, build: Build): boolean
    local old_pos_offset = COPY(primitive.base.pos_offset, ipairs)
    local result = rotate_and_translate(primitive.base, build.quad, build.offset[3])
    if not result then return false end

    local base_table = primitive.base.base_table
    if check_human_map(base_table, primitive.base.name) ~= 0 then return false end -- Sanity

    local sinterface = sinterface_helper.new(primitive.base.pos_offset, primitive.base.dictionary)
    build.special_blocks = sinterface_helper.get_special_blocks(sinterface)

    local update_state = { sinterface = sinterface }
    task_helper.call_with(primitive.c_task, "update", update_state as {string : any})

    -- ATTENTION: VVVVVVVVVVVVVVVVVVVVVVVVV
    -- if returning the length of the MetaSchematic tables is faulty, we'll need to count the height of ngs here
    -- thanks to the magic of lua bogus arguments are ok!
    if primitive.base.iter == nil then
        for index, table_obj in ipairs(base_table) do
            sinterface_helper.parse_string_arr(sinterface, table_obj, index)
            --max_index = max_index + 1
        end
    else
        for index, table_obj in primitive.base:iter() do
            sinterface_helper.parse_string_arr(sinterface, table_obj, index)
        end
    end

    result = build_helper.translate_special(build, build.quad, build.offset[3], old_pos_offset)
    if not result then return false end

    build.build_task = task_helper.new_task(primitive, -1) as BuildTask
    build.doors = primitive.base.doors
    return true
end

function module.require_build(build: Build): boolean
    local name: string = build.name
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
        return false
    end
    
    return module.init(primitive, build)
end


return module
