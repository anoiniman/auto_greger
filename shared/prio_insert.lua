local module = {}
-- prio_insert modified for "named" priorities
function module.named_insert(tbl, to_add)
    -- case tbl is empty
    if #tbl == 0 then
        table.insert(tbl, to_add)
        return
    end

    local prio = to_add["priority"]
    if prio == -1 then
        table.insert(tbl, to_add)
        return
    end

    -- prob fine to break since -1 is always added towards the end and we linear search
    for index = 1, #tbl, 1 do
        local value = tbl[i]["priority"]
        if (value == -1) or (prio <= value) then
            table.insert(tbl, index, to_add)
            return
        end
    end

    -- in case this prio we want to insert is bigger than everything
    table.insert(tbl, to_add)
end

return module
