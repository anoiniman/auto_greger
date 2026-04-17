local record einv_item end

-- as obvious, if it is an item inside a static storage it has no output
-- permissive matters no more, because to be permissive we simple have to have a "name with no lable" association,
global record eInvItem
    item: ItemDefinition
end
-- output: ItemDefinition --> why?

function einv_item.new(item: ItemDefinition): eInvItem
    return {
        item = item,
        --output = output
    }
end

return einv_item
