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

    obj_state = "undecided",

    obj_name = nil,
    obj_path = nil,
    late_binding = false,
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

    if partial_table.obj == nil and partial_table.obj_name == nil then 
        error("Invalid partial table, must at least have a .obj field or .obj_name .obj_path .late_binding fields")
    end
    for key, value in pairs(partial_table) do
        if new[key] == nil then new[key] = value end
    end

    new.parent = parent
    return new
end

function TrackObj:checkSelf()
    if self.late_binding then
        local obj = self.parent:getObj(self.obj_name, self.obj_path)
        if obj ~= nil then
            self.obj = obj
            self.late_binding = false
        else
            return self.obj_state
        end
    end

    local robot_rep = self.parent.world.robot_rep

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

    -- print("self.obj_state: " .. self.obj_state)
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

    step_count = 0,

    tracked_objects = {}, -- flat
    __f_pass = nil,
    __f_fail = nil,
    __f_init = nil,
}
function Test:new(interface, world, __f_pass, __f_fail, command_list, __f_init)
    local new = COPY(self)
    new.world = world

    new.__f_pass = __f_pass
    new.__f_fail = __f_fail
    new.__f_init = __f_init
    new.interface = interface
    new.command_list = command_list

    return new
end
function Test:empty(interface)
    local new = COPY(self)
    new.interface = interface
    return new
end

function Test:getObj(obj_name, path)
    path = path or {}
    local node = self.interface.registered_objects
    for _, name in ipairs(path) do node = node[name] end

    local obj = node[obj_name]
    return obj
end

-- function Test:trackObj(obj_name, path, track_name, target, __f_pass, __f_fail)
function Test:trackObj(track_tbl, track_name, obj_name, path)
    path = path or {}
    local obj = self:getObj(obj_name, path)
    if obj == nil then -- Error
        error(string.format(
            "Required object of name: %s || path: %s <| doesn't exist",
            obj_name,
            table.concat(path, "/")
        ))
    end

    track_name = track_name or obj_name

    track_tbl.obj = obj
    local track_obj = TrackObj:fromPartialTable(self, track_tbl)
    self.tracked_objects[track_name] = track_obj
    
    return track_obj
end

function Test:lateBindObj(track_tbl, track_name, obj_name, path)
    track_name = track_name or obj_name
    track_tbl.obj_name = obj_name
    track_tbl.obj_path = path

    local track_obj = TrackObj:fromPartialTable(self, track_tbl)
    track_obj.late_binding = true
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
    for _, obj in pairs(self.tracked_objects) do
        obj:checkSelf()
    end
    --[[for _, v in pairs(self.world.robot_rep.position) do
        print(v)
    end--]]

    if self.__f_pass ~= nil and self.__f_pass(self) then print("__f_pass") end
    if self.__f_fail ~= nil and self.__f_fail(self) == 1 then print("__f_fail") end

    self.world:simulate()
    self.step_count = self.step_count + 1
end

function Test:initWorld()
    self.__f_init()
    self.world:init()
end

-- Singleton
local testing_interface = {
    tests = {},
    known_names = {},
    registered_objects = {}, -- hierarchical
}

function testing_interface:addTest(world, __f_pass, __f_fail, command_list, __f_init)
    local test = Test:new(self, world, __f_pass, __f_fail, command_list, __f_init)
    table.insert(self.tests, test)
    return test -- returns handle to the test
end

-- path is a table {"home", "user"} obj is a table -> "/home/user/obj_name"
function testing_interface:registerObject(obj, obj_name, path)
    if obj == nil then error("Attempted to register nil object") end
    if path == nil then path = {} end

    local tree = self.registered_objects
    local node = tree
    for _, name in ipairs(path) do
        if node[name] == nil then 
            node[name] = {}
            table.insert(self.known_names, name)
        end
        node = node[name]
    end

    if node[obj_name] ~= nil then error("Attempted to register same name twice") end
    node[obj_name] = obj
    table.insert(self.known_names, obj_name)

    self:printTree()
end

local function num_of_keys(tbl)
    local count = 0
    for _, _ in pairs(tbl) do count = count + 1 end
    return count
end

function testing_interface:getNumOfChildren(path, obj_name)
    local tree = self.registered_objects
    local node = tree
    for _, name in ipairs(path) do
        if node[name] == nil then return 0 end
        node = node[name]
    end
    
    if node[obj_name] == nil then return 0 end
    return num_of_keys(node[obj_name]) 
end

function testing_interface:nameKnown(tbl)
    for _, name in ipairs(self.known_names) do
        for key, _ in pairs(tbl) do
            if name == key then return true end
        end
    end
    return false
end

function testing_interface:printTree()
    local indent = 0
    local buffer = {"T_INTERFACE = "}
    local function recursive_buffer(tbl)
        indent = indent + 4
        table.insert(buffer, "{\n")
        for key, value in pairs(tbl) do
            -- if not self:nameKnown(key) then break end
            for i = 1, indent, 1 do table.insert(buffer, " ") end
            if not self:nameKnown(value) then 
                table.insert(buffer, string.format("%s,\n", key))
            else 
                table.insert(buffer, string.format("%s = ", key))
                recursive_buffer(value)
            end
        end

        indent = indent - 4
        for i = 1, indent, 1 do table.insert(buffer, " ") end
        table.insert(buffer, "},\n")
    end
    local tree = self.registered_objects
    recursive_buffer(tree)
    print(table.concat(buffer))
end

function testing_interface:runTests()
    error("TODO")
end

return testing_interface
