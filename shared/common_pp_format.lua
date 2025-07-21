local keyboard = require("keyboard")

local comms = require("comms")
local deep_copy = require("deep_copy")


local PPObj = {
    title = nil,
    page_titles = nil,
    
    pages = nil,
    lines = nil,
    buffer = nil,

    xsize = -1,
    ysize = -1
}

function PPObj:new(screen_type)
    local new = deep_copy.copy(PPObj)

    new.lines = {}
    new.buffer = {}
    new:setScreen(screen_type)

    return new
end

function PPObj:setScreen(screen_type)
    if screen_type == nil or screen_type == "robot" then
        self.xsize = 50
        self.ysize = 16
    elseif screen_type == "controller" then
        self.xsize = 80
        self.ysize = 25
    else -- DO NOT USE comms
        print("error", "non-recognised screen_type: " .. screen_type)
    end
end

function PPObj:newLine()
    local new_line = table.concat(self.buffer)
    table.insert(self.lines, new_line)

    for index = 1, #self.buffer, 1 do self.buffer[index] = nil end
    return self
end

function PPObj:setTitle(str)
    self.title = str
    return self
end

function PPObj:addString(str)
    if type(str) == "table" then
        for _, inner in ipairs(str) do
            self:addString(inner)
        end
        return self
    end

    table.insert(self.buffer, str)
    return self
end

function PPObj:build()
    if #self.buffer > 0 then
        local new_line = table.concat(self.buffer)
        table.insert(self.lines, new_line)
    end

    local temp = deep_copy.copy(self)
    if string.len(self.title) > self.xsize then
        local sub = string.sub(self.title, 1, self.xsize - 4)
        sub = sub .. "..."
        temp.title = sub
    end

    local index = 1
    while true do
        local str = self.lines[index]
        if str == nil then break end

        index = self:splitLineIf(str, index)
        index = index + 1
    end

    return temp
end

function PPObj:splitLineIf(line, index)
    if string.len(line) > self.xsize then
        local sub1 = string.sub(line, 1, self.xsize - 4)
        sub1 = sub1 .. "..."
        local sub2 = string.sub(line, self.xsize - 4)

        self.lines[index] = sub1
        index = index + 1
        table.insert(self.lines, index, sub2)
        if string.len(sub2) > self.xsize then index = self:splitLineIf(sub2, index) end
    end

    return index
end

-- returns n sub-tables (technically the return value is useless since pass-by-reference and all that)
function PPObj:subDividePages(lines, tbl)
    local padded_ysize = self.ysize - 4
    if #lines > padded_ysize then
        local page1 = {}
        local page2 = {}
        for index = 1, padded_ysize, 1              do table.insert(page1, lines[index]) end
        for index = padded_ysize, #lines, 1         do table.insert(page2, lines[index]) end

        table.insert(tbl, page1)
        if #page2 > padded_ysize then
            return self:subDividePages(page2, tbl)
        end -- else
        table.insert(tbl, page2)
    end

    return tbl
end

function PPObj:initPages()
    if self.pages == nil then
        local page_tbl = {}
        page_tbl = self:subDividePages(self.lines, page_tbl)
        self.pages = page_tbl
    end
    if self.page_titles == nil then
        self.page_titles = {}
        for index, _ in ipairs(self.pages) do
            self.page_titles[index] = self.title
        end
    end
end

function PPObj:addPagesToSelf(other)
    if other.pages == nil then other:initPages() end

    for _, page in ipairs(other.pages) do
        table.insert(self.pages, page)
        table.insert(self.page_titles, other.title)
    end
end

function PPObj:printPage(interactive_mode)
    if interactive_mode == nil or type(interactive_mode) ~= "boolean" then interactive_mode = false end
    if self.title == nil then self.title = "Default Title" end
    if self.is_built_obj == false then
        if interactive_mode == false then print(comms.robot_send("error", "Attempted to print non_built PPObj"))
        else print("<|internal error|>  Attemted to print non_built PPObj") end

        return
    end

    -- smart printing of pages
    if interactive_mode then
        -- we need to build a "page", basically a sub-tbl of lines
        self:initPages()

        local index = 1
        while true do
            local title = self.page_titles[index]
            if title == nil then title = self.title end

            local page = self.pages[index]
            print(title); print();
            for _, line in ipairs(page) do
                print(line)
            end

            local footer_left = {"Pages ", index, "/", #self.pages }
            print()
            print(table.concat(footer_left))

            os.sleep(0.1)
            local breakout = false
            while true do
                if keyboard.isKeyDown(keyboard.keys.left) then
                    index = math.max(1, index - 1)
                    break
                end

                if keyboard.isKeyDown(keyboard.keys.right) then
                    index = math.min(#self.pages, index + 1)
                    break
                end

                if keyboard.isKeyDown(keyboard.keys.q) then
                    breakout = true
                    break
                end
            end

            if breakout then break end
        end
        
        return
    end

    -- Corblimey, just print the lines out
    print(self.title)
    print()
    for _, line in ipairs(self.lines) do
        print(line)
    end
end

return PPObj
