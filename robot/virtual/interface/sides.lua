--[[
    Bottom (bottom), Number: 0
    Top (top), Number: 1
    Back (back), Number: 2
    Front (front), Number: 3
    Right (right), Number: 4
    Left (left), Number: 5
--]]
--[[
    Bottom: down, negy
    Top: up, posy
    Back: north, negz
    Front: south, posz, forward
    Right: west, negx
    Left: east, posx
--]]

local sides = {
    bottom = 0,
    top = 1,
    back = 2,
    front = 3,
    right = 4,
    left = 5,

    down = 0,
    up = 1,
    north = 2,
    south = 3,
    west = 4,
    left = 5,

    negy = 0,
    posy = 1,
    negz = 2,
    posz = 3,
    negx = 4,
    posx = 5,


    forward = 3,

    [0] = 0,
    [1] = 1,
    [2] = 2,
    [3] = 3,
    [4] = 4,
    [5] = 5,
}

return sides
