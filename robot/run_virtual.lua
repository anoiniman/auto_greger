-- #!/bin/bash
-- package.path = "../testing/virtual/?.lua;" .. package.path
package.path = "../shared/?.lua;" .. package.path
package.path = "virtual/interface/?.lua;" .. package.path
package.path = "virtual/def/?.lua;" .. package.path
-- print(package.path)

V_ENV = true

-- require("robo_main")
require("deep_copy")
--print(COPY)


local World = require("virtual.World")
local world = World:default()

-- local render = package.loadlib("../virtual_env/render.so", "luaopen_mylib")
local render = require("librender")
render.init()

local is_ok = 2
while is_ok == 2 do
    is_ok = render.render(world.render, world)
end

-- will have to transition the rendering to C, hurts, but the raylib-lua thing is not doing it for me
-- BLOOM_SHADER = rl.LoadShader(ffi.C.(, rl.TextFormat("virtual/def/bloom.fs", GLSL_VERSION))
-- BLOOM_SHADER = rl.LoadShader(nil, "./virtual/def/bloom.fs")


