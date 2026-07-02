global enum BaseMoveResult
    "impossible move"
    "not enough energy"
    "entity"
    "solid"
    "replaceable"
    "liquid"
    "passable"
    "air"
end

local type Side = string | integer
local record robot
    name: function(): string
    detect: function(): boolean, string
    select: function(integer): integer

    inventorySize: function(): integer
    count: function(integer): integer
    space: function(integer): integer
    transferTo: function(integer, integer): boolean, string | nil
    compareTo: function(integer): boolean

    compare: function(): boolean
    compareUp: function(): boolean
    compareDown: function(): boolean

    drop: function(integer): boolean
    dropUp: function(): boolean
    dropDown: function(): boolean

    suck: function(integer): boolean
    suckUp: function(): boolean
    suckDown: function(): boolean

    place: function(Side, boolean): boolean, string | nil
    placeDown: function(Side, boolean): boolean, string | nil
    placeUp: function(Side, boolean): boolean, string | nil

    durability: function(): integer | nil, string | integer | nil, integer | nil

    swing: function(Side, boolean): boolean, string | nil
    swingUp: function(Side, boolean): boolean, string | nil
    swingDown: function(Side, boolean): boolean, string | nil

    use: function(Side, boolean, number): boolean, string | nil
    useUp: function(Side, boolean, number): boolean, string | nil
    useDown: function(Side, boolean, number): boolean, string | nil

    forward: function(): boolean, BaseMoveResult | nil
    back: function(): boolean, BaseMoveResult | nil
    up: function(): boolean, BaseMoveResult | nil
    down: function(): boolean, BaseMoveResult | nil

    turnLeft: function(): boolean
    turnRight: function(): boolean
    turnAround: function(): boolean
end


return robot
