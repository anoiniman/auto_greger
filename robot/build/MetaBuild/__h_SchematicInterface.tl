require("build.MetaBuild.__h_Symbol")
require("build.MetaBuild.MetaSchematic")
require("Position")
global type SIBuildStack = Pos3D
local type BuildStack = SIBuildStack

global interface SchematicInterface
    schematic: MetaSchematic
    dictionary: {string : TransSymbol}
    origin_block: Pos3D
    special_blocks: {SpecialSchematicChunk}

    build_stack: BuildStack
end
