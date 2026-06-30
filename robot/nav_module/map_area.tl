local helper = require("nav_module.Area")
local record module 
    area_table: AreaTable<NamedArea>
end

-- local area_table: AreaTable<NamedArea> = helper.area_table_new()
module.area_table = helper.area_table_new()
return module
