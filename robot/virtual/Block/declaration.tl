local type BlockColor = {string, integer, integer, integer, integer}
local interface InteractionState end
-- TODO: redisign whole ass thing, so that the interaction between blocks and world can actually be modelled
-- by the type system, for now we simply declare a fake World type to fool teal, not great

local interface MetaBlock
    -- For now {any} after redesign or teal update -> {Block}
    getBlockArray: function(any): {any}
end

return {BlockColor, InteractionState, MetaBlock}
