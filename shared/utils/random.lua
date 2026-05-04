local Random = {}

function Random.range(min, max)
    return math.random(min, max)
end

function Random.chance(percent)
    return math.random(1, 100) <= percent
end

return Random
