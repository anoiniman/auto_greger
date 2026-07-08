local record module
    trim: function(string): string
    escapeMagic: function(string): string
    removeEscape: function(string): string

    tokenize: function(string, {any}): {string} | nil, string | nil
    split: function(string, {string}, boolean, integer): {string}

    detab: function(string, integer): string
    padLeft: function(string, integer): string
    padRight: function(string, integer): string
    wrap: function(string, integer, integer): string, boolean, boolean
    wrappedLines: function(string, integer, integer): function(): string
end

return module
