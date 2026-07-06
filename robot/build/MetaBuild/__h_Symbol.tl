require("Position")
require("inventory.__h_Item")
global enum TSymbolExtra
    "break_shovel"
end

global interface InnerTransSymbol
    item: ItemDefinition
    extra: {TSymbolExtra} | nil
end
-- Can be a table data type or just a raw string where string == item_label
global type TransSymbol = InnerTransSymbol | string

global interface BaseFormat is {{string}} default: {string} end
global type SubSegment = {string, Pos2D}
global type SegmentArray = {integer : {SubSegment}}

