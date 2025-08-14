-- Schema-agnostischer Identity-Resolver; lädt Identifiers erst nach
-- Schema-Probe und vermeidet so "Unknown column"-Crashes auf
-- unterschiedlichen Datenbank-Schemata.
AxIdentity = AxIdentity or {}
AxIdentity.svc = AxIdentity.svc or {}

local CORE = 'Axiom-Core'
local cfg  = AxIdentity.cfg or {}

-- Wrapper auf Core-DB
local function DbSingle(q, p) return exports[CORE]:DbSingle(q, p) end
local function DbScalar(q, p) return exports[CORE]:DbScalar(q, p) end

local function getLicenseFromSrc(src)
  if not src or src == 0 then return nil end
  local first
  for i = 0, GetNumPlayerIdentifiers(src) - 1 do
    local id = GetPlayerIdentifier(src, i)
    if not first then first = id end
    if id and id:find('license:') == 1 then return id end
  end
  return first  -- Fallback (steam:/fivem:* etc.)
end

local function maskLicense(s)
  if not cfg.mask_license or not s then return s end
  local keep = cfg.mask_prefix or 8
  if #s <= keep + 4 then return s end
  return s:sub(1, keep) .. '…' .. s:sub(-4)
end

-- ===== Schema-Erkennung (gecached) =========================================
local HAS = { probed = false, ident=false, license=false }

local function probeSchema()
  if HAS.probed then return end
  local ok1, r1 = pcall(function()
    return DbScalar([[
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = DATABASE()
        AND table_name = 'ax_players'
        AND column_name = 'ident_kind'
      LIMIT 1
    ]], {})
  end)
  HAS.ident = (ok1 and r1 == 1) or false

  local ok2, r2 = pcall(function()
    return DbScalar([[
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = DATABASE()
        AND table_name = 'ax_players'
        AND column_name = 'license'
      LIMIT 1
    ]], {})
  end)
  HAS.license = (ok2 and r2 == 1) or false

  HAS.probed = true
end

-- Ident zu einer UID nachladen (je nach Schema)
local function fetchIdentByUid(uid)
  probeSchema()
  if HAS.ident then
    local row = DbSingle('SELECT ident_kind, ident_value FROM ax_players WHERE uid = ? LIMIT 1', { uid })
    if row and row.ident_kind and row.ident_value then
      return row.ident_kind .. ':' .. row.ident_value
    end
  elseif HAS.license then
    local row = DbSingle('SELECT license FROM ax_players WHERE uid = ? LIMIT 1', { uid })
    if row and row.license then return row.license end
  end
  return nil
end

-- Gezielt per Ident suchen (kind:value), modern + legacy fallback
local function fetchByIdent(kind, value)
  probeSchema()
  if HAS.ident then
    local row = DbSingle(([[
      SELECT p.uid, p.name AS player_name, p.first_seen AS player_first_seen, p.last_seen AS player_last_seen,
             c.id AS cid, c.created_at AS char_created_at, c.last_seen AS char_last_seen
      FROM ax_players p
      LEFT JOIN ax_characters c ON c.uid = p.uid
      WHERE p.ident_kind = ? AND p.ident_value = ?
      LIMIT 1
    ]]), { kind, value })
    if row then
      return {
        uid = row.uid, cid = row.cid, name = row.player_name,
        license = kind..':'..value,
        player = { first_seen = row.player_first_seen, last_seen = row.player_last_seen },
        char   = { created_at = row.char_created_at,   last_seen = row.char_last_seen   },
      }
    end
  end
  if HAS.license and kind == 'license' then
    local row = DbSingle(([[
      SELECT p.uid, p.name AS player_name, p.first_seen AS player_first_seen, p.last_seen AS player_last_seen,
             c.id AS cid, c.created_at AS char_created_at, c.last_seen AS char_last_seen
      FROM ax_players p
      LEFT JOIN ax_characters c ON c.uid = p.uid
      WHERE p.license = ?
      LIMIT 1
    ]]), { 'license:'..value })
    if row then
      return {
        uid = row.uid, cid = row.cid, name = row.player_name,
        license = 'license:'..value,
        player = { first_seen = row.player_first_seen, last_seen = row.player_last_seen },
        char   = { created_at = row.char_created_at,   last_seen = row.char_last_seen   },
      }
    end
  end
  return nil
end

-- ===== Basis-Fetch: nur spalten-sichere Felder selektieren ==================
-- (Keine ident_* oder license in der SELECT-Liste, um Schema-Errors zu vermeiden)
local function fetchIdentityBy(where, param)
  local params = (type(param) == 'table') and param or { param }
  local row = DbSingle(([[ 
    SELECT
      p.uid,
      p.name        AS player_name,
      p.first_seen  AS player_first_seen,
      p.last_seen   AS player_last_seen,
      c.id          AS cid,
      c.created_at  AS char_created_at,
      c.last_seen   AS char_last_seen
    FROM ax_players p
    LEFT JOIN ax_characters c ON c.uid = p.uid
    WHERE %s
    LIMIT 1
  ]]):format(where), params)
  if not row then return nil end

  local ident = fetchIdentByUid(row.uid)  -- optional, je nach Schema vorhanden
  return {
    uid     = row.uid,
    cid     = row.cid,
    name    = row.player_name,
    license = ident, -- kann nil sein falls Schema keine Ident-Spalte hat
    player  = { first_seen = row.player_first_seen, last_seen = row.player_last_seen },
    char    = { created_at = row.char_created_at,   last_seen = row.char_last_seen   },
  }
end

-- Resolver: serverId | uid:XXXX | <kind>:<value> | pure uid | pure serverId-string
function AxIdentity.svc.resolveTarget(target)
  if type(target) == 'number' then
    -- 1) Versuche per Identifier vom Spieler
    local ident = getLicenseFromSrc(target) -- "license:", "steam:", "fivem:", ...
    if ident then
      local k, v = ident:match('^(%w+):(.+)$')
      if k and v then
        local hit = fetchByIdent(k, v)
        if hit then return hit end
      end
    end
    -- 2) Fallback: UID über Core erfragen (falls export vorhanden)
    local ok, uid = pcall(function() return exports[CORE]:GetUid(target) end)
    if ok and uid then
      return fetchIdentityBy('p.uid = ?', uid)
    end
    return nil

  elseif type(target) == 'string' then
    if target:find('^uid:') == 1 then
      return fetchIdentityBy('p.uid = ?', target:sub(5))
    end
    -- generisches <kind>:<value>
    local k, v = target:match('^(%w+):(.+)$')
    if k and v then
      return fetchByIdent(k, v)
    end
    -- "123" → ServerId
    if tonumber(target) then
      return AxIdentity.svc.resolveTarget(tonumber(target))
    end
    -- Fallback: pure UID
    return fetchIdentityBy('p.uid = ?', target)
  end
  return nil
end

function AxIdentity.svc.getByUid(uid)
  if not uid or type(uid) ~= 'string' then return nil end
  return fetchIdentityBy('p.uid = ?', uid)
end

function AxIdentity.svc.getBySrc(src)
  -- bevorzugt über ident; wenn Schema das nicht hergibt, versucht resolveTarget den UID-Export
  local ident = getLicenseFromSrc(src)
  if ident then
    local k, v = ident:match('^(%w+):(.+)$')
    if k and v then
      local hit = fetchByIdent(k, v)
      if hit then return hit end
    end
  end
  local ok, uid = pcall(function() return exports[CORE]:GetUid(src) end)
  if ok and uid then return fetchIdentityBy('p.uid = ?', uid) end
  return nil
end

function AxIdentity.svc.getSafe(target)
  local data = AxIdentity.svc.resolveTarget(target)
  if not data then
    return { ok=false, error={ code='E_NOT_FOUND', message='identity not found' } }
  end
  return { ok=true, data=data }
end

function AxIdentity.svc.viewModel(data)
  if not data then return nil end
  local licStr = data.license or 'n/a'
  if cfg.mask_license and licStr ~= 'n/a' then
    licStr = maskLicense(licStr)
  end
  return {
    uid          = data.uid or 'n/a',
    cid          = data.cid or 'n/a',
    name         = data.name or 'n/a',
    lic          = licStr,
    last_seen    = data.player and data.player.last_seen or nil,
    joined       = data.player and data.player.first_seen or nil,
    char_last    = data.char   and data.char.last_seen or nil,
    char_created = data.char   and data.char.created_at or nil,
  }
end
