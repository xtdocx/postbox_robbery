-- Centralised logger so we never sprinkle print() through gameplay code.

local Logger = {}

local PREFIX        = '[postbox_robbery]'
local DEBUG_CONVAR  = 'postbox_robbery:debug'

local function format(level, args)
    local parts = {}
    for i = 1, #args do parts[i] = tostring(args[i]) end
    return ('%s [%s] %s'):format(PREFIX, level, table.concat(parts, ' '))
end

function Logger.info(...)
    print(format('INFO', { ... }))
end

function Logger.error(...)
    print(format('ERROR', { ... }))
end

function Logger.debug(...)
    if GetConvar(DEBUG_CONVAR, 'false') ~= 'true' then return end
    print(format('DEBUG', { ... }))
end

return Logger
