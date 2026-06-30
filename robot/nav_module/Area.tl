local comms = require("comms")

local c_helper = require("nav_module.chunk_coord")
require("inventory.__h_Item")

local record module end

global interface Area
    chunk_coords: {ChunkCoord}
end

-- Names MUST be unique, they are ID's, IDENTIFIERS!
-- We do NOT store REFERENCES to child chunks, we only store their INDICES!
global interface NamedArea is Area
    name: string
    color: string
    height: integer
    floor_block: ItemDefinition
end

function module.named_area_new(name: string, color: string, height: integer, floor_block: ItemDefinition): NamedArea | nil
    if height == nil or height < 0 or height > 255 then
        print(comms.robot_send("error", "NamedArea:new -- invalid height"))
        return nil
    end

    return {
        name = name,
        color = color,
        height = height,
        floor_block = floor_block,
        chunk_coords = {},
    }
end
function module.add_chunk_to_area<T is Area>(area: T, what_chunk: ChunkCoord)
    for _, o_chunk in ipairs(area.chunk_coords) do -- checks if chunk is already added
        if c_helper.cmp_ccoords(what_chunk, o_chunk) then return end
    end
    table.insert(area.chunk_coords, what_chunk)
end

-- This is an interface purely for the generic type checking, otherwise it's jsut an array
global interface AreaTable<T is Area> is {T} end
function module.area_table_new<T is Area>(): AreaTable<T>
    return {}
end

function module.add_named_area(tbl: AreaTable<NamedArea>, new_area: NamedArea)
    for _, area in ipairs(tbl) do -- checks if the area is already added
        if area.name == new_area.name then return end
    end

    table.insert(tbl, new_area)
end

function module.is_chunk_in_area_table<T is Area>(tbl: AreaTable<T>, what_chunk: ChunkCoord): boolean
    for _, area in ipairs(tbl) do
        for _, area_chunk in ipairs(area.chunk_coords) do
            if c_helper.cmp_ccoords(what_chunk, area_chunk) then return true end
        end
    end
    return false
end
function module.get_named_area(tbl: AreaTable<NamedArea>, name: string): NamedArea | nil
    for _, area in ipairs(tbl) do
        if area.name == name then return area end
    end
    return nil
end

return module
