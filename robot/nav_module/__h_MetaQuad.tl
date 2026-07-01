require("build.MetaBuild.__h_init")
require("build.MetaBuild.DoorInfo")
global interface MetaQuad
    quad: integer
    build: Build | nil
    doors: {DoorInfo} | nil
end

