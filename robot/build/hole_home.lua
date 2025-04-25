local module = {parent = nil}

function module:init(n_parent)
    if self.parent ~= nil then return self end
    self.parent = n_parent
end


return
