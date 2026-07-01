require("nav_module.Area")
require("nav_module.chunk_coord")
require("nav_module.__h_MetaQuad")
global enum ChunkTag

end

global interface Chunk
    tags: {ChunkTag} | nil
    parent_area: Area | nil
    meta_quads:  {MetaQuad} | nil
end

global interface FakeMap
    chunk_set_parent: function(ChunkCoord, NamedArea, ?integer): boolean
    chunk_exists: function(ChunkCoord): Chunk
    add_quad: function(ChunkCoord, integer, string): boolean
    get_build: function(ChunkCoord, integer): Build
end
