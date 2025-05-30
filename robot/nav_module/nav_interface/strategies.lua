local module = {}

local sides_api = require("sides")
local robot = require("robot")

local comms = require("comms")
local geolyzer = require("geolyzer_wrapper")

local function table_contains(extra_sauce, what)
    for _, sauce in ipairs(extra_sauce) do
        if sauce == what then
            return true
        end
    end
    return false
end

-- If lava then uhhh don't?
-- extra sauce expects to be a string
local function maybe_move_down(parent, nav_obj, extra_sauce)
    local result = true
    local err = nil

    local _, block_type = robot.detectDown()
    if block_type == "air" or block_type == "liquid" then
        result, err = parent.base_move("down", nav_obj)
        return result, err
    elseif block_type == "liquid" then
        local liquid = geolyzer.simple_return(sides_api.down)
        if  table_contains(extra_sauce, "avoid_lava")
            and (
                geolyzer.sub_compare("minecraft:lava", "direct", liquid)
                or geolyzer.sub_compare("oil", "naive_contains", liquid)
            )
        then
            return false, "lava"
        end

        result, err = parent.base_move("down, nav_obj")
    end

    return result, err
end

local function try_break_block()
    local swing_function
    if direction == "up" then swing_function = inv.blind_swing_up
    elseif direction == "down" then swing_function = inv.blind_swing_down
    else swing_function = inv.blind_swing_front end

    local result, info = swing_function()

    if not result then return false, info end

    return true, nil
    --module.free(parent, direction, nav_obj, extra_sauce)
end


local break_block = {"break_block"}
function module.surface(parent, direction, nav_obj, extra_sauce)
    local result, err = parent.base_move(direction, nav_obj)

    if err ~= nil and err == "impossible move" then
        -- for know we just panic, maybe one day we'll add better AI
        print(comms.robot_send("error", "real_move: we just IMPOSSIBLE MOVED OURSELVES"))
        return false, "impossible"

    elseif err ~= nil and err ~= "impossible move" then -- TODO check that is not an entity
        if not table_contains(extra_sauce, "no_auto_up") then
            return parent.real_move("free", "up", nav_obj, break_block) -- This is the case for a non tree terrain feature
        end

        local obstacle = geolyzer.simple_return()
        return false, obstacle
    end

    -- Only AFTER (not before) we've been succeseful do we try to move down
    local result, err = maybe_move_down(parent, nav_obj, extra_sauce[1])

    return result, err
end

function module.free(parent, direction, nav_obj, extra_sauce)
    local result, err = parent.base_move(direction, nav_obj)
    if result == nil then
        -- print(comms.robot_send("debug", "real_move: \"" .. strat_name .. "\" || error: \"" .. err .. "\""))
        if err == "entity" then
            inv.equip_tool("sword")
            robot.swing()
            inv.maybe_something_added_to_inv()
            return false, "swong"
        elseif err ~= "impossible move" then
        if extra_sauce == break_block or table_contains(extra_sauce, "break_block") then
            local result, _ = try_break_block()
            if not result then return false, "failed_break" end

            return module.free(parent, direction, nav_obj, extra_sauce)
        else
            return false, err
        end
        elseif err == "impossible move" then
            return false, "impossible"
        end
    end
    return true, nil
end


return module
