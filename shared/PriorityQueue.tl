local interface Prioritizable
    priority: integer
end

local interface PriorityQueue<T is Prioritizable>
    inner: {T} 
end

local record module end
function module.new<T is Prioritizable>(): PriorityQueue<T>
    local new: PriorityQueue<T> = { inner = {} }
    return new
end

function module.find<T is Prioritizable, Q>(queue: PriorityQueue<T>, func: function(T, Q): boolean, other: Q): T | nil
    for _, t in ipairs(queue.inner) do
        if func(t, other) then return t end
    end
    return nil
end

function module.remove<T is Prioritizable>(queue: PriorityQueue<T>, index?: integer): T | nil
    if index is nil then return table.remove(queue.inner) end -- removes last element
    return table.remove(queue.inner, index)
end

function module.peek<T is Prioritizable>(queue: PriorityQueue<T>, index?: integer): T | nil
    if index is nil then return queue.inner[#queue.inner] end -- removes last element
    return queue.inner[index]
end

-- prio_insert modified for "named" priorities
function module.insert<T is Prioritizable>(queue: PriorityQueue<T>, to_add: T)
    local inner = queue.inner
    -- case inner is empty
    if #inner == 0 then
        table.insert(inner, to_add)
        return
    end

    local prio = to_add.priority
    if prio == -1 then
        table.insert(inner, to_add)
        return
    end

    -- prob fine to break since -1 is always added towards the end and we linear search
    for index = 1, #inner, 1 do
        local value = inner[index].priority
        if (value == -1) or (prio <= value) then
            table.insert(inner, index, to_add)
            return
        end
    end

    -- in case this prio we want to insert is bigger than everything
    table.insert(inner, to_add)
end

function module.size<T is Prioritizable>(queue: PriorityQueue<T>): integer
    return #queue.inner
end

--[[function module.iter<T is Prioritizable>(queue: PriorityQueue<T>): function(): function({T}, integer), {T}, integer
    return function(): function({T}, integer), {T}, integer return ipairs(queue.inner) end
end--]]

return {module, PriorityQueue, Prioritizable}
