-- building index is relative to distance to building, where <1 is the nearest and #size> is the furthest
-- this is like this because I cannot be arsed to do better, and most additions/removings will not happen
-- through this interface, but rather directly through direct building interaction and building
-- agnostic direct inventory interaction, no point messing around with the data structuring just to
-- help out this very minor debug-ish function
require("Position")
require("deep_copy")
local comms = require("comms")

require("build.MetaBuild.__h_SchematicInterface")
local item_helper = require("inventory.__h_Item")
local meta_schematic = require("build.MetaBuild.MetaSchematic")
local cbuild_task_helper = require("build.MetaBuild.__h_ConstructBuildTask")

local type BuildStack = SIBuildStack
local type C = CoordinateType

local record module
    instruction_construction: function(MSChunk, Pos3D, {string : TransSymbol}): Instruction | nil
end

local function build_stack_new(): BuildStack
    return {1 as C.X, 1 as C.Z, 1 as C.Y}
end

function module.new(origin: Pos3D, dict: {string : TransSymbol}): SchematicInterface
    local new = {
        schematic = meta_schematic.new(),
        dictionary = dict,
        origin_block = origin,
        special_blocks = {},

        build_stack = build_stack_new(),
    }
    return new
end

function module.get_special_blocks(sinterface: SchematicInterface): {SpecialSchematicChunk}
    return sinterface.special_blocks
end

function module.parse_string_arr(sinterface: SchematicInterface, string_array: {string}, square_index: integer)
    local special_blocks = meta_schematic.parse_string_arr(sinterface.schematic, string_array, square_index)
    if special_blocks ~= nil then
        for _, special in ipairs(special_blocks) do
            table.insert(sinterface.special_blocks, special)
        end
    end

    if #sinterface.schematic == 0 then print(comms.robot_send("error", "we ballsd up good :(")) end
end

function module.advance_y(sinterface: SchematicInterface, top_to_bottom: boolean): boolean
   local b_stack = sinterface.build_stack
    if top_to_bottom then
        return b_stack[3] > 1
    end
    return b_stack[3] <= #sinterface.schematic
end

function module.force_advance_head(sinterface: SchematicInterface, top_to_bottom: boolean): boolean
    local b_stack = sinterface.build_stack

    if b_stack[2] <= 7 then -- try and read every line
        b_stack[1] = 1
        b_stack[2] = b_stack[2] + 1
    elseif module.advance_y(sinterface, top_to_bottom) then -- only then move-up in height
        b_stack[1] = 1
        b_stack[2] = 1

        if not top_to_bottom then
            b_stack[3] = b_stack[3] + 1
        else
            b_stack[3] = b_stack[3] - 1
        end
    else -- we can only assume there is nothing left to process, let's mark oursinterface as built
        return true
    end

    return false -- aka continue
end

local type Instruction = ConstructBuildInstruction

-- Maybe this doing builds thing needs to be redesigned. And by maybe I mean: it does forcefully
-- chunk.dist && chunk.symbol
function module.do_build(state: ConstructBuildState, sinterface: SchematicInterface): ConstructBuildState
    local top_to_bottom = cbuild_task_helper.check_option(state, "top_to_bottom")
    local b_stack = sinterface.build_stack

    local function get_instruction(chunk: MSChunk): Instruction
        b_stack[1] = b_stack[1] + 1 -- prepare the advance to next column element

        local rel = {0, 0, 0}
        rel[3] = sinterface.origin_block[3] + (b_stack[3] - 1) -- (-1) compensates for array access being on 1
        rel[2] = sinterface.origin_block[2] + (b_stack[1] - 1)
        rel[1] = sinterface.origin_block[1] + chunk.x

        return module.instruction_construction(chunk, rel, sinterface.dictionary)
    end

    --[[if DO_DEBUG_PRINT then
        local print_a = serialize.serialize(b_stack, true)
        print(comms.robot_send("info", "b_stack is: \n" .. print_a))
        io.read()
    end--]]

    --[[local print_schematic = sierialize.serialize(sinterface.schematic, true)
    print(comms.robot_send("info", "sinterface.schematic is: \n" .. print_a))--]]

    --local chunk = sinterface.schematic.lookUp(b_stack.logical_y, b_stack.logical_z, b_stack.logical_x)

    local chunk: MSChunk = nil
    local line: {MSChunk} = nil
    local square: {{MSChunk}} = nil

    square = sinterface.schematic[b_stack[3]]
    if square == nil then goto very_funny end

    line = square[b_stack[2]]
    if line == nil then goto very_funny end

    chunk = line[b_stack[1]]

    ::very_funny::
    if chunk == nil then
        if module.force_advance_head(sinterface, top_to_bottom) then
            return state
        end
        return module.do_build(state, sinterface)
    end

    state.build_instruction = get_instruction(chunk)
    return state
end

function module.instruction_construction(
    chunk: MSChunk,
    rel: Pos3D,
    dictionary: {string : TransSymbol}
): Instruction | nil
    local translated_symbol: TransSymbol = dictionary[chunk.symbol]
    if translated_symbol == nil then
        local symbol = chunk.symbol
        if symbol is SpecialSymbol then
            translated_symbol = {item = item_helper.get_air_def()}
        else
            print(comms.robot_send("error", "symbol: \"" .. chunk.symbol .. "\" does not possess a valid flag in the dictionary"))
            return nil
        end
    end

    local coords = COPY(rel, ipairs)
    return cbuild_task_helper.new_instruction(coords, translated_symbol)
end

return module
