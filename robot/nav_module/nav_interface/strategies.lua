local module = {}

local sides_api = require("sides")
local robot = require("robot")

local comms = require("comms")
local geolyzer = require("geolyzer_wrapper")
local inv = require("inventory.inv_obj")


-- Inside the complex operations dictated by "extra_sauce" failure is not an option, since certain
-- things need to be done in a particular order, this is to say, the execution order is
-- non-fungeble, unlike the simple operations that can fail without doing so catastrophically.
-- This is to say, that the simple operations can fail while still upholding the state invariants.


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
        if result then -- else let it fall through, the caller will deal with it
            local old_orient = nav_obj.get_orientation()
            local new_orient = parent.get_opposite_orientation(nav_obj)
            parent.change_orientation(new_orient, nav_obj)

            local result = inv.place_block("front", "any:building_block", "name")
            if not result then

                inv.equip("sword")
                local watch_dog = 17
                while watch_dog < 17 do -- we'll blindly swing around until we score!
                    robot.swing()
                    inv.maybe_something_added_to_inv()
                    os.sleep(1)
                    local result = inv.place_block("front", "any:building_block", "name")
                    if result then goto no_error end

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
                if result then goto no_error end

                watch_dog = watch_dog + 1
            end
            print(comms.robot_send("error", "smart_fall -- fall -- exceeded watch_dog! Make sure we are not stuck in a cave?"))
        end

        ::no_error::
        return true, nil
    end

    if not result then
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
            return module.free(parent, "up", nav_obj, break_block)
        end

        local obstacle = geolyzer.simple_return()
        return false, obstacle
    end

    -- luacheck: pop
    -- Only AFTER (not before) we've been succeseful do we try to move down
    local result, err = maybe_move_down(parent, nav_obj, extra_sauce)

    return result, err
end

-- Auto bridging behaviour is, as defined, entirly self-sufficient, but highly inneficient, but doing a more
-- efficient version of such a bridging behaviour would force us to add state to these functions
function module.free(parent, direction, nav_obj, extra_sauce)
    local result, err = parent.base_move(direction, nav_obj)
    if not result then
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
    end -- else happy path

    local _, block_beneath = robot.detect(sides_api.down)
    if block_beneath ~= "solid" and table_contains(extra_sauce, "auto_bridge") then

        -- sanity check
        if direction == "up" or direction == "down" then
            print(comms.robot_send("warning", "free_move, passed a \"auto_bridge\" directive to an 'up' or 'down' direction"))
            return true, nil
        end

        -- luacheck: ignore
        if block_beneath == "entity" then -- it's error gets managed later
        elseif block_beneath ~= "air" or block_beneath ~= "liquid" then -- there is something wierd here, try to break it
            local result = inv.blind_swing_down()
            if not result then
                print(comms.robot_send("warning", "During auto_bridge, could not break wierd block, be mindful"))
            end
        end

        -- move forward (we assume that we were in a stable platform before), then place block; then we go back and
        -- remove the previous block, its up to the caller to introduce a "no_destroy" extra instruction

        -- Since we already try and move in the start of the function, and this code block is in the happy path we can
        -- assume that we've already moved forward

        -- This is place down (1)
        local result = inv.place_block("down", "any:building_block", "name")
        if not result then
            inv.equip("sword")
            local watch_dog = 0
            while watch_dog < 17 do
                robot.swingDown()
                inv.maybe_something_added_to_inv()
                os.sleep(1)

                local result = inv.place_block("down", "any:building_block", "name")
                if result then goto no_error end

                watch_dog = watch_dog + 1
            end
            print(comms.robot_send("error", "auto_bridge -- place -- exceeded watch_dog! Are we fighting windmills?"))
            return false, nil -- report that bridging failed, let the caller handle this

            ::no_error::
        end
        -- we can now assume that we've placed down a block, unless specified we now go back to collect the previous block
        if not table_contains(extra_sauce, "no_destroy") then
            local old_dir = nav_obj.get_orientation() -- this is more ideomatic than using direction
            local new_dir = parent.get_opposite_orientation(nav_obj)

            -- Walk the Walk
            local result, _ = parent.base_move(new_dir, nav_obj)
            if not result then
                inv.equip("sword")
                local watch_dog = 0
                while watch_dog < 17 do
                    robot.swing()
                    inv.maybe_something_added_to_inv()
                    os.sleep(1)

                    local result, _ = parent.base_move(new_dir, nav_obj)
                    if result then goto no_error end

                    watch_dog = watch_dog + 1
                end

                print(comms.robot_send("error", "auto_bridge -- walk_back -- exceeded watch_dog! Are we fighting windmills?"))
                return false, "auto_bridge"

                ::no_error::
            end
            -- Breaky The Block
            local result = inv.blind_swing_down()
            if not result then
                print(comms.robot_send("warning", "auto_bridge -- break_block -- failed to break block"))
            end


            local result, _ = parent.base_move(old_dir, nav_obj) -- Maybe one day re-make that hacky generic function we thought up
            if not result then
                inv.equip("sword")
                local watch_dog = 0
                while watch_dog < 17 do
                    robot.swing()
                    inv.maybe_something_added_to_inv()
                    os.sleep(1)

                    local result, _ = parent.base_move(old_dir, nav_obj)
                    if result then goto no_error end

                    watch_dog = watch_dog + 1
                end

                print(comms.robot_send("error", "auto_bridge -- walk_back -- exceeded watch_dog! Are we fighting windmills?"))
                return false, "auto_bridge"

                ::no_error::
            end
        end
    end

    return true, nil
end


return module
