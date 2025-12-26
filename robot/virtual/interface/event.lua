local event = {}

local EVENT_TYPE = {}
local EVENT_QUEUE = {}

function event.addToList(event_type, core)
    if EVENT_LIST[event_type] ~= nil then return end
    EVENT_LIST[event_type] = {}
    EVENT_QUEUE[event_type] = {}

    -- table.insert(EVENT_LIST[event_type], core)
    for index, value in ipairs(core) do
        EVENT_TYPE[event_type][index] = value
    end
end

function event.listen(event_type, func)
    local core = EVENT_LIST[event_type]
    if core == nil then return end
    
    local message = table.remove(EVENT_QUEUE[event_type], 1)
    if message == nil then return end

    return func(table.unpack(core), table.unpack(message))
end

return event
