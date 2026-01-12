local text = require("text")
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
    parent = nil,
    obj = nil,
    fail_text = nil,

    __f_pass = nil,
    __f_fail = nil,

    obj_state = "undecided"
}
function TrackObj:new(parent, obj, __f_pass, __f_fail)
    local new = COPY(self)
    new.parent = parent
    new.obj = obj
    new.__f_pass = __f_pass
    new.__f_fail = __f_fail
    return new
end

function TrackObj:fromPartialTable(parent, partial_table)
    local new = COPY(self)

    if partial_table.obj == nil then error("Invalid partial table, must at least have a .obj field") end
    for key, value in pairs(partial_table) do
        if new[key] == nil then new[key] = value end
    end

    new.parent = parent
    return new
end

function TrackObj:checkSelf()
    local robot_rep = self.parent.interface.robot_rep

    if self.__f_pass ~= nil then
        if self.__f_pass(robot_rep, self.obj) then self.obj_state = "pass" end
    end
    if self.__f_fail ~= nil then
        local fail_value = self.__f_fail(robot_rep, self.obj)

        if fail_value ~= 0 then
            self.obj_state = "fail"
            if type(self.fail_text) == "function" then
                self.fail_text(robot_rep, self.obj, fail_value)
            else print(self.fail_text) end
        end
    end

    return self.obj_state
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
    command_list = nil,
    interface = nil,
    world = nil,

    tracked_objects = {}, -- flat
    _f_pass = nil,
    _f_fail = nil,
}
function Test:new(interface, world, __f_pass, __f_fail, command_list)
    local new = COPY(self)
    new.world = world

    new.__f_pass = __f_pass
    new.__f_fail = __f_fail
    new.interface = interface
    new.command_list = command_list

    return new
end
function Test:empty(interface)
    local new = COPY(self)
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
    local track_obj = TrackObj:fromPartialTable(self, track_tbl)
    self.tracked_objects[track_name] = track_obj
    
    return track_obj
end

function Test:doStep(__f_robo_main)
    local command_string = table.remove(self.command_list, 1)
    local command_table = nil
    if command_string ~= nil then
        command_table = text.tokenize(command_string)
        table.insert(command_table, 1, -1) -- insert priority number
    end

    __f_robo_main(command_table)
    for _, obj in ipairs(self.tracked_objects) do
        obj:checkSelf()
    end
end

function Test:initWorld()
    self.world:init()
end

-- Singleton
local testing_interface = {
    tests = {},
    registered_objects = {}, -- hierarchical
}

function testing_interface:addTest(world, __f_pass, __f_fail, command_list)
    local test = Test:new(self, world, __f_pass, __f_fail, command_list)
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
    if node == nil then node = tree end

    if node[obj_name] ~= nil then error("Attempted to register same name twice") end
    node[obj_name] = obj
end

function testing_interface:runTests()
    error("TODO")
end

return testing_interface
