-- Done in a hurry, might be coded wrong
local record PPObj
    title: string
    page_titles: {string}

    pages: {{string}}
    lines: {string}
    buffer: {string}

    xsize: integer
    ysize: integer

    new: function(PPObj, ?string): PPObj
    setScreen: function(PPObj, string)    
    newLine: function(PPObj): PPObj
    setTitle: function(PPObj, string): PPObj
    addString: function(PPObj, string): PPObj
    build: function(PPObj): PPObj

    splitLineIf: function(PPObj, string, integer): integer
    subDividepages: function(PPObj, {string}, {{string}}): {{string}}
    initPages: function(PPObj)
    addPagesToSelf: function(PPObj, PPObj)
    printPage: function(PPObj, boolean)
end
return PPObj
