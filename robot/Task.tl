require("deep_copy")
local tbl = require("PriorityQueue")
local pqueue, PriorityQueue, Prioritizable = table.unpack(tbl)

local record task_helper end
global interface TaskState end

local interface BlockName
    known_names: {string} 
    name: string
    is_valid: function(string): boolean
end

-- Should read {Task} instead of {any}
local await_queue: PriorityQueue<any>
function task_helper.next_task<S is TaskState>(): TaskHandle<S>

end

local interface Task<S is TaskState> is Prioritizable
    yield_block: BlockName | nil

    state: S
    coroutine: thread -- basically a funcpointer
end

global interface TaskHandle<S>
    task: Task<S> -- reference to a task in await_queue or other such long-lived and active value
end

global interface TaskPrototype<S is TaskState>
    priority: integer
    state: S
    func: function(S): S
end

function task_helper.new_prototype<S is TaskState>(priority: integer, func: function(S): S): TaskPrototype<S>
    local new: TaskPrototype<S> = {
        priority = priority,
        func = func
    }
    return new
end

function task_helper.instantiate<S is TaskState>(prototype: TaskPrototype<S>): boolean
    local new: Task<S> = {
        priority = prototype.priority,
        yield_block = nil,

        state = CLONE(prototype.state) as S,
        coroutine = coroutine.create(prototype.func)
    }
    pqueue.insert(await_queue as PriorityQueue<Task<S>>, new)

    return true
end


return task_helper
