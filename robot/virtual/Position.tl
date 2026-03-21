require("overloads")
local tbl = require("fake_pointer")
local FakePointer, fake_pointer = tbl[1], tbl[2]

local record Position
    arr: {FakePointer<integer>}

    x: FakePointer<integer>
    z: FakePointer<integer>
    y: FakePointer<integer>
end

function Position:new(x: integer, z: integer, y: integer)
    self.arr = {
        fake_pointer.new(x),
        fake_pointer.new(z),
        fake_pointer.new(y)
    }
    self.x = self.arr[1]
    self.z = self.arr[2]
    self.y = self.arr[3]
end

function Position:unpack(): integer, integer, integer
    return self.x(), self.z(), self.y()
end

return Position
