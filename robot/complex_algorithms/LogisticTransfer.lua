local os = require("os")
local component = require("component")
local sides_api = require("sides")

local comms = require("comms")
local deep_copy = require("deep_copy")

local nav = require("nav_module.nav_obj")
local door_move = require("nav_module.door_move")
local inv = require("inventory.inv_obj")

local inv_controller = component.getPrimary("inventory_controller")


local dbg_call = 0
local Module = {
    from_inventory = nil,
    to_inventory = nil,

    how_much = 0, -- how much to logisticise
    item_tbl = nil,
    item_tbl_index = 1,

    where = 1, -- if we are in from or in to
    has_door_moved = false,
    has_chunk_moved = false,
    mode_func = nil
}

-- inventories are fat inventories, item_tbl is of the following format table of: {[1] = lable, [2] = name, [3] = how_much} elements
function Module:new(from_inventory, to_inventory, item_tbl)
    if item_tbl == nil or item_tbl[1] == nil
    then
        error(comms.robot_send("fatal", "assertion failed"))
    end

    local new = deep_copy.copy(self, pairs)
    new.from_inventory = from_inventory or "self"
    new.to_inventory = to_inventory or "self"
    new.item_tbl = item_tbl

    new.mode_func = new.goTo

    dbg_call = 0
    return new
end

function Module:doLogistics()
    if dbg_call < 4 then print(comms.robot_send("debug", "doLogistics")) end

    if self.item_tbl_index > #self.item_tbl then -- go to next where if applicable
        self.item_tbl_index = 1

        self.where = self.where + 1
        self.mode_func = self.goTo
        self.has_door_moved = false
        self.has_chunk_moved = false
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
        local is_inv = inv_controller.getInventorySize(sides_api.front)
        if is_inv ~= nil then break end

        nav.rotate_right()
        if nav.get_opposite_orientation() == opposite then
            print(comms.robot_send("error", "We were sent somewhere with no inventory!"))
            return "done"
        end
    end

    local cur_item = self.item_tbl[self.item_tbl_index]
    local lable = cur_item[1]; local name = cur_item[2]; local up_to = cur_item[3]

    -- Another important thing I forgot, if target is "self", then it doesn't make sense to "dump" to self, or "suck" to self,
    -- so we skip
    if target_inv == "self" then
        self.item_tbl_index = 5000 -- hacky, but whatever
        return "go_on"
    end

    local matching_slots = target_inv.ledger:getAllSlots(lable, name, up_to)
    inv_action(target_inv.ledger, up_to, matching_slots)

    self.item_tbl_index = self.item_tbl_index + 1
    dbg_call = 0
    return "go_on"
end


function Module:goTo()
    if dbg_call < 4 then print(comms.robot_send("debug", "goTo")) end

    local target
    if self.where == 1 then target = self.from_inventory
    elseif self.where == 2 then target = self.to_inventory
    elseif self.where == 3 then return "done"
    else error(comms.robot_send("fatal", "invalid state")) end

    -- Very Important thing I forgot, if the target is self, well, we're already there right?
    if target == "self" then
        self.mode_func = self.doLogistics
        dbg_call = 0
        return "go_on"
    end

    local target_chunk = target:getChunk()
    local cur_coords = nav.get_rel()

    if nav.get_cur_building() == target.parent_build then
        self.has_door_moved = true
        goto skip_door_move
    end

    -- Chunk Move
    if not self.has_chunk_moved then
        if not nav.is_setup_navigate_chunk() then
            nav.setup_navigate_chunk(target_chunk)
        end
        self.has_chunk_moved = nav.navigate_chunk("surface") -- I think we don't need to check return?
        return "go_on"
    end

    -- Door Move
    if not self.has_door_moved then
        local door_info = target.parent_build.doors
        if not door_move.is_setup() then door_move.setup_move(door_info, cur_coords) end
        local result, _ = door_move.do_move(nav)
        if result == 0 then return "go_on"
        elseif result == -1 then
            self.has_door_moved = true
        else os.sleep(1) --[[ :) --]] end
    end
    ::skip_door_move::


    -- Rel Move to Special Block
    local height = nav.get_height()
    local target_coords = target:getCoords()
    if cur_coords[1] ~= target_coords[1] or cur_coords[2] ~= target_coords[2] or height ~= target_coords[3] then
        if not nav.is_setup_navigate_rel() then
            nav.setup_navigate_rel(target_coords)
        end
        local result = nav.navigate_rel()
        if result == 1 then
            os.sleep(1) -- not very smart
        end
        return "go_on"
    end

    self.mode_func = self.doLogistics
    dbg_call = 0
    return "go_on"
end

function Module.doTheThing(arguments)
    local self = arguments[1]
    local lock = arguments[2]
    local prio = arguments[3]

    if dbg_call < 4 then
        print(comms.robot_send("debug", "Logistiking"))
        dbg_call = dbg_call + 1
    end

    local result = self.mode_func(self)
    if result == "done" then
        lock[1] = 0 -- We set directly to 0 because this is just a logistic step that doesn't change the underlying requirement
        return nil
    end -- else
    return {prio, self.doTheThing, self, lock, prio}
end


return Module
