local record module end
function module.simple_compare(a: any, b: any): boolean
    if a == nil and b == nil then return true end
    if a == nil or b == nil then return false end

    if type(a) ~= type(b) then return false end
    return a == b
end
global S_CMP: function(any, any): boolean = module.simple_compare

return module
