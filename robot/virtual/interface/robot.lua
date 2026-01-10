-- luacheck: globals INV_SIZE
local sides_api = require("sides")
-- luacheck: push ignore Block
local Block, KnownBlocks = table.unpack(require("Block"))
-- luacheck: pop

local robot = { }
local robot_rep

function robot.setRobotRep(robot_rep_)
    robot_rep = robot_rep_
end

function robot.name()
    return "Testy"
end

local function subDetect(dir)
    local block = robot_rep.world:getBlockRelSide(robot_rep, sides_api[dir])
    if block == nil then return true, "passable" end -- its probabily air

    return block.passable, block.meta_type
end

function robot.detect()
    return subDetect("front")
end

function robot.detectUp()
    return subDetect("up")
end

function robot.detectDown()
    return subDetect("down")
end

function robot.select(slot_num)
    local previous = robot_rep.selected_slot

    if slot_num == nil or slot_num > INV_SIZE or slot_num < 1 then return previous end
    robot_rep.selected_slot = slot_num
    return slot_num
end

function robot.inventorySize()
    return INV_SIZE
end

function robot.count(slot_num)
    local info = robot_rep.inventory:getSlotInfo(slot_num)
    return info.size
end

function robot.space(slot_num)
    local info = robot_rep.inventory:getSlotInfo(slot_num)
    return info.maxSize - info.size
end

function robot.transferTo(slot_num, count)
    if slot_num > INV_SIZE or slot_num < 1 then return false end
    count = count or 64

    return robot_rep:transferTo(slot_num, count)
end

-- I literally never use this function lol
function robot.compareTo(slot_num)
    if slot_num > INV_SIZE or slot_num < 1 then return false end

    local item_info = robot_rep.inventory:getSlotInfo(robot_rep.selected_slot)
    return robot_rep.inventory:isItemSame(item_info, slot_num)
end

local function sub_compare(dir)
    local block = robot_rep.world:getBlockRelSide(sides_api[dir])
    return robot_rep.inventory:isItemSame(block.item_info, robot_rep.selected_slot)
end

function robot.compare() return sub_compare("front") end
function robot.compareUp() return sub_compare("up") end
function robot.compareDown() return sub_compare("down") end

-- This will technically "drop" items into the inside of blocks, but the deviation to real
-- behaviour should not be that big that it'd cause bugs, let alone, difficult to determine ones
-- (AKA -> It should be really obvious what is causing the bug if it happens to happen)
--
-- TODO -> Interact with inventories, not just drop shit on the ground lmao
local function sub_drop(count, dir)
    if robot_rep.inventory:isSlotEmpty(robot_rep.selected_slot) then return false end

    local block = robot_rep.world:getBlockRelSide(sides_api[dir])
    local item_info_copy = COPY(robot_rep.inventory:getSlotInfo(robot_rep.selected_slot))
    item_info_copy.size = math.min(item_info_copy.size, count)

    if block.inventory == nil then
        block:dropOneItemStack(item_info_copy)
        robot_rep.inventory:removeFromSlot(robot_rep.selected_slot, count)
        return true
    end

    local _, not_added = block.inventory:addItem(item_info_copy)
    local added = count - not_added
    robot_rep.inventory:removeFromSlot(robot_rep.selected_slot, added)
    return true
end

function robot.drop(count) return sub_drop(count, "front") end
function robot.dropUp() return sub_drop(64, "up") end
function robot.dropDown() return sub_drop(64, "down") end

-- Implementation for dropped item's is stupid, fix that one day if there are any issues,
-- but I think it is something so side-line-ish that this implementation style is good enough
-- but that iislot ~= nil stuff is vile
local function sub_suck(count, dir)
    count = count or 64
    local block = robot_rep.world:getBlockRelSide(sides_api[dir])
    local item_info, iislot

    if block.inventory == nil then
        item_info = block:pickUpOneItemStack()
    else
        item_info, iislot = block.inventory:getFirstItemInfo()
    end
    if item_info == nil then return false end

    local removed
    local original_size = item_info.size
    if iislot ~= nil then removed = block.inventory:removeFromSlot(iislot, count)
    else
        item_info.size = item_info.size - count
        if item_info.size < 0 then
            removed = original_size
            item_info.size = 0
        else
            removed = count
        end
    end

    -- Behaviour currently is to add as much as possible to wanted slot and only then addind to first free slot
    -- not sure if it is supposed to be like this, but oh well
    local added = robot_rep.inventory:addToSlot(item_info, robot_rep.selected_slot, removed)
    if removed - added ~= 0 then
        local _, added_ = robot_rep.inventory:addItem(item_info)
        added = added + added_
    end

    if iislot == nil then -- Aka if we picked it up from the ground
        if item_info.size > 0 then
            block:dropOneItemStack(item_info)
        end
    end

    if added == 0 then return false end
    return true
end

function robot.suck(count) return sub_suck(count, "front") end
function robot.suckUp() return sub_suck(64, "up") end
function robot.suckDown() return sub_suck(64, "down") end


-- If side is nil then try all sides*
-- This sort of behaviour will probably be unecessary in our simulation, so we'll just ignore
-- Both side and sneaky, for now at least, the simulation is still not very advenaced
local function sub_place(_side, _sneaky, dir)
    local cur_block, bpos = robot_rep.world:getBlockRelSide(dir)
    if cur_block ~= nil and not cur_block:isAir() then return false, "Other Block in the Way" end

    local item_info = robot_rep.inventory:getSlotInfo(robot_rep.selected_slot)
    local new_block = KnownBlocks:getByItemInfo(item_info)
    if new_block == nil then return false, "Cannot Place Selected" end

    robot_rep.world:placeBlock(new_block, table.unpack(bpos))
    robot_rep.inventory:removeFromSlot(robot_rep.selected_slot, 1)

    return true, nil
end

function robot.place(side, sneaky) return sub_place(side, sneaky, "front") end
function robot.placeUp(side, sneaky) return sub_place(side, sneaky, "up") end
function robot.placeDown(side, sneaky) return sub_place(side, sneaky, "down") end

function robot.durability()
    if robot_rep.equiped_item == nil then return nil, "no tool equipped" end
    if robot_rep.equiped_item.maxDamage == -1 then return nil, "tool cannot be damaged" end

    return  table.unpack(
            {
            robot_rep.equiped_item.maxDamange - robot_rep.equiped_item.damage,
            robot_rep.equiped_item.damage,
            robot_rep.equiped_item.maxDamage
            }
            )
end

-- TODO: add interaction with entities && implement silk touch
local function sub_swing(_side, _sneak, dir)
    local equipment = nil
    if robot_rep.equiped_item ~= nil then equipment = robot_rep.equiped_item.equipment_data end

    local block, bpos = robot_rep.world:getBlockRelSide(dir)

    if block == nil then return false, "no block" end
    -- block.ginfo
    if block.ginfo.harvestLevel > 0 then
        if equipment == nil then return false, "no tool" end
        if block.ginfo.harvestTool ~= equipment.type then return false, "wrong tool" end
        if block.ginfo.harvestLevel > equipment.level then return false, "weak tool" end

        -- else we can mine it :)
    end

    -- If not silk-touch
    local item_info = block:getDrop()
    robot_rep.inventory:addItem(item_info)
    robot_rep.world:removeBlock(table.unpack(bpos))

    robot_rep.equiped_item:removeDurability(1)
    return true
end

function robot.swing(side, sneaky) return sub_swing(side, sneaky, "front") end
function robot.swingUp(side, sneaky) return sub_swing(side, sneaky, "up") end
function robot.swingDown(side, sneaky) return sub_swing(side, sneaky, "down") end


local function sub_use(_side, _sneaky, _duration, dir)
    local block = robot_rep.world:getBlockRelSide(dir)
    return block:use(robot_rep.equiped_item)
end

function robot.use(side, sneaky, duration) return sub_use(side, sneaky, duration, "front")  end
function robot.useUp(side, sneaky, duration) return sub_use(side, sneaky, duration, "up")  end
function robot.useDown(side, sneaky, duration) return sub_use(side, sneaky, duration, "down")  end


function robot.forward() robot_rep:forward() end
function robot.back() robot_rep:back() end
function robot.up() robot_rep:up() end
function robot.down() robot_rep:down() end

function robot.turnLeft() robot_rep:turnLeft() end
function robot.turnRight() robot_rep:turnRight() end
function robot.turnAround() robot_rep:turnAround() end

-- TODO "tank controls", not that I used them in the current robot though :P

return robot
