require("build.MetaBuild.__h_init")
require("build.MetaBuild.DoorInfo")
global interface MetaQuad
    quad: integer
    build: Build | nil
    doors: {Door} | nil
end

