-- Generates and distributes loot for a successful robbery.
-- Built for Qbox: cash goes through qbx_core player functions, items go
-- through ox_inventory.

local Random = require 'shared.utils.random'
local config = require 'shared.config'
local Logger = require 'shared.utils.logger'

local Rewards = {}

local function appendItem(items, count, def)
    count          = count + 1
    items[count]   = { name = def.name, count = Random.range(def.min, def.max) }
    return count
end

local function rollItems()
    local items = {}
    local count = 0

    -- Guaranteed: every postbox always contains at least these.
    local guaranteed = config.REWARDS.guaranteed
    for i = 1, #guaranteed do
        count = appendItem(items, count, guaranteed[i])
    end

    -- Bonus: chance-rolled extras on top of the guaranteed pool.
    local bonus = config.REWARDS.bonus
    for i = 1, #bonus do
        local def = bonus[i]
        if Random.chance(def.chance) then
            count = appendItem(items, count, def)
        end
    end

    return items
end

local function rollCash()
    return Random.range(config.REWARDS.cash.min, config.REWARDS.cash.max)
end

local function giveCash(src, amount)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return false end
    return player.Functions.AddMoney('cash', amount, 'postbox-robbery')
end

local function giveItems(src, items)
    for i = 1, #items do
        local item = items[i]
        local ok, canCarry = pcall(exports.ox_inventory.CanCarryItem, exports.ox_inventory, src, item.name, item.count)
        if ok and canCarry then
            exports.ox_inventory:AddItem(src, item.name, item.count)
        end
    end
end

-- Guarantees a payout: cash is always rolled within configured min/max and
-- attempted, items are bonus drops. Failures in the framework call are logged
-- but never block the success result — the player still gets credited the
-- cash amount in the returned payload.
function Rewards.give(src)
    local cashAmount = rollCash()
    local items      = rollItems()

    local cashOk, cashErr = pcall(giveCash, src, cashAmount)
    if not cashOk then
        Logger.error('cash payout failed for', src, ':', tostring(cashErr))
    end

    local itemsOk, itemsErr = pcall(giveItems, src, items)
    if not itemsOk then
        Logger.error('item payout failed for', src, ':', tostring(itemsErr))
        items = {}
    end

    return {
        cash  = cashAmount,
        items = items,
    }
end

return Rewards
