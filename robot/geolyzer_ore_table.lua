-- I've, found out the the "color" value of a ore maps directly to its "Harvest_Level" value
-- So let's just use "Harvest_Level" analysis for an inital analysis of what we've just "found"
-- And If we can't mine at the moment we simple return that we can't mine at the moment
local module = {
    ["7340544"] = {"copper", "pyrite", "chalcopyrite"}, -- Harvest_Level == 1
    ["7368816"] = {"iron", "magnetite", "vanadium_magnetite", "gold"}, -- 2
}


return module
