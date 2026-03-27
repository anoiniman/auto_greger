local record task_helper end
global type TaskState = {any : any}

local interface BlockName
    known_names: {string} 
    name: string
    is_valid: function(string): boolean
end

local await_queue: {Task} = {}
local interface Task
    priority: integer
    yield_block: BlockName | nil

    state: TaskState
    coroutine: thread -- basically a funcpointer
end

global interface TaskHandle
    task: Task -- reference to a task in await_queue or other such long-lived and active value
end

global interface TaskPrototype
    priority: integer
    func: function(TaskState): TaskState
end

function task_helper.new_prototype(priority: integer, func: function(TaskState): TaskState): TaskPrototype
    local new: TaskPrototype = {
        priority = priority,
        func = func
    }
    return new
end

function task_helper.instantiate(prototype: TaskPrototype): TaskHandle
    local new: Task = {
        priority = prototype.priority,
        yield_block = nil,

        coroutine = coroutine.create(prototype.func)
    }
    local handle: TaskHandle = {
        task = new
    }

    return handle
end


return task_helper
