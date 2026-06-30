local comms = require("comms")

require("Task")
require("Position")
require("interactive")
require("inventory.__h_Item")
require("build.MetaBuild.__h_init")
require("build.MetaBuild.MetaSchematic")
local item_helper = require("inventory.__h_Item")

global enum TSymbolExtra
    "break_shovel"
end

global interface InnerTransSymbol
    item: ItemDefinition
    extra: {TSymbolExtra} | nil
end
-- Can be a table data type or just a raw string where string == item_label
global type TransSymbol = InnerTransSymbol | string


global interface ConstructBuildInstruction
    rel_coords: Pos3D    
    block_definition: ItemDefinition

    extra_instruction: {TSymbolExtra} | nil
end

global enum ConstructionOption
    "top_to_bottom"

    "bridge_mode"
    "do_foundation_fill"
end

global interface ConstructBuildState is TaskState, InteractiveIDStore
    build_instruction: ConstructBuildInstruction

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

local record module end
function module.check_option(cbs: ConstructBuildState, option: ConstructionOption): boolean
    for _, opt in ipairs(cbs.c_options) do
        if opt == option then return true end
    end
    return false
end

function module.new_instruction(rel_coords: Pos3D, trans_symbol: TransSymbol): ConstructBuildInstruction
    if trans_symbol is InnerTransSymbol then
        return {
            rel_coords = rel_coords,
            block_definition = trans_symbol.item,

            extra_instruction = trans_symbol.extra
        }
    elseif trans_symbol is string then
        return {
            rel_coords = rel_coords,
            block_definition = item_helper.new_item_definition(trans_symbol, nil),

            extra_instruction = nil
        }
    else
        error(comms.robot_send("fatal", "Unexpected"))
    end
end


return module
