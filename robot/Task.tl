require("deep_copy")
local comms = require("comms")
local a_tbl = require("PriorityQueue")
local pqueue, PriorityQueue, Prioritizable = table.unpack(a_tbl)
local simple_hash = require("simple_hash")

local record task_helper end
global interface TaskState end

local type BlockType = string | integer
global type TaskBlockType = BlockType
local interface BlockName
    known_names: {BlockType} 
    name: BlockType
end

local function good_name(tbl: {BlockType}, name: BlockType): boolean
    for _, k_name in ipairs(tbl) do
        if k_name == name then return true end
    end
    return false
end
function task_helper.block_name_is_valid(bn: BlockName): boolean
    return good_name(bn.known_names, bn.name)
end


global interface Task is Prioritizable
    name: string
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
    func: function(S, BlockType, ?{string : any}): string | nil

    uuid: integer
    name: string
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
    name: string,
    func: function(S, BlockType, ?{string : any}): string | nil
): TaskPrototype<S>
    local new: TaskPrototype<S> = {
        name = name,
        priority = priority,
        func = func,
    }
    new.uuid = simple_hash(tostring(os.clock()) .. tostring(new))
    return new
end

function task_helper.new_task<S is TaskState, T is StateGenerator<S>>(
    base_obj: T,
    quantity: integer,
    init_blockname?: BlockName
): Task
    local prototype = base_obj.task_prototype
    local state: S = base_obj:state_generator(quantity)
    return {
        name = prototype.name,
        priority = prototype.priority,
        prototype_uuid = prototype.uuid,
        yield_block = init_blockname,

        state = state,
        coroutine = coroutine.create(prototype.func)
    }
end

function task_helper.instantiate<S is TaskState, T is StateGenerator<S>>(
    base_obj: T,
    quantity: integer,
    init_blockname?: BlockName
): boolean
    local prototype = base_obj.task_prototype
    local func = function(a: Task, x: TaskPrototype<S>): boolean return a.prototype_uuid == x.uuid end
    if pqueue.find(await_queue as PriorityQueue<Task>, func, prototype) then return false end

    pqueue.insert(await_queue, task_helper.new_task(base_obj, quantity, init_blockname))
    return true
end

local function set_block_name(task: Task, new_name: BlockType)
    if type(new_name) == "string" or type(new_name) == "number" then 
        local block = task.yield_block
        if block is BlockName then
            block.name = new_name as string
        else
            comms.robot_send("fatal", string.format(
                    "(ID = %d | name = %s)\n Attempted to set block_name: %s",
                    task.prototype_uuid, task.name, tostring(new_name)
            ))
        end
    end
end

function task_helper.call(task: Task)
    local _: boolean
    local new_name: any
    _, new_name = coroutine.resume(task.coroutine, task.state, task.yield_block)
    if new_name ~= nil and (type(new_name) == "string" or type(new_name) == "number") then
        set_block_name(task, new_name as BlockType)
    end
end

function task_helper.call_with(task: Task, block: BlockType, arg_: {string : any})
    local _: boolean
    local new_name: any
    _, new_name = coroutine.resume(task.coroutine, task.state, block, arg_)
    if new_name ~= nil and (type(new_name) == "string" or type(new_name) == "number") then
        set_block_name(task, new_name as BlockType)
    end
end

function task_helper.yield(block_name: BlockType)
    coroutine.yield(block_name)
end

return task_helper
