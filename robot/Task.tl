require("deep_copy")
local tbl = require("PriorityQueue")
local pqueue, PriorityQueue, Prioritizable = table.unpack(tbl)
local simple_hash = require("simple_hash")

local record task_helper end
global interface TaskState end

local interface BlockName
    known_names: {string} 
    name: string
    is_valid: function(string): boolean
end

global interface Task is Prioritizable
    prototype_uuid: integer
    yield_block: BlockName | nil

    state: TaskState
    coroutine: thread -- basically a funcpointer
end

global interface TaskHandle
    task: Task -- reference to a task in await_queue or other such long-lived and active value
end

global interface TaskPrototype<S is TaskState>
    priority: integer
    func: function(S): S, boolean

    uuid: integer
end

global interface StateGenerator<S is TaskState>
    state_generator: function(self, integer): S
    task_prototype: TaskPrototype<S>
end

local active_task: Task
local await_queue: PriorityQueue<Task> = pqueue.new()
function task_helper.next_task(): TaskHandle | nil
    local task: Task = pqueue.peek(await_queue, #await_queue.inner)
    if task is nil or task.priority <= active_task.priority then return nil end

    pqueue.insert(await_queue, active_task)
    active_task = task
    return {task = active_task}
end

function task_helper.new_prototype<S is TaskState>(
    priority: integer,
    func: function(S): S, boolean
): TaskPrototype<S>
    local new: TaskPrototype<S> = {
        priority = priority,
        func = func,
    }
    new.uuid = simple_hash(tostring(os.clock()) .. tostring(new))
    return new
end

function task_helper.instantiate<S is TaskState, T is StateGenerator<S>>(
    prototype: TaskPrototype<S>,
    base_obj: T,
    quantity: integer
): boolean
    local func = function(a: Task, x: TaskPrototype<S>): boolean return a.prototype_uuid == x.uuid end
    if pqueue.find(await_queue as PriorityQueue<Task>, func, prototype) then return false end

    local state: S = base_obj:state_generator(quantity)
    local new: Task = {
        priority = prototype.priority,
        prototype_uuid = prototype.uuid
        yield_block = nil,

        state = state,
        coroutine = coroutine.create(prototype.func)
    }
    pqueue.insert(await_queue, new)

    return true
end


return task_helper
