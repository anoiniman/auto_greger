local module = {}

function module.step(instructions, return_table)
    local what_chunk = instructions.what_chunk
    if what_chunk == nil then print(comms.robot_send("error", "road_build.step(), no what_chunk provided!")) end
    -- TODO finish this

    return return_table
end


return module
