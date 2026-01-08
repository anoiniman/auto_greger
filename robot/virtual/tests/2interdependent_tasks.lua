local World = require("World")
local test_interface = require("tests")

local world = World:new()

local function __f_fail (test)
    if test.step_count > 100 * 100 then return 1 end
    return 0
end

local __f_pass = nil
local test = test_interface:addTest(world, __f_pass, __f_fail)

test:trackObj(
    {
        __f_pass = function (inv_obj)
            local inv = inv_obj.virtual_inventory
            -- local log_num = inv:howMany("Oak Log", "any:log")
            local sap_num = inv:howMany("Oak Sapling", "any:sapling")
            if sap_num > 20 then -- num of saplings required by goal saplings02
                return true
            end

            return false
        end
    }
)
