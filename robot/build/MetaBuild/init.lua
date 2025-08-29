--local math = require("math")
--local serialize = require("serialization")
local filesystem = require("filesystem")

local comms = require("comms")
local deep_copy = require("deep_copy")

local nav = require("nav_module.nav_obj")

local general_functions = require("build.general_functions")
local SchematicInterface = require("build.MetaBuild.SchematicInterface")
local VirtualInventory = require("inventory.VirtualInventory")


local primitive_cache = {}  -- as you might have noticed this value exists outside the MetaTable(s)
                            -- so it exists as a singleton all "inheritors" of the MetaTable have the same
                            -- reference for "build_cache"

local Module = {
    name = nil,
    extra_sauce = nil,
    what_chunk = nil, -- It's not a ref, they're coordinates to the chunk

    post_build_s_init = nil,
    post_build_hooks = nil,
    post_build_state = nil,

    is_nil = true,
    built = false,
    doors = nil,
    special_blocks = nil,

    primitive = {},
    s_interface = nil
}

function Module:new()
    return deep_copy.copy(self, pairs)
end

function Module:doBuild()
    if self.s_interface == nil then
        print(comms.robot_send("error", "MetaBuild, doBuild, attempted to build with nil s_interface, init plz"))
        return false
    end

    local reverse = self:is_extra("top_to_bottom")
    local result, status, instruction = self.s_interface:doBuild(reverse) -- string, 3d-coords, symbol

    if self.extra_sauce ~= nil then -- for now this is fine
        for _, str_name in ipairs(self.extra_sauce) do
            instruction.addExtra(str_name, nil)
        end
    end

    return result, status, instruction
end

function Module:is_extra(str)
    if self.extra_sauce == nil then return false end

    local result = false
    for _, sauce in ipairs(self.extra_sauce) do
        if type(sauce) == "table" then
            error(comms.robot_send("fatal", "not implemented yet, MetaBuild is_extra (use the included method in the instruction?)"))
            if sauce[1] == "do_wall" then
                error("shutup the luacheck")
            end -- etc
        end

        if sauce == str then
            result = true
            break
        end

        --::continue::
    end
    return result
end

function Module:getSpecialCoords(what_symbol, index)
    local coords, _ = general_functions.count_occurence_of_symbol(what_symbol, index, self.special_blocks)
    return {coords[1], coords[2], coords[3]} -- this is effectifly a deep_copy
end

function Module:getDistToSpecial(what_symbol, index)
    local coords, _ = general_functions.count_occurence_of_symbol(what_symbol, index, self.special_blocks)
    local x, z, y = coords[1], coords[2], coords[3]
    local cabs_x = self.what_chunk[1] * 16
    local cabs_z = self.what_chunk[2] * 16

    x = x + cabs_x
    z = z + cabs_z
    local cur_abs = nav.get_abs()
    local dist_x = math.abs(x - cur_abs[1])
    local dist_z = math.abs(z - cur_abs[2])
    local dist_y = math.abs(y - nav.get_height())

    local man_dist = dist_x + dist_z + dist_y
    return man_dist
end


function Module:initPrimitive()
    self.primitive.parent = self
end

function Module:rotateAndTranslatePrimitive(quad_num, logical_chunk_height)
    local base_table = self.primitive.base_table
    local segments = self.primitive.segments
    local origin_block = self.primitive.origin_block

    origin_block[3] = origin_block[3] + logical_chunk_height -- y

    if quad_num == 1 then
        general_functions.mirror_x(base_table, segments)

        origin_block[1] = origin_block[1] + 8 -- x
        origin_block[2] = origin_block[2] + 1 -- z
    elseif quad_num == 2 then
        origin_block[1] = origin_block[1] + 1
        origin_block[2] = origin_block[2] + 1
    elseif quad_num == 3 then
        general_functions.mirror_z(base_table, segments)

        origin_block[1] = origin_block[1] + 1
        origin_block[2] = origin_block[2] + 8
    elseif quad_num == 4 then
        general_functions.mirror_x(base_table, segments)
        general_functions.mirror_z(base_table, segments)

        origin_block[1] = origin_block[1] + 8 -- x
        origin_block[2] = origin_block[2] + 8
    else
        print(comms.robot_send("error", "MetaBuild rotatePrimitive impossible quad_num: " .. quad_num))
        return false
    end
    return true
end

-- no need to rotate since they are already pre-rotated from before
function Module:translateSpecial(quad_num, logical_chunk_height, primitive_offset)
    local special_table = self.special_blocks

    --[[print(string.format("Name is: %s", self.name))
    local a_special = special_table[1]
    local str = string.format("Special was: [%s] (%s, %s) h:%s", a_special[1], a_special[2], a_special[3], a_special[4])
    print(str)
    io.read()--]]

    local function case_one(special)
        special[2] = special[2] + 8 -- x
        special[3] = special[3] + 1 -- z
    end
    local function case_two(special)
        special[2] = special[2] + 1 -- x
        special[3] = special[3] + 1 -- z
    end
    local function case_three(special)
        special[2] = special[2] + 1 -- x
        special[3] = special[3] + 8 -- z
    end
    local function case_four(special)
        special[2] = special[2] + 8 -- x
        special[3] = special[3] + 8 -- z
    end

    local case_function
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

--[[function Module:translatePrimitive(quad_num)

end--]]

function Module:dumpPrimitive()
    self.primitive = nil
end

function Module:setupBuild(what_quad, chunk_height)
    local old_origin_block = deep_copy.copy(self.primitive.origin_block, ipairs)
    local result = self:rotateAndTranslatePrimitive(what_quad, chunk_height)
    if not result then return false end

    local base_table = self.primitive.base_table

    if self.s_interface == nil then
        self.s_interface = SchematicInterface:new()
    end
    -- its ok to retain this after dumping the primitive because of GC, I think
    self.s_interface:init(self.primitive.dictionary, self.primitive.origin_block)
    if self:is_extra("top_to_bottom") then -- TODO move this to its own little function when appropriate
        self.s_interface.build_stack.logical_y = #self.s_interface.schematic
    end
    self.special_blocks = self.s_interface:getSpecialBlocks()

    if self:checkHumanMap(base_table, self.primitive.name) ~= 0 then -- sanity check
        return false
    end

    -- Build the sparse array

    -- ATTENTION: VVVVVVVVVVVVVVVVVVVVVVVVV
    -- if returning the length of the MetaSchematic tables is faulty, we'll need to count the height of buildings here
    -- thanks to the magic of lua bogus arguments are ok!
    if self.primitive.iter == nil then
        for index, table_obj in ipairs(base_table) do -- it is expected that table object does not include meta-table
            self.s_interface:parseStringArr(table_obj, index)
            --max_index = max_index + 1
        end
    else
        for index, table_obj in self.primitive:iter(base_table) do -- it is expected that table object does not include meta-data
            self.s_interface:parseStringArr(table_obj, index)
            -- print(comms.robot_send("debug", "MetaBuild:setupBuild() we looped once m8"))
            --max_index = max_index + 1
        end
    end
    -- print(comms.robot_send("debug", "we facking did it m8!"))

    self.is_nil = false

    local result = self:translateSpecial(what_quad, chunk_height, old_origin_block)
    if not result then return false end

    return true
end

function Module:require(name, what_chunk)
    if primitive_cache[name] ~= nil then
        self.primitive = primitive_cache[name]:new() -- very important
        self:initPrimitive()
        return true
    end

    local path = "/home/robot/build/" .. name .. ".lua"
    local build_table = nil -- luacheck: ignore
    if filesystem.exists(path) and not filesystem.isDirectory(path) then
        build_table = dofile(path)
    else
        print(comms.robot_send("error", "MetaBuild -- require -- No such build with name: \"" .. name .. "\""))
        return false
    end

    self.primitive = build_table:new() -- very important
    self.name = self.primitive.name
    self.extra_sauce = self.primitive.extra_sauce -- effective change of ownership
    self.post_build_s_init = self.primitive.state_init
    self.post_build_hooks = self.primitive.hooks

    self.what_chunk = what_chunk

    if self.post_build_state == nil then self.post_build_state = {} end

    -- THIS WAS REMOVED IN ORDER TO PERSERVE RAM
    --primitive_cache[name] = build_table
    self:initPrimitive()

    return true
end


-- build state == 1 chunk wide state
function Module:finalizeBuild(doors)
    self.built = true
    self.doors = doors -- lame cludge for now, fix later

    if self.post_build_state[1] == nil then self.post_build_state[1] = {} end

    for index, func in ipairs(self.post_build_s_init) do
        self.post_build_state[index] = func(self)
    end

    self.s_interface = nil -- :)
    -- print(comms.robot_send("debug", "finalizedBuild"))
end


function Module:getInventories()
    local all_inventories = {}
    for index = 2, #self.post_build_state, 1 do
        local state = self.post_build_state[index]
        if state == nil then goto continue end

        -- checks for the format I've been using for inventories
        if state[1] == nil then goto continue end

        for _, entry in ipairs(state[1]) do
            if entry.storage == nil then goto short_continue end
            table.insert(all_inventories, entry)
            ::short_continue::
        end
        ::continue::
    end
    if #all_inventories == 0 then return nil end
    return all_inventories
end


function Module:runBuildCheck(quantity_goal) -- quantity goal = {input (lable name), quantity}
    -- self:useBuilding(nil, "only_check", nil, quantity_goal, nil, nil)
    return self.post_build_hooks[1](self.post_build_state[1], self, "only_check", quantity_goal, self.post_build_state)
end

local max_depth = 10
local function recursive_append(tbl, buffer, depth)
    if depth >= max_depth then return end
    depth = depth + 1
    table.insert(buffer, "{\n")
    for key, value in pairs(tbl) do
        table.insert(buffer, string.format("%s = ", tostring(key)))

        if type(value) == "table" then recursive_append(value, buffer, depth); goto skip_comma
        elseif type(value) == "function" then table.insert(buffer, "function")
        elseif type(value) == "boolean" or type(value) == "string" or type(value) == "number" then
            table.insert(buffer, tostring(value))
        else table.insert(buffer, "other") end

        table.insert(buffer, ", ")
        ::skip_comma::
    end
    table.insert(buffer, "}\n")
end

-- flag determines if we are running a check or a determinate logistic action
-- (i.e -> picking up stuff from the output chest into the robot, or moving stuff to the input chest etc.)
function Module:useBuilding(f_caller, flag, index, quantity_goal, prio, lock)
    if index == 1 then
        -- first hook must correspond to this pattern
        index = self.post_build_hooks[1](self.post_build_state[1], self, flag, quantity_goal, self.post_build_state)
    else
        index = self.post_build_hooks[index](self.post_build_state[index])
    end

    if index == nil then
        lock[1] = 2
        return nil
    end -- else

    local return_table = {prio, f_caller, self, flag, index, quantity_goal, prio, lock}
    local buffer = {"\n"}
    recursive_append(return_table, buffer, 0)
    table.insert(buffer, "press enter")
    print(comms.robot_send("info", table.concat(buffer)))
    io.read()
    return return_table
end


function Module:createAndReturnLedger()
    -- We could try to pre-add-up every block by looping through the s_interface multiple times, and only
    -- then increment the ledger entries, or we could just loop once and increment the ledger entries
    -- 1-by-1, I don't know what solution is best, so I'll just use the easier one
    local tmp_ledger = VirtualInventory:new(64)


    local result, status, instruction
    while true do
        result, status, instruction = self:doBuild()
        if not result then error(comms.robot_send("fatal", "Failed to doBuild in createLedger, name is -- " .. self.name)) end
        if status == "done" then break end

        local block_name = instruction.block_info.name
        local block_lable = instruction.block_info.lable

        tmp_ledger:addOrCreate(block_lable, block_name, 1)
    end

    return tmp_ledger
end

function Module:getName()
    return self.name
end

function Module:getSchematicInterface()
    return self.s_interface
end

function Module:isBuilt()
    return self.built
end

-- luacheck: no unused args
function Module:checkHumanMap(base_table, name)
    local watch_dog = false
    for _, base in pairs(base_table) do
        if base[1] == "def" then -- I wish there was a re-usable way to write this logic, but no pass by ref, no luck
            if watch_dog == false then
                watch_dog = true
            else
                goto continue
            end
        end

        local map = base[2]
        if #map > 7 then
            comms.robot_send("error", "In human map -- Build: \"" .. name .. "\" -- Too Many Lines!")
            return -1
        end

        for index, line in ipairs(map) do
            if string.len(line) > 7 then
                comms.robot_send("error", "In human map -- Build: \"" .. name .. "\" -- Line: \"" .. tostring(index) .. "\" -- Line is way too big!")
                return index
            end
        end

        ::continue::
    end

    return 0
end

function Module:getPrimitiveDoors()
    return self.primitive.doors
end


return Module
