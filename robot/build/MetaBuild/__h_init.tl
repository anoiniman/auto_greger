require("build.MetaBuild.SchematicInterface")
local enum BuildOption
    "top_to_bottom"
end

global interface Build
    name: string
    options: {BuildOption} | nil
    what_chunk: Pos2D

    build_task: BuildTask | nil
    doors: {Door}
    special_blocks: {SpecialSchematicChunk}

    primitive: BuildPrimitive
    sinterface: SchematicInteface
end
