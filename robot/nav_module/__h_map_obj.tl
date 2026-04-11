global type ChunkCoord = {integer, integer}
local record helper end
function helper.cmp_ccoords(a: ChunkCoord, b: ChunkCoord): boolean
    return a[1] == b[1] and a[2] == b[2]
end

-- (10/04/26) Now with the rewrite (rewrite mentioned) underway, I'm just gonna flatten this to save memory,
-- we'll need lots and lots of chunks so its simply simpler to do this right right away, sure you have caching shit
-- into the hard-drive of the OC robot, but y'know

-- This design will be a pain in the ass to lazy initialise and we'll have to be very careful about
-- life times, it'll be difficult to structure that's for sure


-- CHUNK:
--  x: integer
--  z: integer
--  tags: nil | {Tag} (?)
--  parent_area: nil | Area
--  height_override: nil | integer (deprecated for sure with update of how buildings will be instantiated)
--  meta_quads: {MetaQuad}
--  roads_cleared: boolean (deprecated?) --> if it still exists it'll just be another tag, but rather, maybe
                                         -- we should have a "roads" array that holds Type Road objects
-- //////

-- There will probably be some sort of contract about this uh?
-- Are x and z even necessary? Depends if they are "written into" the structure of the array or not
global interface ChunkHandle
    x: integer
    z: integer
    tags: {string} | nil
    parent_area: Area | nil
    meta_quads:  {MetaQuad}
end


return helper
