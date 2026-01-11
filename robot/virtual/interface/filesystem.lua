local filesystem = {}

local function get_path(path)
    return string.gsub(path, "/home/robot/", "./")
end

function filesystem.exists(path)
    -- if V_ENV ~= nil then path = string.gsub(path, "/home/robot/", "./") end
    path = get_path(path)
    local file = io.open(path, "r")
    if file == nil then return false end
    file:close()
    return true
end

function filesystem.isDirectory(path)
    path = get_path(path)
    if path == "./save_state" then return true end
    error("unimplemented")
end

function filesystem.makeDirectory(path)
    path = get_path(path)
    print("Directory creation not allowed")
    print("Attempted to create: " .. path)
    -- os.execute("mkdir " .. path)
end

return filesystem
