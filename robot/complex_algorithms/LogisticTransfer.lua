local os = require("os")
local component = require("component")

local comms = require("comms")
local deep_copy = require("deep_copy")

local nav = require("nav_module.nav_obj")
local door_move = require("nav_module.door_move")
local inv = require("inventory.inv_obj")

local inv_controller = component.getPrimary("inventory_controller")


local Module = {
    from_inventory = nil,
    to_inventory = nil,

    how_much = 0, -- how much to logisticise
    item_tbl = nil,
    item_tbl_index = 1,

    where = 1, -- if we are in from or in to
    has_door_moved = false,
    mode_func = nil
}

function Module:new(from_inventory, to_inventory, item_tbl)
    if item_tbl == nil or item_tbl[1] == nil
    then
        error(comms.robot_send("fatal", "assertion failed"))
    end

    local new = deep_copy.copy(self, pairs)
    new.from_inventory = from_inventory or "self"
    new.to_inventory = to_inventory or "self"
    new.item_tbl = item_tbl

    new.modue_func = Module.goTo

    return new
end

function Module:doLogistics()
    if self.item_tbl_index > #self.item_tbl then -- go to next where if applicable
        self.item_tbl_index = 1

        self.where = self.where + 1
        self.mode_func = self.goTo
        self.has_door_moved = false
        return "go_on"
    end

    local inv_action
    local target_inv
    if self.where == 1 then
        target_inv = self.from_inventory
        inv_action = inv.suck_only_matching
    elseif self.where == 2 then
        target_inv = self.to_inventory
        inv_action = inv.dump_only_matching
    elseif self.where == 3 then
        return "done"
    else error(comms.robot_send("fatal", "invalid state")) end

    local opposite = nav.get_opposite_orientation()
    while true do -- orient thyself
        local is_inv = inv_controller.getInventorySize()
        if is_inv ~= nil then break end

        nav.rotate_right()
        if nav.get_opposite_orientation() == opposite then
            print(comms.robot_send("error", "We were sent somewhere with no inventory!"))
            return "done"
        end
    end

    local cur_item = self.item_tbl[self.item_tbl_index]
    local lable = cur_item[1]; local name = cur_item[2]; local up_to = cur_item[3]

    local matching_slots = target_inv.ledger:getAllSlots(lable, name, up_to)
    inv_action(target_inv.ledger, matching_slots)

    self.item_tbl_index = self.item_tbl_index + 1
    return "go_on"
end


function Module:goTo()
    local target
    if self.where == 1 then target = self.from_inventory
    elseif self.where == 2 then target = self.to_inventory
    elseif self.where == 3 then return "done"
    else error(comms.robot_send("fatal", "invalid state")) end

    local target_chunk = target:getChunk()
    -- Chunk Move
    if not nav.is_in_chunk(target_chunk) then
        if not nav.is_setup_navigate_chunk() then
            nav.setup_navigate_chunk(target_chunk)
        end
        nav.navigate_chunk("surface") -- I think we don't need to check return?
        return
    end

    local cur_coords = nav.get_rel()

    -- Door Move
    if not self.has_door_moved then
        local door_info = self.where.parent:getDoors()
        if not door_move.is_setup() then door_move.setup_move(door_info, cur_coords) end
        local result, _ = door_move.do_move(nav)
        if result == 0 then return
        elseif result == -1 then
            self.has_door_moved = true
        else os.sleep(1) --[[ :) --]] end
    end


    -- Rel Move to Special Block
    local target_coords = target:getCoords()
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
    return "go_on"
end

function Module.doTheThing(arguments)
    local self = arguments[1]
    local lock = arguments[2]
    local prio = arguments[3]

    local result = self.mode_func(self)
    if result == "done" then
        lock[1] = 0 -- We set directly to 0 because this is just a logistic step that doesn't change the underlying requirement
        return nil
    end -- else
    return {prio, self.doTheThing, self, lock, prio}
end


return Module
