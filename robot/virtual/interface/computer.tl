local record computer end

function computer.address(): string
    return "virtual_address"
end

local assumed_memory: integer = 2048
function computer.freeMemory(): integer
    local count = collectgarbage("count")
    local kilo = count / 1024

    return math.floor(assumed_memory - kilo)
end

function computer.uptime(): integer
    return os.time()
end

function computer.maxEnergy(): integer
    return 30000
end

function computer.energy(): integer
    return 30000
end


return computer
