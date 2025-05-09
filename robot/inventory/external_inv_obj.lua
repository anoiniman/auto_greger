local module = {}
local base_wide_ledger = {}

function module.add_to_ledger(name, quantity)
    local entry_quantity = internal_ledger[lable] -- shared code with internal storage, I'm not a dry-ad
    if entry_quantity == nil then
        entry_quantity = quantity
        return
    end
    entry_quantity = entry_quantity + quantity
end

return module
