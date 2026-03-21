local tree_generator = require("virtual.schematics.oak_tree")
local KnownItems = require("virtual.item.KnownItems")

local oak_sapling = {}

local __f_leaf_decay = function() return math.random(10, 20) end
local __d_leaf_decay = 8

local __d_growth_factor = "slow"

local function new_threshold()
    -- average 920 ticks
    if __d_growth_factor == "slow" then return math.random(330, 590)
    elseif __d_growth_factor == "ok" then return math.random(120, 240)
    elseif __d_growth_factor == "fast" then return math.random(30, 60)
    elseif __d_growth_factor == "instant" then return math.random(1, 8)
    else error("__d_growth_factor is wrong womp womp") end
end

local __d_dead_leaves = false
function oak_sapling:provideAndGet(Block, KnownBlocks, newColor)
    local leaf_green = newColor("LeafGreen", 49, 168, 43, 124)
    local oak_leaves = Block:new(
        "minecraft:oak_leaves",
        "Oak Leaves",
        leaf_green,
        false,
        "solid",
        "shovel",
        0
    )
    if not __d_dead_leaves then
    oak_leaves.tick = function(world, block, offset_table)
        local state = block.t_state
        if world.tick_num < state.check_threshold + state.last_check then return end
        state.check = world.tick_num

        local there_is_log = false
        local log_example = KnownBlocks:getByLabel("Oak Wood").item_info

        for y = offset_table[3] - 2, offset_table[3] + 2, 1 do
        for z = offset_table[2] - 2, offset_table[2] + 2, 1 do
        for x = offset_table[1] - 2, offset_table[1] + 2, 1 do
            local block = world:getBlockAbs(x, z, y)
            if block == nil then goto continue end
            -- print(block.item_info.label)
            if block.item_info:isSame(log_example) then there_is_log = true end

            ::continue::
        end end end
        -- if there_is_log then print("there is log"); return end
        if there_is_log then 
            state.dying = false
            return
        end
        if state.dying == false then
            state.tick_threshold = __f_leaf_decay()
            state.last_tick = world.tick_num
        end
        state.dying = true

        if world.tick_num < state.tick_threshold + state.last_tick then return end

        local drop_chance = 0.05 
        if math.random() > drop_chance then return "destroy_self" end

        -- Sapling falling to ground algorithm
        local did_it = false
        for y = offset_table[3] - 1, 0, -1 do
            local block = world:getBlockAbs(offset_table[1], offset_table[2], y)
            if block ~= nil then
                local item = KnownItems:getByLabel("Oak Sapling")
                item.size = 1
                print(string.format(
                    "Dropped sapling (%s) into: %s (%d, %d, %d)",
                    item.label,
                    block.item_info.label,
                    offset_table[1],
                    offset_table[2],
                    y
                ))

                block:dropOneItemStack(item)
                did_it = true
                break
            end
        end

        if not did_it then error("No floor???") end

        return "destroy_self"
    end

    oak_leaves.on_place = function(world, block)
        local state = {
            tick_threshold = __f_leaf_decay(),
            last_tick = world.tick_num,

            check_threshold = __d_leaf_decay,
            last_check = world.tick_num,
            dying = false,
        }

        block.t_state = state
    end
    else
        print("dead_leaves activated")
    end

    oak_leaves.block_break = function () return 0 end


    local oak_sapling_blue = newColor("OakSaplingBlue", 90, 147, 143, 212)
    local oak_sap = Block:new(
        "minecraft:sapling",
        "Oak Sapling",
        oak_sapling_blue,
        false,
        "solid",
        "shovel",
        0
    )

    local replace_white_list = {
        -- KnownBlocks:getByLabel("")
        KnownBlocks:air(),
        COPY(oak_leaves),
        -- KnownBlocks:getByLabel("Oak Leaves"),
        oak_sap,    
    }

    
    KnownBlocks:register(oak_leaves)
    local tree_schematic, tree_dictionary, tree_rel_offset = table.unpack(tree_generator.generate(KnownBlocks))
    -- oak_sap.tick = function(world, state, offset_table)
    oak_sap.tick = function(world, block, offset_table)
        -- print(pos[1], pos[2], pos[3])

        local state = block.t_state
        if state.last_tick == -1 then state.last_tick = world.tick_num end
        if world.tick_num >= state.tick_threshold + state.last_tick then
            state.growth_stage = state.growth_stage + 1
        end

        for k, v in ipairs(tree_rel_offset) do
            offset_table[k] = offset_table[k] + v
        end

        if state.growth_stage >= 2 then
            -- print(pos[1], pos[2], pos[3])
            world.block_set:parseNativeSchematic(
                tree_schematic,
                tree_dictionary,
                offset_table,
                false,
                replace_white_list,
                false
            )
            state.growth_stage = 0
            state.last_tick = world.tick_num
            state.tick_threshold = new_threshold()
        end
    end

    oak_sap.on_place = function(world, block)
        local state = {
            growth_stage = 0,
            tick_threshold = new_threshold(),
            last_tick = world.tick_num,
        }
        -- print(world.tick_num, state.last_tick, state.tick_threshold)

        block.t_state = state
    end

    return {oak_sap, oak_leaves}
end

return oak_sapling
