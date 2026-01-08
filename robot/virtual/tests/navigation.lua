local test_interface = require("tests")
local RobotRep = require("RobotRep")
local World = require("World")

local robot_rep = RobotRep:new()

local function __f_nav_fail(nav_obj)
    -- Check that absolute coordinates are coordinated
    if  robot_rep.position[1] ~= nav_obj.abs[1]
        or robot_rep.position[2] ~= nav_obj.abs[2]
        or robot_rep.position[3] ~= nav_obj.height
    then
        return 1
    end

    -- Check that relative coordinates are coordinated
    if  robot_rep.position[1] % 15 ~= nav_obj.rel[1]
        or robot_rep.position[2] % 15 ~= nav_obj.rel[2]
    then
        return 2
    end

    -- Check that chunk coordinates are coordinated
    if  math.floor(robot_rep.position[1] / 15) ~= nav_obj.chunk[1]
        or math.floor(robot_rep.position[2] / 15) ~= nav_obj.chunk[2]
    then
        return 3
    end

    if robot_rep.orientation ~= nav_obj.orientation then return true end

    return 0
end

local function __t_nav_fail(nav_obj, fail_value)
    LOG(
        "There has been a misalignement between the robot_rep positional state \z
        and the nav_obj state as it is self-tracked by the robot.\n\z
        It is safe to suspect a failure in the navigation system, but it might be somewhere else.",
        2
    )
    if fail_value == 1 then
        LOG(string.format(
            "RobotRep ABS Position = {%d, %d, %d}, while nav_obj: abs = {%d, %d} height = %d",
            robot_rep.position[1], robot_rep.position[2], robot_rep.position[3],
            nav_obj.abs[1], nav_obj.abs[2], height
        ))
    elseif fail_value == 2 then
        LOG(string.format(
            "RobotRep REL Position = {%d, %d}, while nav_obj: rel = {%d, %d}",
            robot_rep.position[1] % 15, robot_rep.position[2] % 15,
            nav_obj.rel[1], nav_obj.rel[2]
        ))
    elseif fail_value == 3 then
        LOG(string.format(
            "RobotRep CHUNK Position = {%d, %d}, while nav_obj: chunk = {%d, %d}",
            math.floor(robot_rep.position[1] / 15), math.floor(robot_rep.position[2] % 15),
            nav_obj.chunk[1], nav_obj.chunk[2]
        ))
    end
end

-- always starts
local schematic = {
}
local world = World:empty(robot_rep, 72, 72, 6)

local navigate = test_interface:addTest(world, nil, nil)
navigate:trackObj(
    {
        __f_fail = __f_nav_fail,
        fail_text = __t_nav_fail,
    },
    "nav_obj",
    "nav_obj",
    nil
)



return navigate
