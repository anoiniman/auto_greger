global enum TSymbolExtra
    "break_shovel"
end

global interface InnerTransSymbol
    item: ItemDefinition
    extra: {TSymbolExtra} | nil
end
-- Can be a table data type or just a raw string where string == item_label
global type TransSymbol = InnerTransSymbol | string
