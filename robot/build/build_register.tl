local Build = require("build.MetaBuild")
local record build_register
    known_buildings: {string : {Build}}
end

function build_register.get_buildings(name: string): {Build}
    return known_buildings[name]
end

function build_register.get_buildings_num(name: string): boolean
    if known_buildings[name] == nil then return 0 end

    return #known_buildings[name]
end

return build_register
