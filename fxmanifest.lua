fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'postbox_robbery'
author 'lapn'
description 'Immersive postbox robbery system for Qbox / ox_target / bl_ui'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
}

client_scripts {
    'client/main.lua',
    'client/robbery.lua',
    'client/dispatch.lua',
}

server_scripts {
    'server/main.lua',
}

files {
    'shared/config.lua',
    'shared/utils/random.lua',
    'shared/utils/logger.lua',
    'shared/classes/robbery.lua',
    'modules/cooldowns.lua',
    'modules/rewards.lua',
}

dependencies {
    'ox_lib',
    'qbx_core',
    'ox_target',
    'ox_inventory',
    'bl_ui',
}
