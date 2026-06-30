require("build.MetaBuild.__h_MetaBuild")
require("build.MetaBuild.DoorInfo")
global interface MetaQuad
    quad: integer
    build: Build | nil
    doors: {Door} | nil
end

