-- Opencomputers code https://github.com/MightyPirates/OpenComputers/
local keys = {}
keys["1"]           = 0x02
keys["2"]           = 0x03
keys["3"]           = 0x04
keys["4"]           = 0x05
keys["5"]           = 0x06
keys["6"]           = 0x07
keys["7"]           = 0x08
keys["8"]           = 0x09
keys["9"]           = 0x0A
keys["0"]           = 0x0B
keys.a               = 0x1E
keys.b               = 0x30
keys.c               = 0x2E
keys.d               = 0x20
keys.e               = 0x12
keys.f               = 0x21
keys.g               = 0x22
keys.h               = 0x23
keys.i               = 0x17
keys.j               = 0x24
keys.k               = 0x25
keys.l               = 0x26
keys.m               = 0x32
keys.n               = 0x31
keys.o               = 0x18
keys.p               = 0x19
keys.q               = 0x10
keys.r               = 0x13
keys.s               = 0x1F
keys.t               = 0x14
keys.u               = 0x16
keys.v               = 0x2F
keys.w               = 0x11
keys.x               = 0x2D
keys.y               = 0x15
keys.z               = 0x2C

keys.apostrophe      = 0x28
keys.at              = 0x91
keys.back            = 0x0E -- backspace
keys.backslash       = 0x2B
keys.capital         = 0x3A -- capslock
keys.colon           = 0x92
keys.comma           = 0x33
keys.enter           = 0x1C
keys.equals          = 0x0D
keys.grave           = 0x29 -- accent grave
keys.lbracket        = 0x1A
keys.lcontrol        = 0x1D
keys.lmenu           = 0x38 -- left Alt
keys.lshift          = 0x2A
keys.minus           = 0x0C
keys.numlock         = 0x45
keys.pause           = 0xC5
keys.period          = 0x34
keys.rbracket        = 0x1B
keys.rcontrol        = 0x9D
keys.rmenu           = 0xB8 -- right Alt
keys.rshift          = 0x36
keys.scroll          = 0x46 -- Scroll Lock
keys.semicolon       = 0x27
keys.slash           = 0x35 -- / on main keyboard
keys.space           = 0x39
keys.stop            = 0x95
keys.tab             = 0x0F
keys.underline       = 0x93

-- Keypad (and numpad with numlock off)
keys.up              = 0xC8
keys.down            = 0xD0
keys.left            = 0xCB
keys.right           = 0xCD
keys.home            = 0xC7
keys["end"]         = 0xCF
keys.pageUp          = 0xC9
keys.pageDown        = 0xD1
keys.insert          = 0xD2
keys.delete          = 0xD3

-- Function keys
keys.f1              = 0x3B
keys.f2              = 0x3C
keys.f3              = 0x3D
keys.f4              = 0x3E
keys.f5              = 0x3F
keys.f6              = 0x40
keys.f7              = 0x41
keys.f8              = 0x42
keys.f9              = 0x43
keys.f10             = 0x44
keys.f11             = 0x57
keys.f12             = 0x58
keys.f13             = 0x64
keys.f14             = 0x65
keys.f15             = 0x66
keys.f16             = 0x67
keys.f17             = 0x68
keys.f18             = 0x69
keys.f19             = 0x71

-- Japanese keyboards
keys.kana            = 0x70
keys.kanji           = 0x94
keys.convert         = 0x79
keys.noconvert       = 0x7B
keys.yen             = 0x7D
keys.circumflex      = 0x90
keys.ax              = 0x96

-- Numpad
keys.numpad0         = 0x52
keys.numpad1         = 0x4F
keys.numpad2         = 0x50
keys.numpad3         = 0x51
keys.numpad4         = 0x4B
keys.numpad5         = 0x4C
keys.numpad6         = 0x4D
keys.numpad7         = 0x47
keys.numpad8         = 0x48
keys.numpad9         = 0x49
keys.numpadmul       = 0x37
keys.numpaddiv       = 0xB5
keys.numpadsub       = 0x4A
keys.numpadadd       = 0x4E
keys.numpaddecimal   = 0x53
keys.numpadcomma     = 0xB3
keys.numpadenter     = 0x9C
keys.numpadequals    = 0x8D

-- Create inverse mapping for name lookup.
setmetatable(keys,
{
  __index = function(tbl, k)
    if type(k) ~= "number" then return end
    for name,value in pairs(tbl) do
      if value == k then
        return name
      end
    end
  end
})

return keys
