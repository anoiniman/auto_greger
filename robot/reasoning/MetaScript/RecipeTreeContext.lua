local deep_copy = require("deep_copy")
local comms = require("comms")


local Node = {
    le_self = nil,
    children = nil,
}
function Node:new(le_self)
    local new = deep_copy.copy(self, pairs)
    new.le_self = le_self
    new.children = {}
    return new
end
function Node:addChild(other_node)
    table.insert(self.children, other_node)
end

---------------

local TreePath = {
    path = {},
    index = 0
}
function TreePath:new()
    return deep_copy.copy(self, pairs)
end

function TreePath:add(new_node)
    -- I'll be optimistic and say we don't need to add children here, I hope
    -- local latest_node = self.path[self.index]

    table.insert(self.path, new_node)
    self.index = self.index + 1
end
function TreePath:advance(child_index)
    local latest_node = self.path[self.index]
    if #latest_node.children == 0 then
        print(comms.robot_send("error", "Not expected:\n" .. debug.traceback()))
        return
    end

    local new_node = latest_node[child_index]
    if new_node == nil then print(comms.robot_send("error", "Invalid child_index")); return end

    table.insert(self.path, new_node)
    self.index = self.index + 1
end

----------------

-- I kinda started coding this thinking that we'd need to keep several paths in memory, but prob we'll only ever use one
local MetaContext = {
    ctx_head = nil,
    --paths = {},
    paths = {TreePath:new()},
    cur_path = 1
}
function MetaContext:new(raw_recipe)
    local head = Node:new(raw_recipe)
    local new = deep_copy.copy(self, pairs)
    new.ctx_head = head
    new.paths[1]:add(head)
    return new
end

function MetaContext:getLatestNode()
    local cur_path = self.paths[self.cur_path]
    local latest_node = cur_path.path[cur_path.index]
    return latest_node
end

function MetaContext:getParentNode()
    local cur_path = self.paths[self.cur_path]
    local parent_node = cur_path.path[cur_path.index - 1]
    return parent_node
end

function MetaContext:addDepth(more) -- moves forward index and adds to path
    local new_node = Node:new(more)
    local cur_path = self.paths[self.cur_path]

    cur_path:add(new_node)
end

-- Most Importantly, this adds children, but does not add to path, we only add to path after processing children
function MetaContext:addAllDeps(dep_tbl)
    if dep_tbl == nil then return end
    local latest_node = self:getLatestNode()
    for _, dep in ipairs(dep_tbl) do
        local new_node = Node:new(dep)
        latest_node:addChild(new_node)
    end
end

function MetaContext:addDep(dep)
    local latest_node = self:getLatestNode()
    local new_node = Node:new(dep)
    latest_node:addChild(new_node)
end


function MetaContext:checkForLoop(recipe_to_check)
    local cur_path = self.paths[self.cur_path]
    for index = 2, #cur_path.path, 1 do
        local node = cur_path.path[index]
        local le_recipe = node.le_self.inlying_recipe
        if le_recipe:includesOutput(recipe_to_check) then return true end
    end

    return false
end

function MetaContext:getCurNodeIndex()
    local cur_path = self.paths[self.cur_path]
    return cur_path.index
end

function MetaContext:unwind(node_index)
    local cur_path = self.paths[self.cur_path]
    local err_node = cur_path.path[node_index]
    local err_recipe = err_node.le_self.inlying_recipe

    local s_lable = err_recipe.output.lable
    local s_name = err_recipe.output.name
    if s_lable == nil then s_lable = "nil" end
    if s_name == nil then s_name = "nil" end

    print(string.format("Loop found in entry no.%d: (%s, %s)", node_index, s_lable, s_name))

    local match_node = nil
    -- we go until '2' because 1 (the root) is a special node that shouldn't be messed with
    for temp_index = node_index - 1, 2, -1 do
        local temp_node = cur_path[temp_index]
        local temp_recipe = temp_node.le_self.inlying_recipe

        if err_recipe:includesOutput(temp_recipe) and temp_node ~= err_node then
            print(string.format("Matches with entry no.%d", temp_index))
            match_node = temp_node
            break
        end
    end

    -- we only unwind if there was a match, so not re-finding the is worrying
    if match_node == nil then error(comms.robot_send("fatal", "assertion failed")) end
    if match_node.le_self.dep_type ~= "Optional" then error(comms.robot_send("fatal", "Todo?")) end
    return match_node.le_self.inlying_recipe
end

-----------------

return MetaContext
