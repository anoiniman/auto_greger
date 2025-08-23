local Module = {parent = nil}

local deep_copy = require("deep_copy")
local meta_door = require("build.MetaBuild.MetaDoorInfo")
-- local general_functions = require("build.general_functions")
local generic_hooks = require("build.generic_hooks")


Module.name = "hole_home"

-- we'll need to place the chosen power generator since it is a non OpenOS part, but the rest we'll place by hand,
-- because... uhhhhh yeah, the rules, and then I guess locking ourselves in really is easier manually, eventually
-- we'll sub a door in I guess idk
Module.dictionary = {
    --["t"] = "Torch",
    ["d"] = {"nil", "any:grass"},
    ["a"] = {"air", "shovel"},
    ["s"] = {"air", "shovel"},
    ["o"] = "Object Observation Station (OOS)",
    ["r"] = "Radioisotope Thermoelectric Generator",
}

-- Orientation is assumed for sector 3 (x:-1,z:-1)
-- create rotation function somewhere
Module.base_table = {
    {
    "*o-----", -- OOS will be to the right of the * point, or atleast adjacent to it
    "a------",
    "a------",
    "-------",
    "-------",
    "-------",
    "-------",
    },
    {
    "-------",
    "a------",
    "a------",
    "a------",
    "-------",
    "-------",
    "-------",
    },
    {
    "-------",
    "-------",
    "a------",
    "a||||||",
    "a||||||",
    "-||||||",
    "-||||||",
    },
    {
    "-------",
    "-------",
    "-||||||",
    "a||||||",
    "a||||||",
    "a||||||",
    "-||||||",
    },
    {
    "-------",
    "-------",
    "-|||||r",
    "-||||||",
    "a||||||",
    "a||||||",
    "a||||||",
    },
    -- dirt floor here (hopefully) [lenght is 5]
}

Module.origin_block = {0,0,-5} -- x, z, y

Module.doors = {}
Module.doors[1] = meta_door:new()
Module.doors[1]:doorX(1,1)

Module.extra_sauce = {"top_to_bottom"}

function Module:new()
    return deep_copy.copy(self, pairs)
end

Module.shared_state = {
    fsm = 1,
    in_what_asterisk = 1,
    temp_reg = nil,

    in_building = false,
}

Module.state_init = {
    function()
        return Module.shared_state -- takes a ref
    end,
    function()
        return nil
    end
}

Module.hooks = {
    function(state, parent, flag, _quantity_goal, _state_table)
        return generic_hooks.std_hook1(state, parent, flag, Module.state_init[1], "hole_home")
    end,
    function() -- empty, because all we need to do is move to the *
        return nil
    end,
}
return Module
