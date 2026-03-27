-- luacheck: globals REASON_WAIT_LIST

local deep_copy = require("deep_copy")
local comms = require("comms")

-- luacheck: push ignore
local serialize = require("serialization")
-- luacheck: pop
local computer = require("computer")

local build_eval = require("eval.build")
local inv = require("inventory.inv_obj")
local item_buckets = require("inventory.item_buckets")

local record module end

-- This state_primitive bullshitery and what not seems quite poorly designed, we'll need to revise that for v2
-- only gathering uses that stupid crap anyway

-- Whole recipe get copied/cloned by the caller so that state is not changed in the primitive object for a given recipe
-- this decouples the definition of behaviour and data structure from its execution and state-change when in-vivo.
-- Of course, this relies on the caller properly clonning us, but we don't really have a good way to enforce this
-- from within MetaRecipe itself, so just be very very careful ok?
--
-- output must be ItemDefinition
local interface MetaRecipe
    output: ItemDefinition,
    output_quantity: integer,
    dependencies: {MetaDependency},

    task_prototype: TaskPrototype,
end

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

local type ToolLevel = integer
local type ToolTuple = {ToolType, ToolLevel}
local interface Gathering is MetaRecipe
    tools: {ToolTuple},
end

-- Maybe make it so that once there is a crafting area in the base (maybe with a "cache"-like storage included
-- in such an area) the robot will no longer use/keep empty reserved it's internal crafting slot, and instead
-- fully relies on the base's crafting areas, because of the possible "caching" effect, and freeing up
-- robot internal inventory space this might be an amazing idea
local type charNil = string | nil
local type craftingGrid = {
        charNil, charNil, charNil
        charNil, charNil, charNil
        charNil, charNil, charNil
}

local interface CraftingTable is MetaRecipe
    dictionary_ref: {string : ItemDefinition}
    crafting_recipe: craftingGrid
end

local function craft_function(state: TaskState): TaskState

end

function module.new_crafting_table(
    output: ItemDefinition,
    output_quantity: integer,
    dependencies: {MetaDependency},
    -- task_prototype: TaskPrototype,

    dictionary_ref: {string: ItemDefinition},
    crafting_recipe: craftingGrid
): CraftingTable
    local parent = module.new_meta_recipe(output, output_quantity, dependencies, crafting_prototype)
    local new: CraftingTable = {} as CraftingTable
    for k, v in pairs(parent as {any : any}) do new[k] = v end
    new.dictionary_ref = dictionary_ref
    new.crafting_recipe = crafting_recipe
    
    return new
end

local interface BuildingUser is MetaRecipe
    bd_name: string
    usage_flag: string
end

local record RecipeSpecification
    priority: integer
    up_to_quantity: integer
end

-- function module.returnCommand(priority: integer, lock_ref: SharedLock, up_to_quantity: integer)
function module.returnTaskHandle(recipe_template: MetaRecipe, recipe_specification: RecipeSpecification): TaskHandle

end

function module.returnCommand(priority, lock_ref, up_to_quantity, extra_info, dictionary):
    -- This gathering bullshit is the buggiest, hackiest stuff around, makes sense since it was the first thing I did, but
    -- holy shit, I should've been way way way smarter.
    if self.meta_type == "gathering" then
        -- state probabily needs to be copied over no matter what (whenever we create/start a new gathering instance)
        -- to stop the pie from getting contaminated

        -- self.state.priority = priority
        self.state.priority = 100   -- I guess that the priority of a gathering once we start doing one should always be 100
                                    -- we should as well certify that only one gathering occurs at a time, but that is a little
                                    -- bit more difficult to certify, I just hope that this priority trick is enough
        -- even though we set the state.priority as 100 we keep the regular priority as whatever was defined in the goal
        -- this means that the command will be handled as normal BEFORE we start executing the gathering, but once we
        -- start gathering there is no stopping until we finish the gathering!
        return {priority, self.mechanism.algorithm, self.mechanism, deep_copy.copy(self.state), up_to_quantity, lock_ref }
    elseif self.meta_type == "building_user" then
        -- here extra info should be a ref to the building we need to use
        local build = extra_info
        if build == nil then error(comms.robot_send("fatal", "MetaRecipe:returnCommand, extra_info was nil when it shouldn't")) end

        local usage_flag = self.mechanism.usage_flag
        local hook_exec_index = 1


        local check_table = nil
        if self.dependencies ~= nil then
            local one_dep = self.dependencies[1]
            local one_recipe = one_dep.inlying_recipe

            local dep_quantity = math.ceil(one_dep.input_multiplier * up_to_quantity)
            check_table = {one_recipe.output, dep_quantity}
        end

        -- callee then determins how many inputs are needed and does all the inventory management
        -- reasoning should not be doing any invenotry management fr fr
        local r_table = {priority, build_eval.use_build, build, usage_flag, hook_exec_index, check_table, priority, lock_ref}
        --[[for k, v in pairs(r_table) do
            if v == nil then v = "nil"
            elseif type(v) == "table" then v = "table"
            elseif type(v) == "function" then v = "function" end
            print(comms.robot_send("debug", k .. ", " .. v))
        end--]]
        return r_table
    elseif self.meta_type == "crafting_table" then
        -- seems good? All that is missing is a mechanism that limites the batch size for a craft
        -- (so that we don't try and craft 234 things at once for example) -- add this to the mechanism?!
        return {priority, inv.craft, dictionary, self.mechanism.crafting_recipe, self.output, up_to_quantity, lock_ref}
    elseif self.meta_type == "empty_recipe" or self.meta_type == "hold_recipe" then
        if self.mechanism[1] - computer.uptime() >= 120 then
            local r_lable = self.output.lable
            local r_name = self.output.name
            if r_lable == nil then r_lable = "nil" end
            if r_name == nil then r_name = "nil" end

            print(comms.robot_send("warning", string.format("Arrived at empty recipe for: %s, %s", r_lable, r_name)))
            self.mechanism[1] = true
        end

        -- lock_ref[1] = 0 -- force reset!
        -- return nil
        return "wait"
    else
        error(comms.robot_send("fatal", "Unimplemented meta_type selected for returnCommand in MetaRecipe: \""
            .. self.meta_type .. "\""))
    end
end

return module
