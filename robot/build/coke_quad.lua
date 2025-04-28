local deep_copy = require("deep_copy")
local meta_door = require("build.MetaBuild.MetaDoorInfo")

local module = {parent = nil}

-- IGNORE THIS COMMENT -- this an i-table of tables not an a-table k,v
module.dictionary = {
    ["c"] = "CokeOvenBrick", -- tmp name, I need to geolyze in game first or whatever
}

-- Orientation is assumed for sector 3 (x:-1,z:-1)
-- create rotation function somewhere
module.human_readable = {
"--ccc--",
"--ccc--",
"--ccc--",
"-------",
"--ccc--",
"--ccc--",
"--ccc--",
}
module.origin_pos = {0,0,0}

module.doors = {}
doors[1] = meta_door:zeroed()
doors[1].doorX(6,2)

-- consuming what function is to be executed
function module.iter(human_readable)
    local iteration = 0
    local goal = 3
    return function ()
        iteration = iteration + 1 -- later indexes into 1,2,3
        if iteration == 1 then
            local temp = deep_copy.copy_table(human_readable, ipairs)
            local special = "--ccc*-"
            temp[2] = special
            temp[6] = special
            return interation, temp
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
