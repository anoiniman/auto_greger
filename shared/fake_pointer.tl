require("deep_copy")
require("universal_compare")
local comms = require("comms")

local record module end

local NONE = {} -- Will give us an unique reference
local interface FakePointer<T>
    inner_value: T
    mut: boolean
    metamethod __call: function(any): any
end

local record EvenFakerPointer inner_value: any end
local mt_tbl = {
    __call = function(this: any): any
        return (this as EvenFakerPointer).inner_value
    end
}

function module.new<T>(obj: T): FakePointer<T>
    local new: FakePointer<T> = {
        inner_value = NONE as T,
        mut = false,
    }
    setmetatable(new, mt_tbl)

    if obj ~= nil then new.inner_value = obj end
    return new
end
function module.mut<T>(obj: T): FakePointer<T>
    local new = module.new(obj)
    new.mut = true
    return new
end

function module.lock<T>(f_pointer: FakePointer<T>)
    f_pointer.mut = false
end

function module.get_value<T>(f_pointer: FakePointer<T>): T
    return f_pointer.inner_value
end

function module.replace<T>(f_pointer: FakePointer<T>, new_inner: T): T
    if not f_pointer.mut then error(comms.robot_send("fatal", "Attempted to mutate immutable pointer")) end
    if new_inner == nil then new_inner = NONE as T end

    local old = f_pointer.inner_value
    f_pointer.inner_value = new_inner
    return old
end

function module.is_nil<T>(f_pointer: FakePointer<T>): boolean
    return not S_CMP(f_pointer.inner_value, NONE)
end

function module.cmp<T>(f_pointer: FakePointer<T>, obj: T): boolean
    return S_CMP(f_pointer.inner_value, obj)
end


return module
