require("Position")
require("build.MetaBuild.DoorInfo")
require("build.MetaBuild.__h_Symbol")

local task_helper = require("Task")

global enum BuildOption
    "top_to_bottom"
end

global interface BuildState is TaskState end
global interface BuildTask is Task end

local interface BaseFormat is {{string}} default: {string} end
local type SubSegment = {string, Pos2D}
local type SegmentArray = {integer : {SubSegment}}

global interface BaseBuildPrimitive
    name: string
    dictionary: {string : TransSymbol}
    options: {BuildOption} | nil

    human_readable: {{string}} | nil
    origin_block: Pos3D

    base_table: BaseFormat | nil
    segments: {integer : SegmentArray}
    doors: {DoorInfo}
    iter: function(self): (function(): integer | nil, {string} | nil)
end

global interface BuildPrimitive is StateGenerator<BuildState>
    base: BaseBuildPrimitive
end

local record module end

function module.new_build_primtive(
    base_prim: BaseBuildPrimitive,
    gen: function(integer): BuildState,
    use_function: function(BuildState, TaskBlockType): string | nil
): BuildPrimitive
    local prototype = task_helper.new_prototype(-1, use_function)
    return {
        base = base_prim,
        state_generator = gen,
        
        task_prototype = prototype
    }
end

return module
