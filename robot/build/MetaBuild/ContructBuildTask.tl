local task_helper = require("Task")
require("Position")

local record module end

global interface ConstructBuildTask is StateGenerator

end

local interface BuildInstruction
    rel_coords: Pos3D    
    build_ref: Build
    block_info: ItemDefinition

    extra_instruction: {ExtraInstruction} | nil
end

local interface ConstructBuildState is TaskState
    what_chunk: Pos3D
    what_quad: integer
    name: string
    step: integer

    top_down: boolean

    door_move_done: boolean
    bridge_mode: boolean

    rel_moved: boolean
    foundation_filled: boolean
    do_foundation_fill: boolean
end

function Module:require(name, what_chunk)
    if primitive_cache[name] ~= nil then
        self.primitive = primitive_cache[name]:new() -- very important
        self:initPrimitive()
        return true
    end
    if name == nil then name = "nil" end

    local path
    if V_ENV then path = "./build/" .. name .. ".lua"
    else path = "/home/robot/build/" .. name .. ".lua" end
    local build_table = nil -- luacheck: ignore

    local conditional
    if V_ENV then conditional = filesystem.exists(path)
    else conditional = filesystem.exists(path) and not filesystem.isDirectory(path) end

    if conditional then
        build_table = dofile(path)
    else
        print(comms.robot_send("error", "MetaBuild -- require -- No such build with name: \"" .. name .. "\""))
        return false
    end

    self.primitive = build_table:new() -- very important
    self.name = self.primitive.name
    self.extra_sauce = self.primitive.extra_sauce -- effective change of ownership
    self.post_build_s_init = self.primitive.state_init
    self.post_build_hooks = self.primitive.hooks

    self.what_chunk = what_chunk

    if self.post_build_state == nil then self.post_build_state = {} end

    -- THIS WAS REMOVED IN ORDER TO PERSERVE RAM
    --primitive_cache[name] = build_table
    self:initPrimitive()
    return true
end





return module
