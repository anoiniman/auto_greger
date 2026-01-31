local tree_generator = require("virtual.schematics.oak_tree")
local KnownItem = require("virtual.item.KnownItem")

local oak_sapling = {}

local __f_leaf_decay = function() return math.random(10, 20) end

-- local __d_growth_factor = "fast"
local __d_growth_factor = "instant"

local function new_threshold()
    -- average 920 ticks
    if __d_growth_factor == "slow" then return math.random(330, 590)
    elseif __d_growth_factor == "fast" then return math.random(30, 60)
    elseif __d_growth_factor == "instant" then return math.random(1, 8)
    else error("__d_growth_factor is wrong womp womp") end
end

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
    oak_leaves.tick = function(world, block, offset_table)
        local state = block.t_state
        if world.tick_num < state.tick_threshold + state.last_tick then return end

        local there_is_log = false

        for y = offset_table[3] - 2, offset_table[3] + 2, 1 do
        for z = offset_table[2] - 2, offset_table[2] + 2, 1 do
        for x = offset_table[1] - 2, offset_table[1] + 2, 1 do
             

        end end end
        if there_is_log then return end

        local drop_chance = 0.05 
        if math.random() > drop_chance then return "destroy_self" end

        -- Sapling falling to ground algorithm
        local did_it = false
        for y = offset_table[3] - 1, 0, -1 do
            local block = world:getBlockAbs(offset_table[1], offset_table[2], y)
            if block ~= nil then
                local item = KnownItem:getByLabel("Oak Sapling")
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
        }

        block.t_state = state
    end


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

        block.t_state = state
    end

    return {oak_sap}
end

return oak_sapling
