require("Position")
global type SIBuildStack = Pos3D
local type C = CoordinateType

local function build_stack_new(): BuildStack
    return {1 as C.X, 1 as C.Z, 1 as C.Y}
end

global interface SchematicInterface
    schematic: MetaSchematic
    dictionary: {string : TransSymbol}
    origin_block: Pos3D
    special_blocks: {SpecialSchematicChunk}

    build_stack: BuildStack
end
