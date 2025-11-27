local filesystem = {}

function filesystem.exists(path)
    -- if V_ENV ~= nil then path = string.gsub(path, "/home/robot/", "./") end
    path = string.gsub(path, "/home/robot/", "./")
    local file = io.open(path, "r")
    if file == nil then return false end
    file:close()
    return true
end

return filesystem
