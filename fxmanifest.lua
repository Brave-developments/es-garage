fx_version 'cerulean'

description 'EyesStore'
author 'Raider#0101'
version '1.0.0'
repository 'https://discord.com/invite/EkwWvFS'

game 'gta5'

lua54 'yes'

client_script { 
    'client/*.lua'
}

server_script {
    'server/*.lua'
}

shared_script {
    '@ox_lib/init.lua',
    'config.lua'
}


ui_page 'index.html'

files {
    'index.html',
    'vue.js',
    'assets/**/*.*',
    'assets/font/*.otf', 
}
-- dependency '/assetpacks'
