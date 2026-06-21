--[[
  TimeLoggerStorage — indexed event database backed by SavedVariables.

  WoW addons cannot use external databases; this module treats TimeLoggerDB as a
  structured store with numeric IDs, chronological ordering, and per-character
  indexes so reads stay fast as the log grows into thousands of rows.
]]

local ADDON_NAME = ...
TimeLoggerStorage = TimeLoggerStorage or {}

local Storage = TimeLoggerStorage

local SCHEMA_VERSION = 2

local db

local function MakeCharKey(realm, character)
  return (realm or "") .. "|" .. (character or "")
end

local function MakeSessionKey(character, realm)
  return (character or "") .. "-" .. (realm or "")
end

local function CopyEventRecord(event)
  if not event then
    return nil
  end
  if CopyTable then
    return CopyTable(event)
  end
  return {
    id = event.id,
    unix = event.unix,
    utc = event.utc,
    event = event.event,
    character = event.character,
    realm = event.realm,
    recovery = event.recovery,
  }
end

local function EnsureIndexTables()
  if type(db.indexes) ~= "table" then
    db.indexes = {}
  end
  if type(db.indexes.by_character) ~= "table" then
    db.indexes.by_character = {}
  end
  if type(db.indexes.last_by_character) ~= "table" then
    db.indexes.last_by_character = {}
  end
end

local function RebuildIndexesFromOrder()
  EnsureIndexTables()
  db.indexes.by_character = {}
  db.indexes.last_by_character = {}

  for _, id in ipairs(db.event_order) do
    local event = db.events[id]
    if event then
      local charKey = MakeCharKey(event.realm, event.character)
      local ids = db.indexes.by_character[charKey]
      if not ids then
        ids = {}
        db.indexes.by_character[charKey] = ids
      end
      ids[#ids + 1] = id
      db.indexes.last_by_character[charKey] = id
    end
  end
end

local function MigrateFromLegacyEvents(legacyEvents)
  db.schema_version = SCHEMA_VERSION
  db.next_event_id = 1
  db.event_order = {}
  db.events = {}
  db.sessions = nil
  EnsureIndexTables()

  for i = 1, #legacyEvents do
    local legacy = legacyEvents[i]
    if type(legacy) == "table" then
      local id = db.next_event_id
      db.next_event_id = id + 1
      db.events[id] = {
        id = id,
        unix = legacy.unix,
        utc = legacy.utc,
        event = legacy.event,
        character = legacy.character,
        realm = legacy.realm,
        recovery = legacy.recovery,
      }
      db.event_order[#db.event_order + 1] = id
    end
  end

  RebuildIndexesFromOrder()
  return #db.event_order
end

function Storage:EnsureDB()
  if type(TimeLoggerDB) ~= "table" then
    TimeLoggerDB = {}
  end
  db = TimeLoggerDB

  if type(db.played_totals) ~= "table" then
    db.played_totals = {}
  end

  local version = tonumber(db.schema_version) or 1
  if version < SCHEMA_VERSION then
    local legacyEvents = db.events
    local migratedCount = 0
    if type(legacyEvents) == "table" and #legacyEvents > 0 and legacyEvents[1] and not legacyEvents[1].id then
      migratedCount = MigrateFromLegacyEvents(legacyEvents)
    elseif type(db.event_order) ~= "table" or type(db.events) ~= "table" then
      migratedCount = MigrateFromLegacyEvents(type(legacyEvents) == "table" and legacyEvents or {})
    else
      db.schema_version = SCHEMA_VERSION
      db.next_event_id = db.next_event_id or 1
      db.event_order = db.event_order or {}
      db.events = db.events or {}
      EnsureIndexTables()
      RebuildIndexesFromOrder()
    end
    if migratedCount > 0 then
      print(string.format(
        "|cff00ff00TimeLogger:|r Upgraded storage to indexed database (schema v%d). Migrated %d events.",
        SCHEMA_VERSION,
        migratedCount
      ))
    end
  else
    db.next_event_id = db.next_event_id or 1
    db.event_order = db.event_order or {}
    db.events = db.events or {}
    EnsureIndexTables()
    if not next(db.indexes.last_by_character) and #db.event_order > 0 then
      RebuildIndexesFromOrder()
    end
  end

  return db
end

function Storage:GetDB()
  self:EnsureDB()
  return db
end

function Storage:MakeCharKey(realm, character)
  return MakeCharKey(realm, character)
end

function Storage:GetEventCount()
  self:EnsureDB()
  return #db.event_order
end

function Storage:IterateEvents(callback)
  self:EnsureDB()
  for i = 1, #db.event_order do
    local id = db.event_order[i]
    local event = db.events[id]
    if event and callback(event, i, id) == false then
      break
    end
  end
end

function Storage:GetLastEvent()
  self:EnsureDB()
  local n = #db.event_order
  if n == 0 then
    return nil
  end
  return db.events[db.event_order[n]]
end

function Storage:GetLastEventForCharacter(character, realm)
  self:EnsureDB()
  local charKey = MakeCharKey(realm, character)
  local id = db.indexes.last_by_character[charKey]
  if not id then
    return nil
  end
  return db.events[id]
end

function Storage:GetEventsForCharacter(character, realm)
  self:EnsureDB()
  local charKey = MakeCharKey(realm, character)
  local ids = db.indexes.by_character[charKey]
  if not ids then
    return {}
  end

  local result = {}
  for i = 1, #ids do
    result[i] = db.events[ids[i]]
  end
  return result
end

function Storage:InvalidateSessions()
  self:EnsureDB()
  db.sessions = nil
end

function Storage:BuildSessions(forceRebuild)
  self:EnsureDB()
  if not forceRebuild and type(db.sessions) == "table" then
    return db.sessions
  end

  local sessions = {}
  local openSessions = {}

  for i = 1, #db.event_order do
    local event = db.events[db.event_order[i]]
    if event then
      local key = MakeSessionKey(event.character, event.realm)

      if event.event == "login" then
        if openSessions[key] then
          local prevIdx = openSessions[key]
          sessions[prevIdx].status = "no_logout"
        end

        table.insert(sessions, {
          start_unix = event.unix,
          start_utc = event.utc,
          character = event.character,
          realm = event.realm,
          status = "open",
          end_unix = 0,
          end_utc = "",
        })
        openSessions[key] = #sessions
      elseif event.event == "logout" then
        if openSessions[key] then
          local sIdx = openSessions[key]
          local session = sessions[sIdx]
          session.end_unix = event.unix
          session.end_utc = event.utc
          session.duration_sec = event.unix - session.start_unix
          session.status = event.recovery and "recovered" or "closed"
          openSessions[key] = nil
        end
      end
    end
  end

  db.sessions = sessions
  return sessions
end

function Storage:InsertEvent(fields)
  self:EnsureDB()

  local id = db.next_event_id
  db.next_event_id = id + 1

  local event = {
    id = id,
    unix = fields.unix,
    utc = fields.utc,
    event = fields.event,
    character = fields.character,
    realm = fields.realm,
    recovery = fields.recovery,
  }

  db.events[id] = event
  db.event_order[#db.event_order + 1] = id

  local charKey = MakeCharKey(event.realm, event.character)
  local ids = db.indexes.by_character[charKey]
  if not ids then
    ids = {}
    db.indexes.by_character[charKey] = ids
  end
  ids[#ids + 1] = id
  db.indexes.last_by_character[charKey] = id

  self:InvalidateSessions()
  return event
end

function Storage:CopyEventsSnapshot()
  self:EnsureDB()
  local snapshot = {}
  for i = 1, #db.event_order do
    snapshot[i] = CopyEventRecord(db.events[db.event_order[i]])
  end
  return snapshot
end

function Storage:PruneBefore(cutoffUnix)
  self:EnsureDB()

  local keptOrder = {}
  local keptCount = 0

  for i = 1, #db.event_order do
    local id = db.event_order[i]
    local event = db.events[id]
    if event and (event.unix or 0) >= cutoffUnix then
      keptCount = keptCount + 1
      keptOrder[keptCount] = id
    else
      db.events[id] = nil
    end
  end

  db.event_order = keptOrder
  RebuildIndexesFromOrder()
  self:InvalidateSessions()

  return keptCount
end

function Storage:GetPlayedTotal(charKey)
  self:EnsureDB()
  return db.played_totals[charKey]
end

function Storage:SetPlayedTotal(charKey, totalSec)
  self:EnsureDB()
  db.played_totals[charKey] = totalSec
end

function Storage:SumPlayedTotals()
  self:EnsureDB()
  local allTotal = 0
  for _, sec in pairs(db.played_totals) do
    allTotal = allTotal + (sec or 0)
  end
  return allTotal
end

function Storage:GetTempLogout()
  self:EnsureDB()
  return db.temp_logout
end

function Storage:SetTempLogout(snapshot)
  self:EnsureDB()
  db.temp_logout = snapshot
end

function Storage:ClearTempLogout()
  self:EnsureDB()
  db.temp_logout = nil
end

function Storage:ShouldRefreshBackup(nowUnix)
  self:EnsureDB()
  if not db.events_backup or not db.events_backup_time then
    return true
  end
  return (nowUnix - db.events_backup_time) > 3600
end

function Storage:WriteEventsBackup(snapshot, nowUnix)
  self:EnsureDB()
  db.events_backup = snapshot
  db.events_backup_time = nowUnix
end

function Storage:GetBackupRowCount()
  self:EnsureDB()
  if type(db.events_backup) ~= "table" then
    return 0
  end
  return #db.events_backup
end

function Storage:SumCharacterPlaytimeFromEvents(character, realm, nowUnix)
  self:EnsureDB()
  local total = 0
  local openStart
  local events = self:GetEventsForCharacter(character, realm)

  for i = 1, #events do
    local event = events[i]
    if event.event == "login" then
      openStart = event.unix or 0
    elseif event.event == "logout" then
      local endUnix = event.unix or 0
      if openStart and endUnix > openStart then
        total = total + (endUnix - openStart)
      end
      openStart = nil
    end
  end

  if openStart and nowUnix > openStart then
    total = total + (nowUnix - openStart)
  end

  return total
end
