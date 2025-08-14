local log = AxIdentity.log
local cfg = AxIdentity and AxIdentity.cfg or {}
local SVC = AxIdentity.svc

-- Hilfsfunktion: src anhand License finden (falls das Core-Event kein src mitsendet)
local function findSrcByLicense(license)
  if not license then return nil end
  for _, sid in ipairs(GetPlayers()) do
    local s = tonumber(sid)
    for i = 0, GetNumPlayerIdentifiers(s) - 1 do
      local id = GetPlayerIdentifier(s, i)
      if id == license then return s end
    end
  end
  return nil
end

-- Auto-Open UI, wenn der Core meldet "character ready"
-- Core kann (cid, uid [, src]) senden – src ist optional
RegisterNetEvent('Axiom:character:ready', function(cid, uid, evSrc)
  local reqId = log.newCid()
  if not cfg.auto_open_on_ready then return end
  if not uid or not cid then return end

  -- Daten bevorzugt über UID laden
  local data = SVC.getByUid(uid)
  if not data then
    -- Fallback: evtl. sofort nach Join noch nicht im Join-Join sichtbar → via Source versuchen
    if evSrc and evSrc ~= 0 and evSrc ~= -1 then
      data = SVC.getBySrc(evSrc)
    end
  end
  if not data then return end

  -- Ziel-Player (src) bestimmen
  local targetSrc = evSrc
  if (not targetSrc) or targetSrc == 0 or targetSrc == -1 then
    targetSrc = findSrcByLicense(data.license)
  end
  if not targetSrc then return end

  -- ViewModel + an Client schicken → Client öffnet UI
  local vm = SVC.viewModel(data)
  TriggerClientEvent('axi-id:response', targetSrc, { ok=true, data=vm })
  log.info(reqId, 'auto-open sent to src=%s uid=%s cid=%s', tostring(targetSrc), tostring(vm.uid), tostring(cid))
end)
