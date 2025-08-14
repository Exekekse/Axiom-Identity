fx_version 'cerulean'
games { 'rdr3' }
lua54 'yes'

name 'Axiom-Identity'
author 'Exe_kekse'
version '0.1.0'
description 'Kleine Identity-NUI für Axiom-Core (read-only)'

-- RedM Hinweis
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

dependency 'Axiom-Core'

ui_page 'html/index.html'

files {
  'html/index.html',
  'html/style.css',
  'html/app.js'
}

server_scripts {
  'server/config.lua',
  'server/identity_svc.lua',
  'server/main.lua'
}

client_scripts {
  'client/main.lua'
}