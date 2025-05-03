local math = require("math")
local deep_copy = require("deep_copy")

-- coords are chunk_rel, but are attached to quad, they need to be able to rotate with quad, if quad is rotatable
-- their "default" definition inside the build-source files should be assuming quad 2
local MetaDoorInfo = {x = -1, z = -1, len = -1}
function MetaDoorInfo:zeroed()
    return deep_copy.copy(self, pairs)
end

function MetaDoorInfo:doorX(x, len)
    self.x = x
    self.len = len
end

function MetaDoorInfo:doorZ(z, len)
    self.z = z
    self.len = len
end

function MetaDoorInfo:mirror(x_axis, z_axis) -- arguments are bools, function returns nothing
    if x_axis then
        self.x = self.x 
        self.z = math.abs(16 - self.z)
    end
    if z_axis then
        self.x = math.abs(16 - self.x)
        self.z = self.z
    end
end

return MetaDoorInfo
