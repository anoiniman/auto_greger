local deep_copy = require("deep_copy")
local MetaRecipe = require("reasoning.MetaRecipe")

local MetaScript = {}
function MetaScript:new() return deep_copy.copy(self, pairs) end

-- TODO supersided by gathering-type recipe? Food for thought.
local Strategy = {func = nil, arguments_ref = {}}
function Strategy:new() return deep_copy.copy(self, pairs) end
function Strategy:set(func, arguments_ref)
    self.func = func; self.arguments_ref = arguments_ref
end

function Strategy:call()
    return self.func(self.arguments_ref)
end

local RequirementEnum = {
    Item = {},
    Building = {},
}
local Requirement = {}

-- constraints are immaterial, inputs are material
local Goal = {constraints = {}, recipe = nil priority = 0, strategy = Strategy:new()}
function Goal:new() return deep_copy.copy(self, pairs) end

function Goal:try_step(env)
    return self.strategy()
end

local MSBuilder = {base_script = MetaScript:new()}
function MSBuilder:new() return deep_copy.copy(self, pairs) end

function MSBuilder:addGoal(goal)

end

return MSBuilder, Goal, Requirement
