global interface CoordinateType
    type X = integer
    type Z = integer
    type Y = integer
end
local type C = CoordinateType

global type Pos3D = {C.X, C.Z, C.Y}
global type Pos2D = {C.X, C.Z}
