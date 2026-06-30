require("build.MetaBuild.MetaSchematic")
require("nav_module.chunk_coord")
require("build.MetaBuild.DoorInfo")
require("build.MetaBuild.BuildPrimitive")
local enum BuildOption
    "top_to_bottom"
end

global interface Build<T is BuildTask>
    name: string
    options: {BuildOption} | nil
    what_chunk: ChunkCoord
    what_quad: integer

    build_task: T | nil
    doors: {DoorInfo}
    special_blocks: {SpecialSchematicChunk}

    primitive: BuildPrimitive | nil
    -- sinterface: SchematicInteface
end
