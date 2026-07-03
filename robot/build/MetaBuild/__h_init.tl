require("build.MetaBuild.MetaSchematic")
require("nav_module.chunk_coord")
require("build.MetaBuild.DoorInfo")
require("build.MetaBuild.BuildPrimitive")

global interface Build
    name: string
    options: {BuildOption} | nil
    chunk: ChunkCoord
    quad: integer

    build_task: BuildTask | nil
    doors: {DoorInfo}
    special_blocks: {SpecialSchematicChunk}
end
