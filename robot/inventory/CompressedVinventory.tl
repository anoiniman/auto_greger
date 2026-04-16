require("deep_copy")
local vinv_helper = require("inventory.VirtualInventory")
local record module end

global interface CompressedVinventory
    original_size: integer
    inv_table: {string | integer}
end

function module.compress(vinv: VirtualInventory): CompressedVinventory
    local table_size: integer = vinv.table_size
    local pivot_point: integer = 0

    local inv_table = vinv.inv_table
    for index = table_size, 3, -3 do
        if inv_table[index] ~= 0 then pivot_point = index; break; end
    end

    local new_table: {string | integer} = {}
    for index = 1, pivot_point, 3 do
        new_table[index] = inv_table[index] 
        new_table[index + 1] = inv_table[index + 1] 
        new_table[index + 2] = inv_table[index + 2] 
    end

    return {
        original_size = table_size,
        inv_table = new_table
    }
end

function module.uncompress(cvinv: CompressedVinventory): VirtualInventory
    return vinv_helper.from_partial(cvinv.inv_table, cvinv.original_size) 
end


return module
