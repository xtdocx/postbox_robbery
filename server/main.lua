-- Server entry point. Validates every robbery request (weapon, cooldown,
-- distance), issues a one-shot token, and re-validates on completion so the
-- client cannot fabricate coords, succeed by skipping the request, or replay
-- a single request for repeated rewards.
-- Built for Qbox (qbx_core + ox_inventory).

local config    = require 'shared.config'
local Cooldowns = require 'modules.cooldowns'
local Rewards   = require 'modules.rewards'
local Tokens    = require 'modules.tokens'
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

local function getPedCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

-- The client claims the postbox is at `coords`. The server independently
-- checks the player's actual position is within reach of those coords; the
-- buffer absorbs network drift while the player is locked in the anim.
local function isWithinInteractDistance(src, coords)
    local pedCoords = getPedCoords(src)
    if not pedCoords then return false end
    local maxDist = config.MAX_INTERACT_DIST + config.SERVER_DISTANCE_BUFFER
    return #(pedCoords - coords) <= maxDist
end

local function isValidRequestPayload(payload)
    if type(payload) ~= 'table' then return false end
    if type(payload.coords) ~= 'vector3' then return false end
    return true
end

local function isValidReportPayload(payload)
    if type(payload) ~= 'table' then return false end
    if type(payload.token) ~= 'string' then return false end
    return true
end

local function dispatchPoliceAlert(coords)
    -- Public hook: replace with your dispatch system. The default broadcasts
    -- to all clients and lets the dispatch module on the client filter by job.
    TriggerClientEvent('postbox_robbery:client:policeAlert', -1, coords)
end

-- Validates and consumes the token. Re-runs every server-checkable rule
-- (weapon still equipped, still within range, not suspiciously fast). Any
-- failure consumes the token anyway so it cannot be retried.
local function consumeTokenWithRevalidation(src, token)
    local record, err = Tokens.peek(token, src)
    if not record then return nil, err end

    local elapsed = GetGameTimer() - record.issuedAt
    if elapsed < config.TOKEN.minElapsedMs then
        Tokens.consume(token)
        return nil, 'too_fast'
    end

    if not playerHasCrowbar(src) then
        Tokens.consume(token)
        return nil, 'no_crowbar'
    end

    if not isWithinInteractDistance(src, record.coords) then
        Tokens.consume(token)
        return nil, 'too_far'
    end

    Tokens.consume(token)
    return record
end

-- ─── callbacks ───────────────────────────────────────────────────────────────
lib.callback.register('postbox_robbery:server:requestRobbery', function(source, payload)
    if not isValidRequestPayload(payload)        then return false, 'invalid_payload' end
    if not getQbxPlayer(source)                  then return false, 'invalid_payload' end
    if not playerHasCrowbar(source)              then return false, 'no_crowbar'      end
    if Cooldowns.isPlayerOnCooldown(source)      then return false, 'player_cooldown' end
    if not isWithinInteractDistance(source, payload.coords) then return false, 'too_far' end

    Cooldowns.setPlayerCooldown(source, config.COOLDOWN.perPlayerMs)
    local token = Tokens.issue(source, payload.coords, config.TOKEN.ttlMs)

    return true, token
end)

lib.callback.register('postbox_robbery:server:reportSuccess', function(source, payload)
    if not isValidReportPayload(payload) then return false, 'invalid_payload' end

    local record, err = consumeTokenWithRevalidation(source, payload.token)
    if not record then
        Logger.info('reportSuccess rejected for', source, 'reason:', err)
        return false, err
    end

    local result = Rewards.give(source)
    Logger.info('player', source, 'robbed postbox at', tostring(record.coords), 'cash:', result.cash)
    return true, result
end)

lib.callback.register('postbox_robbery:server:reportFailure', function(source, payload)
    if not isValidReportPayload(payload) then return false, 'invalid_payload' end

    local record, err = consumeTokenWithRevalidation(source, payload.token)
    if not record then
        Logger.info('reportFailure rejected for', source, 'reason:', err)
        return false, err
    end

    Logger.info('player', source, 'failed postbox at', tostring(record.coords))
    if math.random(1, 100) <= config.POLICE_ALERT.chanceOnFail then
        dispatchPoliceAlert(record.coords)
    end
    return true
end)

-- ─── lifecycle ───────────────────────────────────────────────────────────────
AddEventHandler('playerDropped', function()
    local src = source
    Cooldowns.clearPlayer(src)
    Tokens.clearForPlayer(src)
end)

CreateThread(function()
    Logger.info('server initialised')
end)
