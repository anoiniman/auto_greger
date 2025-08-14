-- luacheck: globals FUEL_TYPE DO_FUEL_GRIND

-- For now, (but we'll need to improve this for the stone age to even work, as is obvious)
-- we simply take wood from a predefined slot and shovel it into the generator, but hey
-- baby steps
local module = {}

local computer = require("computer")
local robot = require("robot")
local component = require("component")

local comms = require("comms")
local inv = require("inventory.inv_obj")
local item_buckets = require("inventory.item_buckets")
-- local map = require("map_obj")


local gen = component.getPrimary("generator")
local inv_controller = component.getPrimary("inventory_controller")

-- TODO programme the basic fuel-farming routines and when to start them, aka, stop doing progress and
-- grind the fuel

function module.prepare_exit()
    gen.remove(gen.count()) -- removes into selected slot so no need to "maybe_something_added", but still
    inv.maybe_something_added_to_inv()
end

local cur_ammount
local cur_lable, cur_name
local function refuel()
    cur_ammount = gen.count()
    if cur_ammount > 24 then
        return
    end

    local fuel_slot
    if FUEL_TYPE == "loose_coal" then
        fuel_slot = inv.find_largest_slot(nil, "any:fuel") -- bucket name will probabily need to change
    elseif FUEL_TYPE == "wood" then
        fuel_slot = inv.find_largest_slot(nil, "any:plank")
    else
        print(comms.robot_send("error", "Unexpected fuel type"))
        return false
    end

    if fuel_slot == nil then return end

    -- TODO report these little errors to a log file or smthning
    local slot_info = inv_controller.getStackInInternalSlot(fuel_slot)
    if slot_info == nil then return end

    cur_lable = slot_info.label; cur_name = item_buckets.identify(slot_info.name, cur_lable);

    if fuel_slot ~= robot.select(fuel_slot) then
        print(comms.robot_send("error", "Was unable to add fuel"))
        return
    end

    local to_insert = 64 - gen.count()
    gen.insert(to_insert)
    inv.remove_from_slot(fuel_slot, to_insert)

    robot.select(1)
end

function module.start_check() -- at programme startup makes sure that we count fuel properly!
    gen.remove(gen.count())
    inv.maybe_something_added_to_inv()
end

function module.force_fuel(slot_num)
    robot.select(slot_num)
    gen.insert(64)
    robot.select(1)
end

local issued_warning = false
local max_energy = computer.maxEnergy() / 64.0

-- Power Unit (PU) = (MJ * 4) / 10
-- Coal Unit (cU) = 1280 MJ = 512 PU
-- Standard Unit (sU) = 1/8 cU
-- 1 Move = 15 PU = 1/34 cU = 4/17 (~0.25) sU, Moving 1 chunk = 240 PU = 1/2 cU = 4 sU = 1.5 logs
local u_coal = 8.0; local u_wood = 1.5
local u_creosote = 32.0
function module.calculate_cur_energy(reserve) -- reserve, for example, always have 32 planks available for non power usage
    reserve = tonumber(reserve)
    if reserve == nil then reserve = 0
    elseif reserve < 0 then reserve = 0 end

    local unit_mult
    if cur_lable == "Coal" or cur_lable == "Charcoal" then unit_mult = u_coal
    elseif cur_name == "any:plank" or cur_name == "any:wood" then unit_mult = u_wood
    elseif cur_lable == "Creosote Bucket" then unit_mult = u_creosote
    elseif cur_lable == nil and cur_name == nil then -- we have nothing in le hole
        return computer.energy() / 64.0
    else
        print(comms.robot_send("error", "calculate energy lable/name not recognised: " .. string.format("l: %s, n: %s", cur_lable, cur_name)))
        return -1
    end

    local total_ammount = cur_ammount + inv.virtual_inventory:howMany(cur_lable, cur_name) - reserve
    local fuel_energy = total_ammount * unit_mult -- sU
    local battery_energy = computer.energy() / 64.0 -- PU -> sU

    return battery_energy + fuel_energy
end

function module.possible_round_trip_distance(reserve, high_margin)
    if high_margin == nil then high_margin = false end
    local margin
    if high_margin then margin = max_energy
    else margin = max_energy / 3.0 end

    local cur_energy = module.calculate_cur_energy(reserve) / 2
    -- take away some of it away to give us some margin (1/3)
    cur_energy = cur_energy - margin

    return cur_energy * (17.0 / 4.0) -- converts sU into blocks
end

local function basic_energy_management(_cur_energy, percentage)
    -- Determine if we have to emergency shut-off or something like that
    if percentage < 12.0 then
        print(comms.robot_send("warning", "Energy Dropped below 12%, shutting down"))
        os.sleep(2.0) -- IDK if it matters, but it is good practice imo
        computer.shutdown()
    elseif percentage < 50.0 and not issued_warning then -- issue a warning
        print(comms.robot_send("warning", "Energy Dropped below 50%"))
        issued_warning = true
    end

    if percentage > 50.0 and issued_warning then issued_warning = false end

    -- Determine if we need to take a break
    local raw_percentage = ((computer.energy() / 64.0) / max_energy) * 100
    if raw_percentage < 15.0 then os.sleep(3) end
end

-- Maybe this is not necessary if we make it so the energy management things have the highest priority idk in rasoning
--[[local function advanced_energy_management(cur_energy, percentage)
    if not DO_FUEL_GRIND then return nil end
    local coke_quads = map.get_buildings("coke_quad")   -- hehehhe if we le coke quad etc.


    return command
end--]]

function module.keep_alive()
    refuel() -- The cool thing

    local cur_energy = module.calculate_cur_energy()
    local percentage = (cur_energy / max_energy) * 100
    basic_energy_management(cur_energy, percentage)

    return nil
end

return module
