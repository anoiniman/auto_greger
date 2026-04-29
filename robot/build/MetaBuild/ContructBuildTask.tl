local task_helper = require("Task")
require("Position")
require("build.MetaBuild.__h_init")
require("inventory.__h_Item")

local record module end

local enum ExtraInstruction

end

local interface BuildInstruction
    rel_coords: Pos3D    
    build_ref: Build
    block_info: ItemDefinition

    extra_instruction: {ExtraInstruction} | nil
end

global enum ConstructionOption
    "top_to_bottom"

    "bridge_mode"
    "do_foundation_fill"
end

local interface ConstructBuildState is TaskState
    build_instruction: BuildInstruction

    what_chunk: Pos3D
    what_quad: integer

    c_options: {ConstructionOption}

    rel_moved: boolean
    foundation_filled: boolean
    door_move_done: boolean
end

local interface ConstructBuildGenerator<S is ConstructBuildState> is StateGenerator<S>
    what_chunk: Pos3D
    what_quad: integer
    c_options: {ConstructionOption}
end

local function state_generator(gen: ConstructBuildGenerator<ConstructBuildState>, _: integer): ConstructBuildState
    return {
        build_instruction = nil as BuildInstruction,

        what_chunk = gen.what_chunk,
        what_quad = gen.what_quad,
        c_options = gen.c_options,

        rel_moved = false,
        foundation_filled = false,
        door_move_done = false,
    }
end

-- forward declaration
local c_main_function: function(ConstructBuildState): ConstructBuildState, string

function module.new_construct_task(
    what_chunk: Pos3D,
    what_quad: integer,
    priority: integer,
    c_options: {ConstructionOption}
): Task
    local prototype = task_helper.new_prototype(priority, c_main_func)
    local gen_obj: ConstructBuildGenerator<ConstructBuildState> = {
        what_chunk = what_chunk,
        what_quad = what_quad,
        c_options = c_options,

        state_generator = state_generator,
        task_prototype = prototype,
    }
    return task_helper.new_task(prototype, state_generator, -1)
end

return module
