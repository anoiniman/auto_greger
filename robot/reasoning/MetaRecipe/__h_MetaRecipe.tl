require("Task")
require("inventory.__h_Item")

-- This state_primitive bullshitery and what not seems quite poorly designed, we'll need to revise that for v2
-- only gathering uses that stupid crap anyway

-- Whole recipe get copied/cloned by the caller so that state is not changed in the primitive object for a given recipe
-- this decouples the definition of behaviour and data structure from its execution and state-change when in-vivo.
-- Of course, this relies on the caller properly clonning us, but we don't really have a good way to enforce this
-- from within MetaRecipe itself, so just be very very careful ok?
--
-- output must be ItemDefinition
global type MetaDependency;
global interface MetaRecipe
    output: ItemDefinition
    output_quantity: integer
    dependencies: {MetaDependency}

    task_prototype: TaskPrototype
end

-- global type ToolLevel = integer
global type ToolTuple = {ToolType, ToolLevel}
global interface Gathering is MetaRecipe
    tools: {ToolTuple}
end

-- Maybe make it so that once there is a crafting area in the base (maybe with a "cache"-like storage included
-- in such an area) the robot will no longer use/keep empty reserved it's internal crafting slot, and instead
-- fully relies on the base's crafting areas, because of the possible "caching" effect, and freeing up
-- robot internal inventory space this might be an amazing idea
global type charNil = string | nil
global type craftingGrid = {
        charNil, charNil, charNil,
        charNil, charNil, charNil,
        charNil, charNil, charNil
}

global type ItemDefOrNil = ItemDefinition | nil
global type recipeGrid = {
    ItemDefOrNil, ItemDefOrNil, ItemDefOrNil,
    ItemDefOrNil, ItemDefOrNil, ItemDefOrNil,
    ItemDefOrNil, ItemDefOrNil, ItemDefOrNil
}

global interface CraftingTable is MetaRecipe
    crafting_grid: recipeGrid
end

global interface CraftingState is TaskState
    recipe_grid: recipeGrid
    output: ItemDefinition
    repeats: integer
end

global interface BuildingUser is MetaRecipe
    bd_name: string
    usage_flag: string
end

global record RecipeSpecification
    priority: integer
    up_to_quantity: integer
end
