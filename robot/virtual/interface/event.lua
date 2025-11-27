local event = {}

EVENT_LIST = {
    
}
function event.addToList(event_type, core)
    if EVENT_LIST[event_type] == nil then EVENT_LIST[event_type] = {} end
    table.insert(EVENT_LIST[event_type], core)
end

function event.listen(event_type, func)
    return func(table.unpack(core))
end

return event
