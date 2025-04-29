local nav = require("nav_module.nav_interface")
local goal_rel = {0,0,0} -- x,z,y

function module.setup_navigate_rel(x,z,y)
    goal_rel[1] = x
    goal_rel[2] = z
    goal_rel[3] = y
end

function module.navigate_rel(nav_obj)

end
