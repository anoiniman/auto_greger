require("deep_copy")

local module = {parent = nil}

-- IGNORE THIS COMMENT -- this an i-table of tables not an a-table k,v
local dictionary = {
    ["c"] = "CokeOvenBrick", -- tmp name, I need to geolyze in game first or whatever
}

-- Orientation is assumed for sector 3 (x:-1,z:-1)
-- create rotation function somewhere
local human_readable = {
"--ccc--",
"--ccc--",
"--ccc--",
"-------",
"--ccc--",
"--ccc--",
"--ccc--",
}

local origin_pos = {0,0,0}
local doors = {}

-- consuming what function is to be executed
function iter(human_readable)
    local iteration = 0
    local goal = 3
    return function ()
        iteration = iteration + 1 -- later indexes into 1,2,3
        if iteration == 2 then
            local temp = deep_copy.copy_table(human_readable, ipairs)
            local hole = "--c-c--"
            temp[2] = hole
            temp[6] = hole
            return interation, temp
        end
        if iteration <= goal then 
            return iteration, human_readable 
        end
        return nil
    end
end

return
