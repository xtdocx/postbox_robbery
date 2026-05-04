-- Entry point. Wires up the ox_target interaction on every prop_postbox_01a in
-- the world and gates it on the player carrying a crowbar.

local config       = require 'shared.config'
local Logger       = require 'shared.utils.logger'
local robberyModule = require 'client.robbery'

local function getCurrentWeaponHash()
    local _, weaponHash = GetCurrentPedWeapon(PlayerPedId(), true)
    return weaponHash
end

local function hasCrowbarEquipped()
    return getCurrentWeaponHash() == config.REQUIRED_WEAPON
end

local function isBusy()
    return robberyModule.isActive()
end

local function canInteract(entity, distance)
    if isBusy() then return false end
    if not DoesEntityExist(entity) then return false end
    if distance > config.MAX_INTERACT_DIST then return false end
    return hasCrowbarEquipped()
end

local function onSelect(data)
    if not canInteract(data.entity, data.distance) then return end
    robberyModule.start(data.entity)
end

local function setupTarget()
    exports.ox_target:addModel(config.PROP_MODEL, {
        {
            name        = config.TARGET.name,
            label       = config.TARGET.label,
            icon        = config.TARGET.icon,
            distance    = config.MAX_INTERACT_DIST,
            canInteract = canInteract,
            onSelect    = onSelect,
        },
    })
end

local function teardownTarget()
    pcall(function()
        exports.ox_target:removeModel(config.PROP_MODEL, config.TARGET.name)
    end)
end

CreateThread(function()
    setupTarget()
    Logger.info('client initialised')
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    teardownTarget()
end)
