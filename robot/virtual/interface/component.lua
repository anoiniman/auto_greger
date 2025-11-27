local Tunnel = {}
function Tunnel.send()
    return
end


local component_list = {
    inventory_controller = nil,
    crafting = nil,
    tractor_beam = nil,
    geolyzer = nil,
    generator = nil,

    tunnel = Tunnel,
}

local component = {}

function component.getPrimary(name)
    return component_list[name]
end

return component
