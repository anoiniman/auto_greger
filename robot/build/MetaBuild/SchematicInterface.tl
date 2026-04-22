-- building index is relative to distance to building, where <1 is the nearest and #size> is the furthest
-- this is like this because I cannot be arsed to do better, and most additions/removings will not happen
-- through this interface, but rather directly through direct building interaction and building
-- agnostic direct inventory interaction, no point messing around with the data structuring just to
-- help out this very minor debug-ish function-- luacheck: ignore io
local serialize = require("serialization")
local io = require("io")

local comms = require("comms")
local deep_copy = require("deep_copy")

local meta_schematic = require("build.MetaBuild.MetaSchematic")
local BuildInstruction = require("build.MetaBuild.BuildInstruction")
require("Position")

local type BuildStack = Pos3D
local type C = CoordinateType

local function build_stack_new(): BuildStack
    return {1 as C.X, 1 as C.Z, 1 as C.Y}
end

local record Module end

local interface SchematicInterface
    schematic: MetaSchematic
    dictionary: {any} | nil
    origin_block: Pos3D
    special_blocks: {SpecialSchematicChunk}

    build_stack: BuildStack
end

function module.new(): SchematicInterface
    return {
        schematic = meta_schematic_new(),
        dictionary = nil, -- {}
        origin_block = {
            x = 0,
            z = 0,
            y = 0
        },
        special_blocks = {},

        build_stack = BuildStack:new()
    }
end

function module.init(sinterface: SchematicInterface, dict: {any}, origin: Pos3D)
    sinterface.origin_block = origin
    sinterface.dictionary = dict
end

function module.get_special_blocks(sinterface: SchematicInterface)
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

function module.advance_y(sinterface: SchematicInterface, top_down: boolean): boolean
   local b_stack = sinterface.build_stack
    if top_down then
        return b_stack[3] > 1
    end
    return b_stack[3] <= #sinterface.schematic
end

function module.force_advance_head(sinterface: SchematicInterface, top_down: boolean): boolean
    local b_stack = sinterface.build_stack

    if b_stack[2] <= 7 then -- try and read every line
        b_stack[1] = 1
        b_stack[2] = b_stack[2] + 1
    elseif module.advance_y(sinterface, top_down) then -- only then move-up in height
        b_stack[1] = 1
        b_stack[2] = 1

        if not top_down then
            b_stack[3] = b_stack[3] + 1
        else
            b_stack[3] = b_stack[3] - 1
        end
    else -- we can only assume there is nothing left to process, let's mark oursinterface as built
        return true
    end

    return false -- aka continue
end

-- Maybe this doing builds thing needs to be redesing. And by maybe I mean: it does forcefully
-- chunk.dist && chunk.symbol
function module.do_build(state: ConstructBuildState): ConstructBuildState
    local top_down = state.top_down
    local b_stack = sinterface.build_stack

    local function get_instruction(chunk: MSChunk): Instruction
        b_stack[1] = b_stack[1] + 1 -- prepare the advance to next column element

        local rel = {0, 0, 0}
        rel[3] = sinterface.origin_block[3] + (b_stack[3] - 1) -- (-1) compensates for array access being on 1
        rel[2] = sinterface.origin_block[2] + (b_stack[1] - 1)
        rel[1] = sinterface.origin_block[1] + chunk.x

        return module.instruction_construction(sinterface, chunk, rel)
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
        if module.force_advance_head(sinterface, top_down) then
            return true, "done", nil
        end
        return module.do_build(sinterface, top_down)
    end

    local instruction = get_instruction(chunk)
    return true, "continue", instruction
end

-- place for the side argument in place
-- orientation to have the robot change it's orientation before placing

local function interpret_element(element, index, do_error)
    if element == nil then
        print(comms.robot_send("error", "SI:interpret_element, element nil! Expected a table to have more than 1 element"))
        return nil
    end

    if element == "west" or element == "east" or element == "north" or element == "south" or element == "up" or element == "down" then
        if index == 1 then return "place", element
        elseif index == 2 then return "orient", element
        else error(comms.robot_send("fatal", "interpret_element: as of yet unsupported!")) end

    else -- non instruction element
        if do_error then
            print(comms.robot_send("error", "SI:IC, instruction: \"" .. element .. "\" not recognized"))
        end
        return nil
    end
end

function SchematicInterface:InstructionConstruction(chunk, rel)
    local translated_symbol = sinterface.dictionary[chunk.symbol]
    if translated_symbol == nil then
        if is_special_symbol(chunk.symbol) then
            translated_symbol = {"air", "shovel"}
            goto skip01
        end

        print(comms.robot_send("error", "symbol: \"" .. chunk.symbol .. "\" does not possess a valid flag in the dictionary"))
        return false
    end
    ::skip01::

    --print(comms.robot_send("debug", "coords: " .. rel[1] .. ", " .. rel[2] .. ", " .. rel[3]))
    if type(translated_symbol) ~= "table" then
        --print(comms.robot_send("debug", "symbol: " .. chunk.symbol .. " -- " .. translated_symbol))
    else -- if it IS a table
        translated_symbol = deep_copy.copy(translated_symbol, ipairs) -- Yes I should do this in place, no I don't care for now

        -- luacheck: push ignore serial
        local serial = serialize.serialize(translated_symbol, true)
        -- luacheck: pop
        --print(comms.robot_send("debug", "symbol: " .. chunk.symbol .. " -- " .. serial))
    end

    local coords = deep_copy.copy(rel, ipairs)

    if type(translated_symbol) ~= "table" then
        return BuildInstruction:newBasic(coords, translated_symbol)
    end

    local instruction
    local first = table.remove(translated_symbol, 1) -- should be lable
    local peek = interpret_element(translated_symbol[1], 1, false)
    if peek == nil then
        local second = table.remove(translated_symbol, 1)
        if first == "nil" then first = nil end
        instruction = BuildInstruction:newBasic(coords, first, second)
    else
        instruction = BuildInstruction:newBasic(coords, first, nil)
    end

    for index, element in ipairs(translated_symbol) do
        local i_str, arg = interpret_element(element, index, true)
        instruction:addExtra(i_str, arg)
    end

    if instruction == nil then
        error(comms.robot_send("fatal", "SI:InstructionConstruction, no instruction was created!"))
    end
    return instruction
end

return module
