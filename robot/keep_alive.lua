-- luacheck: globals FUEL_TYPE
FUEL_TYPE = false

-- For now, (but we'll need to improve this for the stone age to even work, as is obvious)
-- we simply take wood from a predefined slot and shovel it into the generator, but hey
-- baby steps
local module = {}

local robot = require("robot")
local component = require("component")

local comms = require("comms")
local inv = require("inventory.inv_obj")
local item_buckets = require("inventory.item_buckets")

local gen = component.getPrimary("generator")
local inv_controller = component.getPrimary("inventory_controller")


function module.prepare_exit()
    gen.remove(gen.count())
    inv.maybe_something_added_to_inv()
end

local cur_ammount
local cur_lable, cur_name
local function refuel()
    cur_ammount = gen.count()
    if cur_ammount > 24 then
        return
    end

    -- TODO (ATTENTION) In the early game we'll need to burn logs and shit, so add a flag to
    -- switch "any:fuel" to "any:plank" (it is free to turn logs into planks)
    local fuel_slot = inv.find_largest_slot(nil, "any:fuel")
    if fuel_slot == nil then return end

    -- TODO report these little errors to a log file or smthning
    local slot_info = inv_controller.getStackInInternalSlot(fuel_slot)
    if slot_info == nil then return end

    cur_lable = slot_info.label; cur_name = item_buckets.identify(slot_info.name, cur_lable);

    if fuel_slot ~= robot.select(fuel_slot) then
        print(comms.robot_send("error", "Was unable to add fuel"))
        return
    end

    local to_insert = 64 - fuel_count
    gen.insert(to_insert)
    inv.remove_from_slot(fuel_slot, to_insert)

    robot.select(1)
end

-- Power Unit (PU) = (MJ * 4) / 10
-- Coal Unit (cU) = 1280 MJ = 512 PU
-- Standard Unit (sU) = 1/8 cU
-- 1 Move = 15 PU = 1/34 cU = 4 * 1/4 (17/4) (4.25) sU, Moving 1 chunk = 240 PU = 1/2 cU = 4 sU = 1.5 logs
local u_coal = 8.0; local u_wood = 1.5
local u_creosote = 32.0
local function calculate_cur_energy()
    local unit_mult
    if cur_lable == "Coal" or cur_lable == "Charcoal" then unit_mult = u_coal
    elseif cur_name == "any:plank" or cur_name == "any:wood" then unit_mult = u_wood
    elseif cur_lable == "Creosote Bucket" then unit_mult = u_creosote
    else
        print(comms.robot_send("error", "calculate energy lable/name not recognised: " .. string.format("l: %s, n: %s", cur_lable, cur_name)))
        return -1
    end

    return cur_ammount * unit_mult -- sU
end

-- very temporary code
function module.keep_alive()
    refuel()
    local cur = calculate_cur_energy
end

return module
