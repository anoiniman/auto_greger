local robot = require("robot")
local component = require("component")

require("Task")
require("reasoning.MetaRecipe.__h_MetaRecipe")
local type InvObj = require("inventory.__h_InvObj")
local vinv_helper = require("inventory.VirtualInventory")

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
function module.craft(taskState: CraftingState, inv: InvObj): boolean
    local recipe_grid: recipeGrid = taskState.recipe_grid
    local output: ItemDefinition = taskState.output
    local repeats: integer = taskState.repeats

    --function module.craft(dictionary, recipe, output, how_much_to_craft)
    if not module.isCraftActive() then error(comms.robot_send("fatal", "Craft is not active")) end

    if not inv.is_crafting_clear() then
        print(comms.robot_send("error", "attempted to self_craft, yet internal crafting table was not clear, aborting!"))
        return false
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

        return false
    end

    -- Optimistically Update the thingy-majig
    vinv_helper.force_update_slot(inv.virtual_inventory, output.label, output.name, repeats, output_slot)

    robot.select(1)
    return true
end

--[[function module.craft(taskState: CraftingState, crafting_table_clear: boolean): boolean
    local dictionary: {string : ItemDefinition} = taskState.dictionary
    local recipe: craftingGrid = taskState.crafting_recipe
    local output: ItemDefinition = taskState.output
    local repeats: integer = taskState.repeats

    --function module.craft(dictionary, recipe, output, how_much_to_craft)
    if not module.isCraftActive() then error(comms.robot_send("fatal", "Craft is not active")) end

    if not crafting_table_clear then
        print(comms.robot_send("error", "attempted to self_craft, yet internal crafting table was not clear, aborting!"))
        return false
    end

    local ingredient_table = {}
    local occurence_table = {} -- = {slot_a, slob_b, .... slot_c}
    for slot, char in ipairs(recipe) do
        if char is nil then goto continue end
        if occurence_table[char] == nil then
            occurence_table[char] = {slot}
            local ingredient = dictionary[char]
            ingredient_table[char] = ingredient
        else
            table.insert(occurence_table[char], slot)
        end

        ::continue::
    end

    local clean_up = false
    for stbl_index, sub_table in pairs(occurence_table) do
        local label, name: string, string
        local ingredient = ingredient_table[stbl_index]

        if ingredient == nil then
            error(comms.robot_send("fatal", "assertion failed"))
        end

        if type(ingredient) == "table" then -- select strict search (or permissive is ingredient[1] is nil)
            label = ingredient[1]
            name = ingredient[2]
        else -- select lable-only search
            label = ingredient
            name = nil --> "generic" (remember than "generic" will match any other name)
        end

        local how_many_needed = #sub_table
        local how_many_in_inv = module.virtual_inventory:howMany(lable, name)
        local how_many_can_craft = math.floor(how_many_in_inv / how_many_needed)
        if how_many_can_craft < how_much_to_craft then -- no bueno
            print(comms.robot_send("error", "how many can craft: " .. how_many_can_craft .. " || " ..
                                   "how much to craft: " .. how_much_to_craft))
            local print_name = name
            local print_lable = lable
            if print_name == nil then print_name = "nil" end
            if print_lable == nil then print_lable = "nil" end

            print(comms.robot_send("error", "lable was: " .. print_lable .. " || name was: " .. print_name))
            print(comms.robot_send("error", "how many in inv was: " .. how_many_in_inv .. " || how many needed was: " .. how_many_needed))
            clean_up = true
            break
        end

        for _, c_table_slot in ipairs(sub_table) do
            -- this correction needs to be done because crafting table is 3 slots wide, but robot inventory is 4 slots wide
            if c_table_slot > 6 then c_table_slot = c_table_slot + 2
            elseif c_table_slot > 3 then c_table_slot = c_table_slot + 1 end

            local ingredient_slots = {}
            local accumulator = 0
            local i_slot_tbl = module.virtual_inventory:getAllSlots(lable, name)
            sort_table_indexed(i_slot_tbl, false, 2)
            if i_slot_tbl == nil then -- there has been an woopsie in the crafting/recipe/scripting
                print(comms.robot_send(
                    "error", string.format("While Crafting i_slot_tbl was nil, this means we didn't " ..
                    "have what we expected inside of the inventory: (l,n) -> (%s, %s)", lable, name)
                ))
                clean_up = true
                break
            end

            for _, inner_slot_obj in ipairs(i_slot_tbl) do
                local inner_slot = inner_slot_obj[1]
                local slot_size = module.virtual_inventory:howManySlot(inner_slot)
                accumulator = accumulator + slot_size
                table.insert(ingredient_slots, inner_slot)

                if accumulator >= how_much_to_craft then
                    break
                end
            end
            if accumulator < how_much_to_craft then
                clean_up = true
                break
            end

            local reverse_accumulator = how_much_to_craft
            local do_break = false
            for _, i_slot in ipairs(ingredient_slots) do -- usually we'll only iterate once, but we never know!
                local slot_size = module.virtual_inventory:howManySlot(i_slot)
                local to_transfer = math.min(reverse_accumulator, slot_size)

                local result = robot.select(i_slot)
                if result ~= i_slot or not robot.transferTo(c_table_slot, to_transfer) then
                    print(comms.robot_send("error", "something went wrong in self_crafting"))
                    clean_up = true
                    do_break = true
                    break
                end -- else we succeded! (yay!)
                module.virtual_inventory:removeFromSlot(i_slot, to_transfer) -- it's ok to overshoot!
                -- reverse_accumulator = reverse_accumulator - slot_size
                reverse_accumulator = reverse_accumulator - to_transfer
            end
            if reverse_accumulator ~= 0 then print(comms.robot_send("warning", "r_accumulator was: " .. reverse_accumulator)) end
            if do_break then break end
        end
    end -- Then check for errors
    if clean_up then
        print(comms.robot_send("error", "Error while crafting, cleaning up"))
        module.force_update_vinv()
        for index = 1, 12, 1 do
            if index % 4 ~= 0 then module.simple_slot_check(index) end
        end
        return false
    end

    -- Now the virtual crafting-table should be assembled, lets do the thing!
    local output_slot = module.virtual_inventory:getSmallestSlot(output.lable, output.name)
    if  output_slot == nil
        or module.virtual_inventory:howManySlot(output_slot) + how_much_to_craft > 64
    then
        output_slot = module.virtual_inventory:getEmptySlot(get_forbidden_table())
    end

    if output_slot == nil then error(comms.robot_send("fatal", "assert failed!")) end

    robot.select(output_slot)
    local result = crafting_component.craft(64)     -- craft as many as possible, in case of gross oversight
                                                    -- this should at least crash hard

    if not result then
        print(comms.robot_send("error", "failed to craft :("))
        module.force_update_vinv() -- last hurah-ass
        for index = 1, 12, 1 do
            if index % 4 ~= 0 then module.simple_slot_check(index) end
        end

        return false
    end

    -- TODO make it not use getStackInInternalSlot se we're a bit faster (it'll require better recipe programming)
    local stack_rep = inventory.getStackInInternalSlot(output_slot)
    local new_quantity = stack_rep.size

    local update_name = output.name
    local update_lable = output.lable
    if update_name == nil then update_name = stack_rep.name end
    if update_lable == nil then update_lable = stack_rep.label end

    -- Optimistically Update the thingy-majig
    module.virtual_inventory:forceUpdateSlot(update_lable, update_name, new_quantity, output_slot)

    robot.select(1)
    return true
end--]]
