global interface CoordinateType
    type X = integer
    type Z = integer
    type Y = integer
end
local type C = CoordinateType

global type Pos3D = {C.X, C.Z, C.Y}
global type Pos2D = {C.X, C.Z}

local record helper end
function helper.add(a: {integer}, b: {integer})
    for i = 1, #a, 1 do
        local other: integer | nil = b[i]
        if other == nil then other = 0 end
        a[i] = other as integer
    end
end

return helper
