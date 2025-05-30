local module = {}

local sides_api = require("sides")
local robot = require("robot")

local comms = require("comms")
local geolyzer = require("geolyzer_wrapper")
local inv = require("inventory.inv_obj")

local function table_contains(extra_sauce, what)
    for _, sauce in ipairs(extra_sauce) do
        if sauce == what then
            return true
        end
    end
    return false
end

local function do_move_down(parent, nav_obj, extra_sauce)
    local result, err = parent.base_move("down", nav_obj)

    if table_contains(extra_sauce, "smart_fall") then
        if result == true then -- else let it fall through, the caller will deal with it
            local old_orient = nav_obj.get_orientation()
            local new_orient = parent.get_opposite_orientation(nav_obj)
            parent.change_orientation(new_orient, nav_obj)

            local result = inv.place_block("front", "any:building_block", "name")
            if result == false then

                inv.equip("sword")
                local watch_dog = 17
                while watch_dog < 17 do -- we'll blindly swing around until we score!
                    robot.swing()
                    inv.maybe_something_added_to_inv()
                    os.sleep(1)
                    local result = inv.place_block("front", "any:building_block", "name")
                    if result == true then goto no_error end

                    watch_dog = watch_dog + 1
                end
                print(comms.robot_send("error", "smart_fall -- place -- exceeded watch_dog! Make sure we are not stuck?"))

                ::no_error::
            end

            parent.change_orientation(old_orient, nav_obj) -- required so that we do not lose track of which way "forwards" is
        end
    end

    return result, err
end

-- If lava then uhhh don't?
-- It'll move down as much as it can without returning to the main loop, while the down-sides are
-- obvious it really simplifies the internal logic and mantains this functions as stateless
local function maybe_move_down(parent, nav_obj, extra_sauce)
    -- luacheck: ignore result err
    local result = true
    local err = nil

    local _, block_type = robot.detectDown()
    if block_type == "air" or block_type == "liquid" then
        -- Aka: just dew it
        result, err = do_move_down(parent, nav_obj, extra_sauce)

    elseif block_type == "liquid" then
        local liquid = geolyzer.simple_return(sides_api.down)
        if  table_contains(extra_sauce, "avoid_lava")
            and (
                geolyzer.sub_compare("minecraft:lava", "direct", liquid)
                or geolyzer.sub_compare("oil", "naive_contains", liquid)
            )
        then
            return false, "lava" -- early return
        end

        result, err = do_move_down(parent, nav_obj, extra_sauce)
    elseif block_type == "solid" then
        return true, nil -- we've arrived, return out
    else
        -- take a swing at it and depending if we're being smart or not wait for it to die/leave (smart)
        -- or just keep going (dumb) and hope for the best (early return)
        if table_contains(extra_sauce, "smart_fall") then

            inv.equip("sword")
            local watch_dog = 0
            while watch_dog < 21 do -- will atempt 21 times do break/attack thing below before bailing
                robot.swingDown()
                inv.maybe_something_added_to_inv()
                os.sleep(1)

                local result, err = do_move_down(parent, nav_obj, extra_sauce)
                if result == true then goto no_error end

                watch_dog = watch_dog + 1
            end
            print(comms.robot_send("error", "smart_fall -- fall -- exceeded watch_dog! Make sure we are not stuck in a cave?"))
        end

        ::no_error::
        return true, nil
    end

    if result == false then
        return result, err -- we've failed, return out
    end
    return maybe_move_down(parent, nav_obj, extra_sauce) -- kid named tail recursion
end

local function try_break_block(direction)
    local swing_function
    if direction == "up" then swing_function = inv.blind_swing_up
    elseif direction == "down" then swing_function = inv.blind_swing_down
    else swing_function = inv.blind_swing_front end

    local result, info = swing_function()

    if not result then return false, info end

    return true, nil
end


local break_block = {"break_block"}
function module.surface(parent, direction, nav_obj, extra_sauce)
    -- luacheck: push ignore result
    local result, err = parent.base_move(direction, nav_obj)

    if err ~= nil and err == "impossible move" then
        -- for know we just panic, maybe one day we'll add better AI
        print(comms.robot_send("error", "real_move: we just IMPOSSIBLE MOVED OURSELVES"))
        return false, "impossible"

    elseif err ~= nil and err ~= "impossible move" then -- TODO check that is not an entity
        if not table_contains(extra_sauce, "no_auto_up") then
            return parent.real_move("free", "up", nav_obj, break_block)
        end

        local obstacle = geolyzer.simple_return()
        return false, obstacle
    end

    -- luacheck: pop
    -- Only AFTER (not before) we've been succeseful do we try to move down
    local result, err = maybe_move_down(parent, nav_obj, extra_sauce)

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
            local result, _ = try_break_block(direction)
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
