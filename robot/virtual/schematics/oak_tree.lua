local module = {}

function module.generate(KnownBlocks)
    if KnownBlocks == nil then error("Known Blocks nil") end

    local tree_dictionary = {
        ["o"] = KnownBlocks:getByLabel("Oak Wood") or KnownBlocks:default(),
        ["/"] = KnownBlocks:getByLabel("Oak Leaves") or KnownBlocks:default(),
    }

    local tree_schematic = {
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

    local relative_offset = {
        -3,
        -4,
        -1,
    }

    local return_table = {tree_schematic, tree_dictionary, relative_offset}
    return return_table
end

return module
