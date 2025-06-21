local os = require("os")
local component = require("component")
local sides_api = require("sides")

local deep_copy = require("deep_copy")
local nav = require("nav_module.nav_obj")
-- local inv = require("inventory.inv_obj")

local inv_controller = component.getPrimary("inventory_controller")


local Module = {
    from_inventory = nil,
    to_inventory = nil,

    how_much = 0, -- how much to logisticise

    where = 1, -- if we are in from or in to
    mode_func = Module.toFrom 
}

function Module:new(from_inventory, to_inventory)
    local new = deep_copy.copy(self, pairs)
    new.from_inventory = from_inventory or "self"
    new.to_inventory = to_inventory or "self"
    return new
end

function Module:doLogistics()
    local inv_action
    local target_inv
    if where == 1 then
        target_inv = self.from_inventory
        inv_action = inv.suck_only_named
    elseif where == 2 then
        target_inv = self.to_inventory
        inv_action = inv.dump_only_named
    else error(comms.robot_send("fatal", "invalid state")) end

    local opposite = nav.get_opposite_orientation()
    while true do -- orient thyself
        local is_inv = inv_controller.getInventorySize()
        if is_inv ~= nil then break end

        nav.rotate_right()
        if nav.get_opposite_orientation() == opposite then
            error(comms.robot_send("fatal", "We were sent somewhere with no inventory!"))
        end
    end

    inv_action(target_inv)
end


function Module:goTo()
    local target
    if where == 1 then target = self.from_inventory
    elseif where == 2 then target = self.to_inventory
    else error(comms.robot_send("fatal", "invalid state")) end

    local cur_chunk = nav.get_chunk()
    local from_chunk = target:getChunk()

    if cur_chunk[1] ~= from_chunk[1] or cur_chunk[2] ~= from_chunk[2] then
        if not nav.is_setup_navigate_chunk() then
            nav.setup_navigate_chunk(from_chunk)
        end
        nav.navigate_chunk("surface") -- I think we don't need to check return?
        return
    end

    local target_coords = target:getCoords()
    local cur_coords = nav.get_rel()
    if cur_coords[1] ~= target_coords[1] or cur_coords[2] ~= target_coords[2] or cur_coords[3] ~= target_coords[3] then
        if not nav.is_setup_navigate_rel() then
            nav.setup_navigate_rel(target_coords)
        end
        local result = nav.navigate_rel()
        if result == 1 then
            os.sleep(1) -- not very smart
        end
        return
    end

    self.mode_func = self.doLogistics
end

function Module:doTheThing()
    self.mode_func(self)
end


return Module
