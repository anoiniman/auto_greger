require("reasoning.MetaRecipe.__h_MetaRecipe")

local comms = require("comms")

local task_helper = require("Task")
local item_helper = require("inventory.__h_Item")

-- local build_eval = require("eval.build")
local crafting = require("inventory.crafting")

local record module end

global type MetaDependency;
local function new_meta_recipe<S is TaskState, T is MetaRecipe<S>>(
    output: ItemDefinition,
    output_quantity: integer,
    dependencies: {MetaDependency},
    task_prototype: TaskPrototype,

    state_generator: function(T, integer): S
): MetaRecipe<S>
    if output.label == nil then error(comms.robot_send("fatal", "Bad meta recipe no label")) end
    return {
        output = output,
        output_quantity = output_quantity,
        dependencies = dependencies,

        task_prototype = task_prototype,
        state_generator = state_generator
    }
end

function module.new_crafting_table(
    priority: integer,

    output: ItemDefinition,
    output_quantity: integer,
    dependencies: {MetaDependency},

    dictionary_ref: {string : ItemDefinition},
    crafting_grid: craftingGrid
): CraftingTable
    local recipe_grid: {ItemDefinition | nil} = {}
    for index, char in ipairs(crafting_grid) do
        local item_def: ItemDefinition
        if char == nil then item_def = nil
        else item_def = dictionary_ref[char] end

        recipe_grid[index] = item_def
    end

    local function s_generator<S is TaskState>(crafting_table: CraftingTable<S>, repeats: integer): CraftingState
        local old_output = crafting_table.output
        local new_output = item_helper.new_fuller_definition(
            old_output.label,
            old_output.name,
            repeats,
            old_output.stack_size
        )

        return {
            recipe_grid = crafting_table.recipe_grid,
            output = new_output,
        }
    end

    local crafting_prototype = task_helper.new_prototype(priority, crafting.craft)
    local parent = new_meta_recipe(output, output_quantity, dependencies, crafting_prototype, s_generator)
    local new: CraftingTable<CraftingState> = {} as CraftingTable<CraftingState>

    for k, v in pairs(parent as {any : any}) do (new as {any : any})[k] = v end
    new.recipe_grid = recipe_grid
    
    return new
end

-- output_quantity field needs to do something for when we are "calculating" how many repetitions are needed for
-- crafting table action, will a simple math.floor be enough, or should the task of doing this be relegated to
-- recipe tree resolution? Probably here?
function module.instantiate<S is TaskState>(recipe_template: MetaRecipe<S>, quantity: integer)
    task_helper.instantiate(recipe_template.task_prototype, recipe_template, quantity)
end

return module
