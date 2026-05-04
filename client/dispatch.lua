-- Receives the server-side police alert and shows a temporary blip.
-- Replace this with your dispatch system of choice (ps-dispatch, cd_dispatch,
-- ox_dispatch, etc). Kept as a separate file so swapping it out doesn't touch
-- the robbery flow.

local config = require 'shared.config'

local function isPolice()
    -- Qbox: check player groups via qbx_core. Returns truthy when the player
    -- is in any law-enforcement group. Adjust group names to match your server.
    local player = exports.qbx_core:GetPlayerData()
    if not player or not player.job then return false end
    local jobName = player.job.name
    return jobName == 'police' or jobName == 'sheriff' or jobName == 'sasp'
end

local function spawnAlertBlip(coords)
    local blipCfg = config.POLICE_ALERT.blip
    local blip    = AddBlipForCoord(coords.x, coords.y, coords.z)

    SetBlipSprite(blip, blipCfg.sprite)
    SetBlipColour(blip, blipCfg.color)
    SetBlipScale(blip, blipCfg.scale)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(blipCfg.text)
    EndTextCommandSetBlipName(blip)

    SetTimeout(blipCfg.durationMs, function()
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end)
end

RegisterNetEvent('postbox_robbery:client:policeAlert', function(coords)
    if GetInvokingResource() then return end
    if type(coords) ~= 'vector3' then return end
    if not isPolice() then return end
    spawnAlertBlip(coords)
end)
