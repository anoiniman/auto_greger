local interface LateBind
    source_path: string
    target_name: string
end

local interface LateBindContext
    lb_tbl: {string : any}
    objects: {LateBind}
end

local ctxs: {LateBindContext} = {}
local record helper end

-- Only works for modules that do not return tables of tables
-- Only works for table members that are pass by reference
function helper.new_ctx(lb_tbl: {string : any}): LateBindContext
    local ctx = {lb_tbl = lb_tbl, objects = {}}
    table.insert(ctxs, ctx)
    return ctx
end

function helper.new_bind(ctx: LateBindContext, source_path: string, target_name: string)
    table.insert(ctx.objects, {source_path = source_path, target_name = target_name})
end
function helper.do_binds()
    while true do
        local ctx = table.remove(ctxs) as LateBindContext
        if ctx == nil then break end

        while true do
            local lb = table.remove(ctx.objects) as LateBind
            if lb == nil then break end

            local source = require(lb.source_path)
            ctx.lb_tbl[lb.target_name] = source
        end
    end
end


return helper
