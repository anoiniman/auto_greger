require("inventory.__h_VirtualInventory")

local record InvObj
    virtual_inventory: VirtualInventory

    is_crafting_clear: function(): boolean
    get_forbidden_table: function(): {integer}
    force_update_vinv: function()
    simple_slot_check: function(integer)
end

--[[ For the future
is_crafting_clear: function(self): boolean
get_forbidden_table: function(self): {integer}
force_update_vinv: function(self)
simple_slot_check: function(self, integer)
--]]

return InvObj
