local term = {}

function term.getCursor()
    print("dummy")
end

function term.setCursor(col, row)
    error()
end

local cursor_blink = true
function term.getCursorBlink()
    return cursor_blink 
end

function term.setCursorBlink(enabled)
    cursor_blink = enabled
end

function term.clear()
    print("dummy")
end

function term.clearLine()
    error()
end

function term.read()
    io.read()
end

function term.write(value)
    print(value)
end

function term.bind(gpu)
    error()
end

function term.screen()
    error()
end

function term.keyboard()
    error()
end

return term
