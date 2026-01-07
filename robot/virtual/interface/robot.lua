-- luacheck: globals INV_SIZE
local sides_api = require("sides")
local Block, KnownBlocks = table.unpack(require("Block"))

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
    local item_info = robot_rep.inventory:getSlotInfo(robot_rep.selected_slot)

    if block.inventory == nil then
        block:dropOneItemStack(item_info)
        robot_rep.inventory:removeFromSlot(robot_rep.selected_slot, 64)
        return true
    end

    local _, added = block.inventory:addItem(item_info)
    robot_rep.inventory:removeFromSlot(robot_rep.selected_slot, added)
    return true
end

function robot.drop(count) return sub_drop(count, "front") end
function robot.dropUp() return sub_drop(64, "up") end
function robot.dropDown() return sub_drop(64, "down") end

function sub_suck(count, dir)
    count = count or 64
    local block = robot_rep.world:getBlockRelSide(sides_api[dir])
    local item_info, iislot

    if block.inventory == nil then
        item_info = block:pickUpOneItemStack()
    else
        item_info, iislot = block.inventory:getFirstItemInfo()
    end
    if item_info == nil then return false end

    -- Behaviour currently is to add as much as possible to wanted slot and only then addind to first free slot
    -- not sure if it is supposed to be like this, but oh well
    local original_size = item_info.size
    local added = robot_rep.inventory:addToSlot(item_info, robot_rep.selected_slot)
    if original_size - added ~= 0 then
        local _, added_ = robot_rep.inventory:addItem(item_info)
        added = added + added_
    end

    if iislot ~= nil then block.inventory:removeFromSlot(iislot, added) end

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
    if cur_block ~= nil and not block:isAir() then return false, "Other Block in the Way" end

    local item_info = robot_rep.inventory:getSlotInfo(robot_rep.selected_slot)
    local new_block = KnownBlocks:getByItemInfo(item_info)
    if new_block == nil then return false, "Cannot Place Selected" end

    robot_rep.world:placeBlock(new_block, table.unpack(bpos))
    robot_rep.inventory:removeFromSlot(robot_rep.selected_slot, 1)

    return true, nil
end

function robot.place() return sub_place(nil, nil, "front") end
function robot.placeUp() return sub_place(nil, nil, "up") end
function robot.placeDown() return sub_place(nil, nil, "down") end


return robot
