local showing = false

RegisterCommand('idui', function()
  if not showing then
    TriggerServerEvent('axi-id:request')
  else
    SendNUIMessage({ action = 'close' })
    SetNuiFocus(false, false)
    showing = false
  end
end, false)

-- Optional:
-- RegisterKeyMapping('idui', 'Identity öffnen/schließen', 'keyboard', 'F6')

RegisterNetEvent('axi-id:response', function(payload)
  if not payload or payload.ok == false then return end
  SendNUIMessage({ action = 'open', data = payload.data })
  SetNuiFocus(true, true)
  showing = true
end)

RegisterNUICallback('close', function(_, cb)
  SetNuiFocus(false, false)
  showing = false
  cb({ ok = true })
end)
