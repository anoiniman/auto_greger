require("deep_copy")
local a_tbl = require("PriorityQueue")
local pqueue, PriorityQueue, Prioritizable = table.unpack(a_tbl)
local simple_hash = require("simple_hash")

local record task_helper end
global interface TaskState end

local interface BlockName
    known_names: {string} 
    name: string
end

local function good_name(tbl: {string}, name: string): boolean
    for _, k_name in ipairs(tbl) do
        if k_name == name then return true end
    end
    return false
end
function task_helper.block_name_is_valid(bn: BlockName): boolean
    return good_name(bn.known_names, bn.name)
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
    func: function(S): S, string

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
    func: function(S): S, string
): TaskPrototype<S>
    local new: TaskPrototype<S> = {
        priority = priority,
        func = func,
    }
    new.uuid = simple_hash(tostring(os.clock()) .. tostring(new))
    return new
end

function task_helper.new_task<S is TaskState, T is StateGenerator<S>>(
    prototype: TaskPrototype<S>,
    base_obj: T,
    quantity: integer
): Task
    local state: S = base_obj:state_generator(quantity)
    return {
        priority = prototype.priority,
        prototype_uuid = prototype.uuid,
        yield_block = nil,

        state = state,
        coroutine = coroutine.create(prototype.func)
    }
end


function task_helper.instantiate<S is TaskState, T is StateGenerator<S>>(
    prototype: TaskPrototype<S>,
    base_obj: T,
    quantity: integer
): boolean
    local func = function(a: Task, x: TaskPrototype<S>): boolean return a.prototype_uuid == x.uuid end
    if pqueue.find(await_queue as PriorityQueue<Task>, func, prototype) then return false end

    pqueue.insert(await_queue, task_helper.new_task(prototype, base_obj, quantity))
    return true
end

function task_helper.yield(block_name: string)
    coroutine.yield(block_name)
end

return task_helper
