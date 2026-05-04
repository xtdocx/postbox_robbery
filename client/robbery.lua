-- Robbery sequence: validate -> animate -> bl_ui hack -> resolve outcome.
-- Player is locked in place during the action; movement, weapon switch, or
-- damage cancels the attempt.

local config  = require 'shared.config'
local Logger  = require 'shared.utils.logger'
local Robbery = require 'shared.classes.robbery'

local M = {}

-- Module-local "active" flag — using a state bag here would expose status to
-- other resources but adds no value for this script.
local active = false

local function isActive() return active end
local function setActive(v) active = v end

-- ─── animation helpers ───────────────────────────────────────────────────────
local function loadAnim(dict)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > timeout then return false end
        Wait(50)
    end
    return true
end

local function playAnim(ped, anim)
    if not loadAnim(anim.dict) then return false end
    -- Finite duration so the anim self-terminates even if a stop call is missed.
    TaskPlayAnim(ped, anim.dict, anim.clip, 8.0, -8.0, anim.durationMs, anim.flag, 0, false, false, false)
    return true
end

local function stopAnim(ped, anim)
    StopAnimTask(ped, anim.dict, anim.clip, 1.0)
end

-- Hard reset: fully clear any task/animation residue from the ped.
local function clearPedAnimState(ped)
    ClearPedTasks(ped)
    ClearPedSecondaryTask(ped)
end

-- ─── control / interrupt watchers ────────────────────────────────────────────
local function disableMovementControls()
    DisableControlAction(0, 30,  true)  -- move LR
    DisableControlAction(0, 31,  true)  -- move UD
    DisableControlAction(0, 21,  true)  -- sprint
    DisableControlAction(0, 22,  true)  -- jump
    DisableControlAction(0, 23,  true)  -- enter vehicle
    DisableControlAction(0, 24,  true)  -- attack
    DisableControlAction(0, 25,  true)  -- aim
    DisableControlAction(0, 47,  true)  -- weapon
    DisableControlAction(0, 263, true)  -- melee
    DisableControlAction(0, 257, true)  -- attack2
end

local function startControlsBlocker(robbery)
    CreateThread(function()
        while not robbery:isCancelled() do
            disableMovementControls()
            Wait(0)
        end
    end)
end

local function startInterruptWatcher(robbery)
    CreateThread(function()
        while not robbery:isCancelled() do
            local ped = PlayerPedId()
            if robbery:hasMovedTooFar(config.INTERRUPT.maxMoveDistance) then
                robbery:cancel()
                return
            end
            if IsEntityDead(ped) or IsPedRagdoll(ped) or IsPedBeingStunned(ped) then
                robbery:cancel()
                return
            end
            local _, weaponHash = GetCurrentPedWeapon(ped, true)
            if weaponHash ~= config.REQUIRED_WEAPON then
                robbery:cancel()
                return
            end
            Wait(config.INTERRUPT.checkIntervalMs)
        end
    end)
end

-- ─── effects ─────────────────────────────────────────────────────────────────
local function playSound(soundConfig)
    PlaySoundFrontend(-1, soundConfig.name, soundConfig.ref, true)
end

local function notify(type, description)
    lib.notify({ type = type, description = description })
end

-- ─── skill check ─────────────────────────────────────────────────────────────
-- bl_ui Progress minigame: synchronous, returns a boolean.
--   exports.bl_ui:Progress(iterations, difficulty)
-- Returns two values: (ran, success).
--   ran     = true when the skillcheck UI actually displayed (no export error)
--   success = whether the player passed it
-- The two-value return lets the caller distinguish a real fail (punish) from
-- a missing/broken export (don't punish — the UI never appeared).
local function runSkillCheck()
    local ok, result = pcall(function()
        return exports.bl_ui:Progress(
            config.SKILLCHECK.iterations,
            config.SKILLCHECK.difficulty
        )
    end)
    if not ok then
        Logger.error('bl_ui Progress export failed:', tostring(result))
        return false, false
    end
    return true, result == true
end

-- ─── stuck punishment ────────────────────────────────────────────────────────
-- Fixed 5s lock with finite anim duration. Self-terminates even if everything
-- else fails.
local function applyStuckPunishment(ped)
    local anim = config.ANIMATION.stuck
    playAnim(ped, anim)

    local stuckUntil = GetGameTimer() + config.STUCK.durationMs

    while GetGameTimer() < stuckUntil do
        DisablePlayerFiring(PlayerId(), true)
        disableMovementControls()
        DisableControlAction(0, 245, true) -- chat
        Wait(0)
    end

    stopAnim(ped, anim)
end

-- ─── translated reasons ──────────────────────────────────────────────────────
local REJECT_REASONS = {
    no_crowbar      = 'You need a crowbar in hand.',
    player_cooldown = 'Wait before trying another postbox.',
    invalid_payload = 'Something went wrong.',
}

-- ─── main flow ───────────────────────────────────────────────────────────────
local function attemptRobbery(entity)
    local entityCoords = GetEntityCoords(entity)

    local accepted, reason = lib.callback.await(
        'postbox_robbery:server:requestRobbery', false, { coords = entityCoords }
    )

    if not accepted then
        notify('error', REJECT_REASONS[reason] or 'Cannot rob this right now.')
        return
    end

    setActive(true)

    local ped     = PlayerPedId()
    local robbery = Robbery:new(entity, GetEntityCoords(ped))

    startInterruptWatcher(robbery)
    startControlsBlocker(robbery)

    -- Kick off the animation + sound in a parallel thread so the skillcheck
    -- pops up immediately. loadAnim() yields while the dict streams in, so
    -- running it on the main thread would delay the UI for ~50ms.
    playSound(config.SOUND.pry)
    CreateThread(function()
        if robbery:isCancelled() then return end
        playAnim(ped, config.ANIMATION.pry)
    end)

    local skillCheckRan, hackSucceeded = runSkillCheck()

    stopAnim(ped, config.ANIMATION.pry)

    if robbery:isCancelled() then
        notify('error', 'Interrupted.')
        lib.callback.await('postbox_robbery:server:completeRobbery', false, {
            coords  = entityCoords,
            success = false,
        })
    elseif not skillCheckRan then
        -- Export was missing or threw — never show the stuck punishment for
        -- this case; the player did not actually get a chance to fail.
        notify('error', 'Skillcheck failed to load. Try again shortly.')
        lib.callback.await('postbox_robbery:server:completeRobbery', false, {
            coords  = entityCoords,
            success = false,
        })
    elseif hackSucceeded then
        local ok, result = lib.callback.await('postbox_robbery:server:completeRobbery', false, {
            coords  = entityCoords,
            success = true,
        })
        if ok and result and result.cash then
            notify('success', ('You found $%d in the postbox.'):format(result.cash))
        end
    else
        -- Genuine skillcheck failure — apply the stuck punishment.
        playSound(config.SOUND.fail)
        lib.callback.await('postbox_robbery:server:completeRobbery', false, {
            coords  = entityCoords,
            success = false,
        })

        -- Stop watcher threads before the stuck loop — it runs its own control
        -- lock, and leaving the original blocker alive would keep the player
        -- frozen forever once the stuck animation ends.
        robbery:cancel()

        if math.random(1, 100) <= config.STUCK.chance then
            notify('error', 'Your hand is stuck!')
            applyStuckPunishment(ped)
        else
            notify('error', 'No luck this time.')
        end
    end

    -- Always end the robbery: stops watcher threads, restores controls,
    -- clears any leftover anim/secondary task so the player can move freely.
    robbery:cancel()
    clearPedAnimState(ped)
    setActive(false)
end

function M.start(entity)
    if isActive() then return end
    if not DoesEntityExist(entity) then return end
    CreateThread(function()
        local ok, err = pcall(attemptRobbery, entity)
        if not ok then
            Logger.error('robbery error:', tostring(err))
            setActive(false)
        end
    end)
end

function M.isActive()
    return isActive()
end

return M
