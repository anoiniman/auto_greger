-- local KnownBlocks = require("virtual.items.KnownBlocks")
local Position = require("virtual.Position")
local BlockTypes = require("virtual.Block.implementation")
require("virtual.Block")

local Block = BlockTypes[1]
local KnownBlocks = BlockTypes[2]

local record module end

function module.generate(known_blocks: KnownBlocks): { {{string}}, {string : Block}, Position }
    local tree_dictionary: {string : Block} = {
        ["o"] = known_blocks:getByLabel("Oak Wood") or known_blocks:default(),
        ["/"] = known_blocks:getByLabel("Oak Leaves") or known_blocks:default(),
    }

    local tree_schematic: {{string}} = {
        {
        "-------",
        "-------",
        "-------",
        "---o---",
        "-------",
        "-------",
        "-------",
        },
        {
        "-------",
        "-////--",
        "-/////-",
        "-//o//-",
        "-/////-",
        "-/////-",
        "-------",
        },
        {
        "-------",
        "-/////-",
        "-/////-",
        "-//o//-",
        "-/////-",
        "-/////-",
        "-------",
        },
        {
        "-------",
        "-------",
        "--///--",
        "-//o//-",
        "--///--",
        "-------",
        "-------",
        },
        {
        "-------",
        "-------",
        "--///--",
        "--///--",
        "--///--",
        "-------",
        "-------",
        },
    }

    local relative_offset: Position = Position:new(-3, -4, -1)

    local return_table = {tree_schematic, tree_dictionary, relative_offset}
    return return_table
end

return module
