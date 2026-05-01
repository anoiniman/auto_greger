require("Position")
require("build.MetaBuild.__h_init")
require("inventory.__h_Item")

local enum ExtraInstruction

end

global interface ConstructBuildInstruction
    rel_coords: Pos3D    
    block_info: ItemDefinition

    extra_instruction: {ExtraInstruction} | nil
end

global enum ConstructionOption
    "top_to_bottom"

    "bridge_mode"
    "do_foundation_fill"
end

global interface ConstructBuildState is TaskState
    build_instruction: ConstructBuildInstruction

    interaction_id: integer
    build_ref: Build

    c_options: {ConstructionOption}

    rel_moved: boolean
    foundation_filled: boolean
    door_move_done: boolean
end

global interface ConstructBuildGenerator<S is ConstructBuildState> is StateGenerator<S>
    build_ref: Build
    c_options: {ConstructionOption}
end
