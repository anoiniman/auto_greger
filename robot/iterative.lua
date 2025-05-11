local module = {}

ITERATIVE_WAIT_LIST = {}
function module.add(to_add)
    table.insert(ITERATIVE_WAIT_LIST, to_add) 
end

return module
