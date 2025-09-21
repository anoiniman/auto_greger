local comms = require("comms")

local robot = require("robot")
local nav = require("nav_module.nav_obj")
local inv = require("inventory.inv_obj")

local module = {}

local target_height = -1
local going_down = true
local is_setup = false

function module.setup(t_height)
    going_down = true
    is_setup = true
    target_height = t_height
end

function module.is_setup()
    return is_setup
end

-- false for continue, true to go next
local function down_stroke()
    local something_below, _ = robot.detectDown()
    if something_below then return true end

    nav.debug_move("down", 1)
    return false
end

local function up_stroke()
    local cur_height = nav.get_height()
    if cur_height >= target_height then return true end

    nav.debug_move("up", 1)
    -- if it fails, just keep climbing until le target height
    inv.place_block("down", {"any:building", "any:plank", "any:log", "any:grass"}, "name_table", nil)
    return false
end

-- true means we're done, false means keepgoing
function module.fill()
    if not is_setup then
        print(comms.robot_send("error", "violated execution order, fill is not setup"))
        return true
    end

    if going_down then
        local result = down_stroke()
        if result then going_down = false end

        local cur_height = nav.get_height()
        if not going_down and cur_height >= target_height then
            print(comms.robot_send("warning", "erratic movement pattern discovered in foundation_fill"))
        end
        return false
    end

    local result = up_stroke()
    if result then
        target_height = -1
        going_down = true
        is_setup = false
    end
    return result
end


return module
