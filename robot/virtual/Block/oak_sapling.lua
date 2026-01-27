local oak_sapling = {}
local tree_generator = require("virtual.schematics.oak_tree")

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
        KnownBlocks:getByLabel("Oak Leaves"),
        oak_sap,    
    }


    local tree_schematic, tree_dictionary, tree_rel_offset = table.unpack(tree_generator.generate(KnownBlocks))
    oak_sap.tick = function(world, state, offset_table)
        -- print(pos[1], pos[2], pos[3])

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

    oak_sap.on_place = function(world) 
        local state = {
            growth_stage = 0,
            tick_threshold = new_threshold(),
            last_tick = world.tick_num,
        }

        return state
    end

    return {oak_sap}
end

return oak_sapling
