-- Things to do after exit is called
local keep_alive = require("keep_alive")

local module = {}

-- This will be where we do the saving the state things
function module.exit()
    keep_alive.prepare_exit()
end

return module
