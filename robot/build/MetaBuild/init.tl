--local math = require("math")
--local serialize = require("serialization")
local comms = require("comms")
require("deep_copy")
require("nav_module.chunk_coord")
require("Task")

local nav = require("nav_module.nav_obj")

require("inventory.__h_ExternalInventory")
require("build.MetaBuild.__h_init")
local general_functions = require("build.general_functions")
require("build.MetaBuild.SchematicInterface")
-- local vinv_helper = require("inventory.VirtualInventory")

local record module end
local type C = CoordinateType

function module.empty(name: string): Build
    return {
        name = name,
        chunk = {0, 0},
        height = 1,
        quad = -1,

        offset = {0 as C.X, 0 as C.Z, 0 as C.Y},
        doors = {},
        special_blocks = {},
    }
end

function module.new(name: string, chunk: ChunkCoord, height: integer, quad: integer): Build
    return {
        name = name,
        chunk = chunk,
        height = height,
        quad = quad,

        offset = {0 as C.X, 0 as C.Z, 0 as C.Y},
        doors = {},
        special_blocks = {},
    }
end

function module.get_special_coords(build: Build, what_symbol: SpecialSymbol, index: integer): Pos3D | nil
    local coords, _ = general_functions.count_occurence_of_symbol(what_symbol, index, build.special_blocks)
    if coords is SpecialSchematicChunk then
        return {coords[2] as C.X, coords[3] as C.Z, coords[4] as C.Y} -- this is effectifly a deep_copy
    end
    return nil
end

function module.get_dist_to_special(build: Build, what_symbol: SpecialSymbol, index: integer): integer | nil
    local coords, _ = general_functions.count_occurence_of_symbol(what_symbol, index, build.special_blocks)
    if coords is SpecialSchematicChunk then
        local x, z, y = coords[2], coords[3], coords[4]
        local cabs_x = build.chunk[1] * 16
        local cabs_z = build.chunk[2] * 16

        x = x + cabs_x
        z = z + cabs_z
        local cur_abs = nav.get_abs()
        local dist_x = math.abs(x - cur_abs[1])
        local dist_z = math.abs(z - cur_abs[2])
        local dist_y = math.abs(y - nav.get_height())

        local man_dist = dist_x + dist_z + dist_y
        return man_dist
    end
    return nil
end

local type SSC = SpecialSchematicChunk
-- no need to rotate since they are already pre-rotated from before
function module.translate_special(build: Build, quad_num: integer, logical_chunk_height: integer, primitive_offset: Pos3D): boolean
    local special_table = build.special_blocks

    --[[print(string.format("Name is: %s", self.name))
    local a_special = special_table[1]
    local str = string.format("Special was: [%s] (%s, %s) h:%s", a_special[1], a_special[2], a_special[3], a_special[4])
    print(str)
    io.read()--]]

    local function case_one(special: SSC)
        special[2] = special[2] + 8 -- x
        special[3] = special[3] + 1 -- z
    end
    local function case_two(special: SSC)
        special[2] = special[2] + 1 -- x
        special[3] = special[3] + 1 -- z
    end
    local function case_three(special: SSC)
        special[2] = special[2] + 1 -- x
        special[3] = special[3] + 8 -- z
    end
    local function case_four(special: SSC)
        special[2] = special[2] + 8 -- x
        special[3] = special[3] + 8 -- z
    end

    local case_function: function(SSC)
    if quad_num == 1 then
        case_function = case_one
    elseif quad_num == 2 then
        case_function = case_two
    elseif quad_num == 3 then
        case_function = case_three
    elseif quad_num == 4 then
        case_function = case_four
    else
        print(comms.robot_send("error", "MetaBuild rotateSpecial impossible quad_num: " .. quad_num))
        return false
    end


    for _, special in ipairs(special_table) do
        special[4] = special[4] + logical_chunk_height - 1 -- adds height to le thing (- 1 because idk you just need to)
        case_function(special)

        special[2] = special[2] + primitive_offset[1]
        special[3] = special[3] + primitive_offset[2]
        special[4] = special[4] + primitive_offset[3]
    end

    --[[local special = special_table[1]
    local str = string.format("Special now is: [%s] (%s, %s) h:%s", special[1], special[2], special[3], special[4])
    print(str)
    print()
    io.read()--]]

    return true
end

--[[
function module.get_inventories(build: Build): {ExternalInventory} | nil
    if build.build_task == nil then return nil end
    return bt_helper.get_attached_inventories(build.build_task)
end

function module.run_build_check(build: Build, quantity_goal: integer): CheckResult
    -- self:useBuilding(nil, "only_check", nil, quantity_goal, nil, nil)
    return bt_helper.run_check(build.build_task)
end

function module.create_and_return_ledger(build: Build): VirtualInventory
    -- We could try to pre-add-up every block by looping through the sinterface multiple times, and only
    -- then increment the ledger entries, or we could just loop once and increment the ledger entries
    -- 1-by-1, I don't know what solution is best, so I'll just use the easier one
    local tmp_ledger = vinv_helper.new(64)

    local result, status, instruction
    while true do -- TODO got to think about this
        error("TODO")
        result, status, instruction = self:doBuild()
        if not result then error(comms.robot_send("fatal", "Failed to doBuild in createLedger, name is -- " .. self.name)) end
        if status == "done" then break end

        local block_name = instruction.block_info.name
        local block_lable = instruction.block_info.lable

        tmp_ledger:addOrCreate(block_lable, block_name, 1)
    end

    return tmp_ledger
end
--]]

return module
