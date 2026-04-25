local task_helper = require("Task")
require("Position")

local record module end

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

function module.new_construct_task(
    what_chunk: Pos3D,
    what_quad: integer,
    c_options: {ConstructionOption}
): Task
    local gen_obj: ConstructBuildGenerator = {
        what_chunk = what_chunk,
        what_quad = what_chunk
        c_options = c_options,

        state_generator = state_generator,
        task_prototype = prototype,
    }
    local prototype = task_helper.new_prototype(priority, c_main_func)
    return task_helper.new_task(prototype, state_generator, -1)
end

return module
