local task_helper = require("Task")
require("Position")

local record module end

global interface DoBuildTask is StateGenerator

end

local interface BuildInstruction
    rel_coords: Pos3D    
    build_ref: Build
    block_info: ItemDefinition

    extra_instruction: {ExtraInstruction} | nil
end

local interface BuildState is TaskState
    what_chunk: Pos3D
    what_quad: integer
    name: string
    step: integer

    door_move_done: boolean
    bridge_mode: boolean

    rel_moved: boolean
    foundation_filled: boolean
    do_foundation_fill: boolean
end

return module
