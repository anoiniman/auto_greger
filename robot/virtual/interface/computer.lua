local computer = {}

function computer.address()
    return "virtual_address"
end

local assumed_memory = 2048
function computer.freeMemory()
    local count = collectgarbage("count")
    local kilo = count / 1024
    return kilo
end

function computer.uptime()
    return os.time()
end


return computer
