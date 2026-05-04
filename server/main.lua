-- Server entry point. Validates every robbery request, applies cooldowns,
-- distributes loot on success, and dispatches police alerts on failure.
-- Built for Qbox (qbx_core + ox_inventory).

local config    = require 'shared.config'
local Cooldowns = require 'modules.cooldowns'
local Rewards   = require 'modules.rewards'
local Logger    = require 'shared.utils.logger'

-- ─── helpers ─────────────────────────────────────────────────────────────────
local CROWBAR_ITEM = 'WEAPON_CROWBAR'

local function getQbxPlayer(src)
    return exports.qbx_core:GetPlayer(src)
end

local function playerHasCrowbar(src)
    local count = exports.ox_inventory:Search(src, 'count', CROWBAR_ITEM)
    return type(count) == 'number' and count > 0
end

local function isValidPayload(payload, requireSuccessFlag)
    if type(payload) ~= 'table' then return false end
    if type(payload.coords) ~= 'vector3' then return false end
    if requireSuccessFlag and type(payload.success) ~= 'boolean' then return false end
    return true
end

local function dispatchPoliceAlert(coords)
    -- Public hook: replace with your dispatch system if you have one. The
    -- default broadcasts to all clients and lets the dispatch module on the
    -- client filter by job.
    TriggerClientEvent('postbox_robbery:client:policeAlert', -1, coords)
end

-- ─── callbacks ───────────────────────────────────────────────────────────────
lib.callback.register('postbox_robbery:server:requestRobbery', function(source, payload)
    if not isValidPayload(payload, false) then
        return false, 'invalid_payload'
    end

    if not getQbxPlayer(source) then
        return false, 'invalid_payload'
    end

    if not playerHasCrowbar(source) then
        return false, 'no_crowbar'
    end

    if Cooldowns.isPlayerOnCooldown(source) then
        return false, 'player_cooldown'
    end

    Cooldowns.setPlayerCooldown(source, config.COOLDOWN.perPlayerMs)

    return true
end)

lib.callback.register('postbox_robbery:server:completeRobbery', function(source, payload)
    if not isValidPayload(payload, true) then
        return false, 'invalid_payload'
    end

    if not getQbxPlayer(source) then
        return false, 'invalid_payload'
    end

    if payload.success then
        local result = Rewards.give(source)
        Logger.info('player', source, 'robbed postbox at', tostring(payload.coords), 'cash:', result.cash)
        return true, result
    end

    Logger.info('player', source, 'failed postbox at', tostring(payload.coords))
    if math.random(1, 100) <= config.POLICE_ALERT.chanceOnFail then
        dispatchPoliceAlert(payload.coords)
    end
    return true
end)

-- ─── lifecycle ───────────────────────────────────────────────────────────────
AddEventHandler('playerDropped', function()
    Cooldowns.clearPlayer(source)
end)

CreateThread(function()
    Logger.info('server initialised')
end)
