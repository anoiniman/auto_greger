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

-- consuming what function is to be executed
local function iter(human_readable)
    local iteration = 0
    local goal = 3
    return function ()
        iteration = iteration + 1 -- later indexes into 1,2,3
        if iteration <= goal then 
            return iteration, human_readable 
        end
        return nil
    end
end

function module:init(n_parent) -- return ref to dictionary plz
    if self.parent ~= nil then return self end
    self.parent = n_parent
    parent.iter_init_func = iter
end


return
