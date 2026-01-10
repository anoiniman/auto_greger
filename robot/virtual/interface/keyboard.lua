-- local render_lib = require("render")
-- Stub implementation
local buffer = {}
local keyboard = {}

function keyboard.isAltDown()
    return false
end

function keyboard.isControl(char)
    return false
end

function keyboard.isControlDown()
    return false
end

function keyboard.isKeyDown(code)
    local maybe = table.remove(buffer, 1)
    if maybe == nil then return false end

    return maybe == code
end

function keyboard.isShiftDown()
    return false
end

return new
