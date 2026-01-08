local term = {}

function term.getCursor()
    print("term_getCursor")
end

function term.setCursor(_col, _row)
    print("term_setCursor")
end

local cursor_blink = true
function term.getCursorBlink()
    return cursor_blink
end

function term.setCursorBlink(enabled)
    cursor_blink = enabled
end

function term.clear()
    print("term_clear")
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

function term.bind(_gpu)
    error()
end

function term.screen()
    error()
end

function term.keyboard()
    error()
end

return term
