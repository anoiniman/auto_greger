global type ChunkCoord = {integer, integer}
local record helper end
function helper.cmp_ccoords(a: ChunkCoord, b: ChunkCoord): boolean
    return a[1] == b[1] and a[2] == b[2]
end

return helper
