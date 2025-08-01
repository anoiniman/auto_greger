-- Things to do after exit is called
local comms = require("comms")
local deep_copy = require("deep_copy")
local search_table = require("search_table")

local keep_alive = require("keep_alive")

local map = require("nav_module.map_obj")
local nav = require("nav_module.nav_obj")
local inv = require("inventory.inv_obj")
local reas = require("reasoning.reasoning_obj")

local serialize = require("serialization")
local io = require("io")
local filesystem = require("filesystem")

local module = {}

-- This will be where we do the saving the state things
function module.exit()
    keep_alive.prepare_exit()
    module.save_state()
end

-- returns table of different indexes (useless right now)
local function compare_tables(old, new)
    local diff = {}
    for index, inner in ipairs(new) do
        local old_inner = old[index]
        if old_inner == nil then table.insert(diff, index); goto continue end

        if type(inner) == "table" then
            local inner_diff = compare_tables(old_inner, inner)
            if inner_diff ~= nil then table.insert(diff, inner_diff) end
            goto continue
        end
        if inner ~= old_inner then table.insert(diff, index) end

        ::continue::
    end
    return diff
end

local function save_thing(path, obj, extra)
    if filesystem.exists(path) then filesystem.remove(path) end
    local file = io.open(path, "w")
    local new = obj.get_data(extra)
    -- hacking because this shit's stupid, hope this doesn't cuse RAM issues in the future
    new = deep_copy.copy_no_functions(new)

    local serial = serialize.serialize(new, false)
    file:write(serial)
    file:close()
end

local save_home = "/home/robot/save_state"
local inv_path = save_home .. "/inv.save"
local map_path = save_home .. "/map.save"
local nav_path = save_home .. "/nav.save"
local reas_path = save_home .. "/reas.save"


function module.save_state(options)
    if not filesystem.isDirectory(save_home) then
        filesystem.makeDirectory(save_home)
    end
    save_thing(inv_path, inv)
    save_thing(map_path, map)
    save_thing(nav_path, nav, map)
    save_thing(reas_path, reas)
end

local function load_thing(path, obj, extra)
    if not filesystem.exists(path) then return end
    local file = io.open(path, "r")
    local serial = file:read("*a")
    if serial == nil then
        print(comms.robot_send("error", "failed to read save file: " .. path))
        return
    end

    local big_table = serialize.unserialize(serial)
    if big_table == nil then
        print(comms.robot_send("error", "failed to de-serialize save file: " .. path))
        return
    end

    obj.re_instantiate(big_table, extra)
end

local function do_presets(obj, extra)
    obj.load_preset(extra)
end

function module.load_state(exclude)
    if not filesystem.isDirectory(save_home) then
        return
    end
    if not search_table.ione(exclude, "-inv") then load_thing(inv_path, inv) end
    if not search_table.ione(exclude, "-map") then load_thing(map_path, map) end
    if not search_table.ione(exclude, "-nav") then load_thing(nav_path, nav, map) end
    if not search_table.ione(exclude, "-reas") then load_thing(reas_path, reas) end

    if not search_table.ione(exclude, "-auto") then
        do_presets(map)
        do_presets(inv, map)
    end
end


return module
