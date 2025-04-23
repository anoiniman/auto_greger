local module = {}

local filesystem = require("filesystem")
local comms = require("comms")

local cur_dir = nil
local o_path = nil

function module.setup_factory(c_dir, op)
    if c_dir ~= nil then cur_dir = c_dir end
    if op ~= nil then o_path = op end
end

function module.get_sym(name) -- returns require require string
    local sym_dir = cur_dir .. "/sym"
    if not filesystem.isDirectory(sym_dir) then
        filesystem.makeDirectory(sym_dir)
    end

    local sym_file = sym_dir .. "/" .. name .. ".lua"
    local original_file = o_path .. "/" .. name .. ".lua"

    if not filesystem.exists(sym_file) then
        if not filesystem.exists(original_file) then
            print(comms.robot_send("error", "get_sym -- file does not exist: " .. original_file))
            return nil
        end

        filesystem.link(original_file, sym_file)
    end

    return "sym." .. name
end

return module
