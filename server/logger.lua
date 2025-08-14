AxIdentity = AxIdentity or {}

local cfg = AxIdentity.cfg or {}

local LEVELS = { error = 0, warn = 1, info = 2, debug = 3 }
local current = LEVELS[cfg.log_level or 'info'] or LEVELS.info

local function should(level)
  return LEVELS[level] <= current
end

local function format(level, cid, msg, ...)
  local prefix = ('[ax_identity][%s]'):format(level)
  if cid then prefix = prefix .. ('[' .. cid .. ']') end
  local body = msg and msg:format(...) or ''
  return prefix .. ' ' .. body
end

AxIdentity.log = {}

function AxIdentity.log.newCid()
  return ('%08x'):format(math.random(0, 0xffffffff))
end

function AxIdentity.log.info(cid, msg, ...)
  if should('info') then print(format('info', cid, msg, ...)) end
end

function AxIdentity.log.warn(cid, msg, ...)
  if should('warn') then print(format('warn', cid, msg, ...)) end
end

function AxIdentity.log.error(cid, msg, ...)
  if should('error') then print(format('error', cid, msg, ...)) end
end

return AxIdentity.log
