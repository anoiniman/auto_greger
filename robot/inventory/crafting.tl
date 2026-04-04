local robot = require("robot")
local component = require("component")

require("Task")
require("reasoning.MetaRecipe.__h_MetaRecipe")
local type InvObj = require("inventory.__h_InvObj")
local vinv_helper = require("inventory.VirtualInventory")

local late_bind = require("late_bind")
local inv: InvObj = late_bind.new_bind("inventory.inv_obj")

local a_tbl = require("PriorityQueue")
local pqueue, PriorityQueue, _Prioritizable = table.unpack(a_tbl)

local comms = require("comms")

-- local inventory_controller: InventoryController = component.getPrimary("inventory_controller") as InventoryController
local crafting_component: Crafting = component.getPrimary("crafting") as Crafting
local use_self_craft = true

local record module end
function module.isCraftActive(): boolean
    return use_self_craft
end

-- WARNING: WILL have some problems with tools breaking and so on, let's just hope it is able of self-cleaning!
-- WARNING: can only craft (optimistically) up to a stack at the time! expected_output > 64 is floored to 64
-- NOTE: We expect that crafting quantities and so on are pre-calculated by reasoning, failure to do so will be
-- reported but it will result in a full system crash that is not to be handled
function module.craft(task_state: CraftingState): CraftingState, boolean
    local recipe_grid: recipeGrid = task_state.recipe_grid
    local output: FullerDefinition = task_state.output
    local repeats: integer = output.size

    --function module.craft(dictionary, recipe, output, how_much_to_craft)
    if not module.isCraftActive() then error(comms.robot_send("fatal", "Craft is not active")) end

    if not inv.is_crafting_clear() then
        print(comms.robot_send("error", "attempted to self_craft, yet internal crafting table was not clear, aborting!"))
        return task_state, false
    end

    for grid_slot, item_def in ipairs(recipe_grid) do
        if item_def is nil then goto continue end
        item_def = item_def as ItemDefinition

        if grid_slot > 3 then grid_slot = grid_slot + 1 end
        if grid_slot > 6 then grid_slot = grid_slot + 2 end

        local label, name: string, string | nil
        label = item_def.label as string
        name = item_def.name

        local i_slot_tbl = vinv_helper.get_all_slots(inv.virtual_inventory, label, name)
        if i_slot_tbl is nil then
            error(comms.robot_send("fatal", "Woops no slots with what we want"))
            break
        end
        i_slot_tbl = i_slot_tbl as PriorityQueue<SlotEntry>

        local remaining = repeats
        while remaining > 0 do
            local biggest = pqueue.remove(i_slot_tbl)
            if biggest is nil then 
                error(comms.robot_send("fatal", "Woops no slots left in queue"))
                break
            end
            biggest = biggest as SlotEntry

            local quantity = biggest.quantity

            local result = robot.select(biggest.slot)
            if result ~= biggest.slot or not robot.transferTo(grid_slot, remaining) then
                error(comms.robot_send("fatal", "something went wrong in self_crafting (transferTo)"))
            end -- else we succeded! (yay!)
            vinv_helper.remove_from_slot(inv.virtual_inventory, biggest.slot, remaining) -- it's ok to overshoot!

            remaining = remaining - quantity
        end

        ::continue::
    end
    
    -- Now the virtual crafting-table should be assembled, lets do the thing!
    local output_slot = vinv_helper.get_smallest_slot(inv.virtual_inventory, output.label, output.name)
    if  output_slot is nil
        or vinv_helper.how_many_slot(inv.virtual_inventory, output_slot) + repeats > 64
    then
        output_slot = vinv_helper.get_empty_slot(inv.virtual_inventory, inv.get_forbidden_table())
    end

    if output_slot == nil then error(comms.robot_send("fatal", "assert failed!")) end

    robot.select(output_slot)
    local result = crafting_component.craft(64)     -- craft as many as possible, in case of gross oversight
                                                    -- this should at least crash hard

    if not result then
        print(comms.robot_send("error", "failed to craft :("))
        inv.force_update_vinv() -- last hurah-ass
        for index = 1, 12, 1 do
            if index % 4 ~= 0 then inv.simple_slot_check(index) end
        end

        return task_state, false
    end

    -- Optimistically Update the thingy-majig
    vinv_helper.force_update_slot(inv.virtual_inventory, output.label, output.name, repeats, output_slot)

    robot.select(1)
    return task_state, true
end

return module
