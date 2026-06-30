require("Position")
require("build.MetaBuild.DoorInfo")
require("build.MetaBuild.__h_Symbol")

local task_helper = require("Task")

local interface BuildState is TaskState end
global interface BuildTask<S is BuildState> is TaskPrototype<S> end

local interface BaseFormat is {{string}} default: {string} end
local type SubSegment = {string, Pos2D}
local type SegmentArray = {integer : {SubSegment}}

global interface BaseBuildPrimitive
    name: string
    dictionary: {string : TransSymbol}

    human_readable: {{string}} | nil
    origin_block: Pos3D

    base_table: BaseFormat | nil
    segments: {integer : SegmentArray}
    doors: {DoorInfo}
    iter: function(self): (function(): integer | nil, {string} | nil)
end

global interface BuildPrimitive<S is BuildState> is StateGenerator<S>
    base: BaseBuildPrimitive
end

local record module end

function module.new_build_primtive<S is BuildState>(
    base_prim: BaseBuildPrimitive,
    gen: (function(self, integer): S),
    use_function: (function(S, BlockType): string | nil),
): BuildPrimitive<S>
    local prototype = task_helper.new_prototype(-1, use_function)
    return {
        base = base_prim,
        state_generator = s,
        
        task_prototype = prototype
    }
end


return module
