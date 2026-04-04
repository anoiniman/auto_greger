local interface LateBind
    path: string
    fake_table: {any : any}
end

local objects: {LateBind}
local record helper end

-- Only works for modules that do not return tables of tables lmao
function helper.new_bind<T>(path: string): T
    local fake_table: T = {} as T
    table.insert(objects, {path = path, fake_table = fake_table as {any : any}})
    return fake_table
end

function helper.do_binds()
    while true do
        local late_bind = table.remove(objects)
        if late_bind == nil then break end

        local real_table: {any : any} = require(late_bind.path) as {any : any}
        local fake_table = late_bind.fake_table
        for k, v in pairs(real_table) do fake_table[k] = v end
    end
end

return helper
