require("deep_copy")
require("overloads")
local tbl = require("fake_pointer")
local FakePointer, fake_pointer = tbl[1], tbl[2]

local type posTuple = {FakePointer<integer>, FakePointer<integer>, FakePointer<integer>}
local record Position
    arr: posTuple

    x: FakePointer<integer>
    z: FakePointer<integer>
    y: FakePointer<integer>

    metamethod __index: function(Position, integer): integer
end

local mt: metatable<Position>
mt = {
   __index = function(self: Position, k: integer): integer
        return self.arr[k]()
   end
}
setmetatable(Position, mt)

function Position:new(x: integer, z: integer, y: integer): Position
    local new = COPY(self) as Position
    new.arr = {
        fake_pointer.new(x),
        fake_pointer.new(z),
        fake_pointer.new(y),
    }
    new.x = new.arr[1]
    new.z = new.arr[2]
    new.y = new.arr[3]

    return new
end

function Position:unpack(): integer, integer, integer
    return self.x(), self.z(), self.y()
end

function Position:asIntArr(): {integer}
    return {self:unpack()}
end

return Position
