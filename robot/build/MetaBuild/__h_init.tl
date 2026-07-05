require("build.MetaBuild.MetaSchematic")
require("nav_module.chunk_coord")
require("build.MetaBuild.DoorInfo")

global interface BuildState is TaskState end
global interface BuildTask is Task end

global interface Build
    name: string
    chunk: ChunkCoord
    quad: integer

    offset: Pos3D
    doors: {DoorInfo}
    special_blocks: {SpecialSchematicChunk}
    build_task: BuildTask | nil
end
