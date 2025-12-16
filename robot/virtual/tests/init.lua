local deep_copy = require("deep_copy")

--[[local function iSmaller (obj, target) return obj <  target end
local function iSequal  (obj, target) return obj <= target end
local function iBequal  (obj, target) return obj >= target end
local function iBigger  (obj, target) return obj >  target end

local function _equal   (obj, target) return obj == target end
local function _nequal  (obj, target) return obj ~= target end

local prefab_funcs = {
    ["iSmaller"] = iSmaller,
    ["iSequal"] = iSequal,
    ["iBequal"] = iBequal,
    ["iBigger"] = iBigger,

    ["_equal,"] = _equal,
    ["_nequal,"] = _nequal,

    [1] = iSmaller,
    [2] = iSequal,
    [3] = iBequal,
    [4] = iBigger,

    [5] = _equal,
    [6] = _nequal
}--]]


local TrackObj = {
    obj = nil,
    fail_text = nil,

    __f_pass = nil,
    __f_fail = nil,

    obj_state = "pass"
}
function TrackObj:new(obj, __f_pass, __f_fail)
    local new = COPY(self)
    new.obj = obj
    new.__f_pass = __f_pass
    new.__f_fail = __f_fail
    return new
end

function TrackObj:fromPartialTable(new_tbl)
    for key, value in pairs(self) do
        if new_tbl[key] == nil then new_tbl[key] = value end
    end
    if new_tbl.obj == nil then error("Invalid partial table, must at least have a .obj field") end
    return new_tbl
end

--[[function TrackObj:newKFT(key, func, table)
    if type(func) == "string" or type(func) == "number" then
        func = prefab_funcs[func]
        if func == nil then error(string.format("Bad KFT assingment: %s", tostring(func))) end
    end
    if type(func) ~= "function" then
        error(string.format("type(func) is not function: %s", tostring(func)))
    end
end--]]

local Test = {
    interface = nil,
    world = nil,

    tracked_objects = {}, -- flat
    _f_pass = nil,
    _f_fail = nil,
}
function Test:new(interface, world, __f_pass, __f_fail)
    local new = COPY(self)
    new.__f_pass = __f_pass
    new.__f_fail = __f_fail
    new.interface = interface

    return new
end

-- function Test:trackObj(obj_name, path, track_name, target, __f_pass, __f_fail)
function Test:trackObj(track_tbl, track_name, obj_name, path)
    local node = self.interface.registered_objects
    path = path or {}
    for _, name in ipairs(path) do node = node[name] end

    local obj = node[obj_name]
    if obj == nil then -- Error
        error(string.format(
            "Required object of name: %s || path: %s <| doesn't exist",
            obj_name,
            table.concat(path, "/")
        ))
    end

    if track_name == nil then track_name = obj_name end
    track_name = track_name or obj_name

    track_tbl.obj = obj
    local track_obj = TrackObj:fromPartialTable(track_tbl)
    self.tracked_objects[track_name] = track_obj
end

function Test:doStep()

end

-- Singleton
local testing_interface = {
    tests = {},
    registered_objects = {}, -- hierarchical
}

function testing_interface:addTest(world, __f_pass, __f_fail)
    local test = Test:new(self, world, __f_pass, __f_fail)
    table.insert(self.tests, test)
    return test -- returns handle to the test
end

-- path is a table {"home", "user"} obj is a table -> "/home/user/obj_name"
function testing_interface:registerObject(obj, obj_name, path)
    if obj == nil then error("Attempted to register nil object") end
    if path == nil then path = {} end

    local node = nil
    local tree = self.registered_objects
    for _, name in ipairs(path) do
        if tree[name] == nil then tree[name] = {} end
        node = tree[name]
    end

    if node[obj_name] ~= nil then error("Attempted to register same name twice") end
    node[obj_name] = obj
end

function testing_interface:runTests()
    error("TODO")
end

return testing_interface
