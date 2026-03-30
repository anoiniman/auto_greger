require("reasoning.MetaRecipe.__h_MetaRecipe")

local deep_copy = require("deep_copy")
local comms = require("comms")

-- local serialize = require("serialization")
local computer = require("computer")

local build_eval = require("eval.build")
-- local inv = require("inventory.inv_obj")
local crafting = require("inventory.crafting")
local item_buckets = require("inventory.item_buckets")

local record module end

local function new_meta_recipe(
    output: ItemDefinition,
    output_quantity: integer,
    dependencies: {MetaDependency},
    task_prototype: TaskPrototype
): MetaRecipe
    return {
        output = output,
        output_quantity = output_quantity,
        dependencies = dependencies,

        task_prototype = task_prototype
    }
end

function module.new_crafting_table(
    output: ItemDefinition,
    output_quantity: integer,
    dependencies: {MetaDependency},

    dictionary_ref: {string : ItemDefinition},
    crafting_grid: craftingGrid
): CraftingTable
    local crafting_routine = coroutine.create(crafting.craft)
    local crafting_prototype = 
    local parent = module.new_meta_recipe(output, output_quantity, dependencies, crafting_prototype)

    local new: CraftingTable = {} as CraftingTable
    for k, v in pairs(parent as {any : any}) do new[k] = v end

    local recipe_grid = {}
    for index, char in ipairs(crafting_grid) do
        local char = crafting_grid[index]

        local item_def
        if char == nil then item_def = nil
        else item_def = dictionary_ref[char] end

        recipe_grid[index] = item_def
    end
    new.recipe_grid = recipe_grid
    
    return new
end

-- Need to add: scaling with needed output
function module.instantiate(recipe_template: MetaRecipe, recipe_specification: RecipeSpecification): TaskHandle
    task_helper.instantiate(recipe_template.task_prototype)
end

return module
