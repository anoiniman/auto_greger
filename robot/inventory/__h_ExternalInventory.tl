require("build.MetaBuild.__h_init")
require("inventory.eInvItem")
require("inventory.CompressedVinventory")

-- storage compared to being a production inventory that consumes items
-- long_term_storage compared to being an inventory associated with this 1 specific building
global interface ExternalInventory
    parent_build: Build | nil
    
    item_defs: {eInvItem}
    storage: boolean
    long_term_storage: boolean

    ledger: CompressedVinventory
    symbol: string
    special_block_index: integer
end
