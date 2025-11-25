require("deep_copy")
require("universal_compare")
local comms = require("comms")

local module = {}

local NONE = {} -- Will give us an unique pointer
local FakePointer = {
    inner_value = NONE,
    mut = false,
}

function module.new(obj)
    local new = CLONE(FakePointer)
    if obj ~= nil then new.inner_value = obj end
    return new
end
function module.mut(obj)
    local new = module.new(obj)
    new.mut = true
    return new
end

function module.lock(f_pointer)
    f_pointer.mut = false
end

function module.get_value(f_pointer)
    return f_pointer.inner_value
end

function module.replace(f_pointer, new_inner)
    if not f_pointer.mut then
        error(comms.robot_send("fatal", "Attempted to mutate immutable pointer"))
    end
    if new_inner == nil then new_inner = NONE end

    local old = f_pointer.inner_value
    f_pointer.inner_value = new_inner
    return old
end

function module.is_nil(f_pointer)
    return not S_CMP(f_pointer.inner_value, NONE)
end

function module.cmp(f_pointer, obj)
    return S_CMP(f_pointer.inner_value, obj)
end

local metatable = {
    __call = function(this, ...)
        return this.inner_value
    end
}
setmetatable(FakePointer, metatable)


return module
