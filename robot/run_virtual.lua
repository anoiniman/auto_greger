-- #!/bin/bash
-- package.path = "../testing/virtual/?.lua;" .. package.path
package.path = "../shared/?.lua;" .. package.path
package.path = "virtual/interface/?.lua;" .. package.path
-- print(package.path)

V_ENV = true

-- require("robo_main")
require("deep_copy")
--print(COPY)


local World = require("virtual.World")
local world = World:default()


rl.SetConfigFlags(rl.FLAG_VSYNC_HINT)
rl.InitWindow(1280, 720, "VirtuCraft Renderer")

local camera = rl.new("Camera", {
    position = rl.new("Vector3", 0, 10, 10),
    target = rl.new("Vector3", 0, 0, 0),
    up = rl.new("Vector3", 0, 1, 0),
    fovy = 45,
    type = rl.CAMERA_ORTHOGRAPHIC
})
-- local camera_mode = rl.CAMERA_FIRST_PERSON
local camera_mode = rl.CAMERA_FREE

-- luacheck: globals rl
while not rl.WindowShouldClose() do
    if rl.IsCursorHidden() then rl.UpdateCamera(camera, camera_mode) end
    if rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_RIGHT) then
        if rl.IsCursorHidden() then rl.EnableCursor()
        else rl.DisableCursor() end
    end

    rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)
        rl.BeginMode3D(camera)
            world:render()
        rl.EndMode3D()
    rl.EndDrawing()
end

rl.CloseWindow()
