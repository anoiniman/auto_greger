-- NAH, we won't need this I'll just use the table hashmap for what I want, lmao, bad day today
local comms = require("comms")

local record helper end
local interface Node<T>
    obj: T
    left: Node<T> | nil
    right: Node<T> | nil
end

global interface BinaryTree<T, Q>
    head: Node<T>

    lt_cmpT: function(T, T): boolean
    eq_cmpT: function(T, T): boolean

    lt_cmpQT: function(Q, T): boolean
    eq_cmpQT: function(Q, T): boolean

    ir_counter: integer
end

function helper.newTree<T, Q>(
    head_obj: T,
    lt_cmpT: function(T, T): boolean,
    eq_cmpT: function(T, T): boolean,
    lt_cmpQT: function(Q, T): boolean,
    eq_cmpQT: function(Q, T): boolean
): BinaryTree<T, Q>
    return {
        head = {obj = head_obj},

        lt_cmpT = lt_cmpT,
        eq_cmpT = eq_cmpT,

        lt_cmpQT = lt_cmpQT,
        eq_cmpQT = eq_cmpQT,
    }
end

function helper.insert<T, Q>(tree: BinaryTree<T, Q>, new_obj: T): boolean
    if tree.head == nil then tree.head = {obj = new_obj} end

    local node = tree.head
    local parent: Node<T>
    while node ~= nil do
        parent = node
        if tree.eq_cmpT(new_obj, node.obj) then
            error(comms.robot_send("fatal", "code in proper debugging messages"))
            -- print(comms.robot_send("Warning", "failed to add object, already exists" .. new_obj))
            return false
        end

        if tree.lt_cmpT(new_obj, node.obj) then
            node = node.left 
        else
            node = node.right
        end
    end

    if tree.lt_cmpT(new_obj, parent.obj) then
        node.left = {obj = new_obj}
    else
        node.right = {obj = new_obj}
    end
    return true
end

function helper.get<T, Q>(tree: BinaryTree<T, Q>, term: Q): T | nil
    local node = tree.head
    while node ~= nil and not tree.eq_cmpQT(term, node.obj) do
        if tree.lt_cmpQT(term, node.obj) then
            node = node.left
        else
            node = node.right
        end
    end

    if node == nil then return nil end
    return node.obj
end

local enum LorR
    "left"
    "right"
end

local function successor<T, Q>(tree: BinaryTree<T, Q>, node: Node<T>, parent: Node<T>): Node<T>, LooR
     if node.right ~= nil then
         return BST-Minimum(node.right)
     end

     local value: T = node.obj
     

     local other = parent
     while other ~= nil and node = other.right do
         node = other
         other = other.parent
     repeat
     return y

end

function helper.remove<T, Q>(tree: BinaryTree<T, Q>, term: Q): boolean
    local lorr = "left"
    local parent: Node<T>
    local node = tree.head
    while node ~= nil and not  do
        if tree.eq_cmpQT(term, node.obj) then
            if node.left == nil and node.right == nil then parent[lorr] = nil
            elseif node.left == nil and node.right ~= nil then
                parent[lorr] = node.right
            elseif node.left ~= nil and node.right == nil then
                parent[lorr] = node.left
            else

            end
        end

        parent = node
        if tree.lt_cmpQT(term, node.obj) then
            node = node.left
            lorr = "left"
        else
            node = node.right
            lorr = "right"
        end
    end
    return false
end

local do_test = false
if do_test then
    local lt_cmp = function(a: integer, b: integer): boolean return a < b end
    local eq_cmp = function(a: integer, b: integer): boolean return a == b end

    local tree: BinaryTree<integer, integer> = helper.newTree(10, lt_cmp, eq_cmp, lt_cmp, eq_cmp)
    helper.insert(tree, 9)
    helper.insert(tree, 20)
    helper.insert(tree, 13)
    helper.insert(tree, 4)

    print(helper.get(tree, 13))
end

return helper
