fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'cobalt_vehiclekeys'
description 'Vehicle keys, locks, keyfob, lockpicking and hotwiring'
author 'Project Cobalt'
version '1.0.0'

ui_page '_nui/build/index.html'

dependencies {
    'cobalt_core',
    'cobalt_inventory',
    'cobalt_management',
    'ox_lib',
}

ox_libs { 'locale' }

shared_script '@ox_lib/init.lua'

client_script 'client/init.lua'
server_script 'server/init.lua'

files {
    'config.lua',
    'client/*.lua',
    'locales/*.json',
    '_nui/build/index.html',
    '_nui/build/assets/*',
}
