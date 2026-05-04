-- Server-side per-player throttle. Every postbox in the world is always
-- robbable; we only rate-limit how often a given player can attempt one.

local Cooldowns = {}

local playerCooldowns = {}    -- [src] = expiresAt

local function now()
    return GetGameTimer()
end

function Cooldowns.isPlayerOnCooldown(src)
    local expiresAt = playerCooldowns[src]
    return expiresAt ~= nil and expiresAt > now()
end

function Cooldowns.setPlayerCooldown(src, durationMs)
    playerCooldowns[src] = now() + durationMs
end

function Cooldowns.clearPlayer(src)
    playerCooldowns[src] = nil
end

return Cooldowns
