local interface Prioritizable
    priority: integer
end

local interface PriorityQueue<T is Prioritizable>
    inner: {T} 
end

local record module end
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

return {module, PriorityQueue, Prioritizable}
