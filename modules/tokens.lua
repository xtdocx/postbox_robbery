-- Server-side one-shot tokens for postbox robberies. The server issues a
-- token on requestRobbery (after validating weapon, cooldown, and distance)
-- and stores the validated origin coords inside it. The client then echoes
-- the token back on report*, so the completion handlers never have to trust
-- client-supplied coords or success-flag context — only the token.

local Tokens = {}

local tokens  = {}    -- [token] = { src, coords, issuedAt, expiresAt, consumed }
local counter = 0

local TOKEN_TOMBSTONE_MS = 5000

local function now()
    return GetGameTimer()
end

-- Random-padded counter. The counter alone guarantees uniqueness across the
-- session; the random suffix makes guessing a live token infeasible.
local function generateToken()
    counter = counter + 1
    return ('%d-%08x%08x'):format(
        counter,
        math.random(0, 0xFFFFFFFF),
        math.random(0, 0xFFFFFFFF)
    )
end

function Tokens.issue(src, coords, ttlMs)
    local token = generateToken()
    tokens[token] = {
        src       = src,
        coords    = coords,
        issuedAt  = now(),
        expiresAt = now() + ttlMs,
        consumed  = false,
    }
    return token, tokens[token]
end

-- Returns the record on success, or (nil, errorCode) on failure. Does NOT
-- consume — call Tokens.consume after running any downstream rule checks so
-- a failed re-validation still burns the token.
function Tokens.peek(token, src)
    if type(token) ~= 'string' then return nil, 'invalid_token' end
    local record = tokens[token]
    if not record           then return nil, 'unknown_token'        end
    if record.consumed      then return nil, 'token_consumed'       end
    if record.src ~= src    then return nil, 'token_owner_mismatch' end
    if now() > record.expiresAt then return nil, 'token_expired'    end
    return record
end

-- Marks the token consumed, then schedules cleanup. We keep the record around
-- briefly so a duplicate call returns 'token_consumed' (clearer than
-- 'unknown_token') if the client retries.
function Tokens.consume(token)
    local record = tokens[token]
    if not record then return false end
    record.consumed = true
    SetTimeout(TOKEN_TOMBSTONE_MS, function() tokens[token] = nil end)
    return true
end

function Tokens.clearForPlayer(src)
    for token, record in pairs(tokens) do
        if record.src == src then tokens[token] = nil end
    end
end

return Tokens
