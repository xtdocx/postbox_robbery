-- Tracks the state of a single in-progress robbery on the client.

---@class Robbery : OxClass
---@field private entity number
---@field private originCoords vector3
---@field private startedAt number
---@field private cancelled boolean
local Robbery = lib.class('Robbery')

function Robbery:constructor(entity, originCoords)
    self.entity       = entity
    self.originCoords = originCoords
    self.startedAt    = GetGameTimer()
    self.cancelled    = false
end

function Robbery:getEntity()
    return self.entity
end

function Robbery:getOriginCoords()
    return self.originCoords
end

function Robbery:cancel()
    self.cancelled = true
end

function Robbery:isCancelled()
    return self.cancelled
end

function Robbery:hasMovedTooFar(maxDistance)
    local pedCoords = GetEntityCoords(PlayerPedId())
    return #(pedCoords - self.originCoords) > maxDistance
end

function Robbery:elapsedMs()
    return GetGameTimer() - self.startedAt
end

return Robbery
