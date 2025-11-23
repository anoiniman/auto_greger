local Block = {
    lable = "Dirt",
    passable = false,
}
function Block:default()
    return deep_copy.copy(self)
end

-- generates a flat rectangle at a given height
local function default_generation()
    local height = 3
    local width = 16
    local length = 16

    local top_level = {}
    local block
    local z_level
    local x_level

    for y = 1, height, 1 do
        top_level[y] = {}
        y_level = top_level[y] -- {{}}
        for z = 1, length, 1 do
            y_level[z] = {}
            z_level = y_level[z]
            for x = 1, width, 1 do
                z_level[x] = Block:default()
                block = z_level[x]
            end
        end
    end

    local y = 1
    for z = 1, #z_level, 16 do
        for x = 1, #x_level, 8 do
            top_level[y][z][x] = Block:default()
        end
    end
end

local function gen_line()

end

local function default_generation(width, length, height)
    local table_of_blocks
    for
end


local World = {
    blocks = default_generation(),
    generate_function = default_generation,
}

function World:


function World:Generate()
    return self.generate_function(self, width, length, height)
end
