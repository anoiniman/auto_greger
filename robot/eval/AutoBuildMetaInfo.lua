local deep_copy = require("deep_copy")

--[[return map_obj.start_auto_build(
    arguments[1],
    arguments[2],
    arguments[3],
    arguments[4],
    arguments[5],
    arguments[6],
    arguments[7],
    arguments[8], -- old_build_instructions
    arguments
)--]]

local ABMetaInfo = {
    what_chunk = nil,
    what_quad = nil,
    name = nil,
    step = nil,

    lock = nil,
    id = nil,
    prio = nil,

    door_move_done = false,
    bridge_mode = false
}

function ABMetaInfo:new(
    what_chunk,
    what_quad,
    name,
    step,

    lock,
    id,
    prio
)
    local new = deep_copy.copy(self, pairs)
    new.what_chunk = what_chunk
    new.what_quad = what_quad
    new.name = name
    new.step = step

    new.lock = lock
    new.id = id
    new.prio = prio

    return new
end

function ABMetaInfo:unpack()
    return self.what_chunk, self.what_quad, self.name, self.step, self.lock, self.id, self.prio
end

return ABMetaInfo
