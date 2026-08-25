local ADDON_NAME = ...

local DEFAULT_HEARTBEAT_SEC = 300
local MIN_HEARTBEAT_SEC = 60
local MAX_HEARTBEAT_SEC = 600
local HEARTBEAT_STEP_SEC = 60

local pendingPruneDays
local pendingRestoreRows
local tempLogoutTicker
local lastPlayedRequestUnix

--- Centralized time collection using the synchronized Unix timestamp.
local function GetUnix()
  if GetServerTime then
    return GetServerTime()
  end
  return time()
end

local function EnsureDB()
  TimeLoggerStorage:EnsureDB()
end

local function NormalizeHeartbeatSeconds(value)
  value = tonumber(value) or DEFAULT_HEARTBEAT_SEC
  value = math.floor((value / HEARTBEAT_STEP_SEC) + 0.5) * HEARTBEAT_STEP_SEC
  return math.max(MIN_HEARTBEAT_SEC, math.min(MAX_HEARTBEAT_SEC, value))
end

local function GetHeartbeatSeconds()
  EnsureDB()
  local db = TimeLoggerStorage:GetDB()
  local heartbeatSec = NormalizeHeartbeatSeconds(db.heartbeatSec)
  db.heartbeatSec = heartbeatSec
  return heartbeatSec
end

--- ISO 8601 instant in UTC (Z suffix); independent of player timezone.
local function UtcIso(unix)
  if unix then
    return date("!%Y-%m-%dT%H:%M:%SZ", unix)
  end
  return date("!%Y-%m-%dT%H:%M:%SZ")
end

local function CsvEscape(s)
  s = tostring(s or "")
  if s:find('["\r\n,]') then
    s = '"' .. s:gsub('"', '""') .. '"'
  end
  return s
end

local function JsonEscape(s)
  s = tostring(s or "")
  s = s:gsub("\\", "\\\\"):gsub('"', '\\"')
  return s:gsub("[\000-\031]", function(char)
    local byte = char:byte()
    if byte == 8 then
      return "\\b"
    elseif byte == 9 then
      return "\\t"
    elseif byte == 10 then
      return "\\n"
    elseif byte == 12 then
      return "\\f"
    elseif byte == 13 then
      return "\\r"
    end
    return string.format("\\u%04x", byte)
  end)
end

local function BuildEventFields(kind, unix, extra)
  unix = unix or GetUnix()
  local fields = {
    unix = unix,
    utc = UtcIso(unix),
    event = kind,
    character = UnitName("player") or "",
    realm = GetRealmName() or "",
  }
  if extra then
    for key, value in pairs(extra) do
      fields[key] = value
    end
  end
  local context = TimeLoggerContext:Collect(unix)
  for key, value in pairs(context) do
    if fields[key] == nil then
      fields[key] = value
    end
  end

  -- Persist subscription active boolean at the exact moment of the event.
  local subExpiresUnix = 0
  if TimeLoggerStorage and type(TimeLoggerStorage.GetDB) == "function" then
    local db = TimeLoggerStorage:GetDB()
    if db and db.subExpiresUnix then
      subExpiresUnix = db.subExpiresUnix
    end
  end
  fields.subActive = (unix <= subExpiresUnix)

  return fields
end

--- Last-known-alive snapshot (same shape as an event). Updated at the configured heartbeat interval while in-game.
--- Used only when the last stored event is login and we need a synthetic logout after crash / missing PLAYER_LOGOUT.
local function UpdateTempLogout()
  EnsureDB()
  TimeLoggerStorage:SetTempLogout(BuildEventFields("logout"))
end

local function StopTempLogoutTicker()
  if tempLogoutTicker then
    tempLogoutTicker:Cancel()
    tempLogoutTicker = nil
  end
end

local function StartTempLogoutTicker()
  StopTempLogoutTicker()
  tempLogoutTicker = C_Timer.NewTicker(GetHeartbeatSeconds(), UpdateTempLogout)
end

local function SetHeartbeatSeconds(value)
  EnsureDB()
  local heartbeatSec = NormalizeHeartbeatSeconds(value)
  local db = TimeLoggerStorage:GetDB()
  db.heartbeatSec = heartbeatSec
  if tempLogoutTicker then
    StartTempLogoutTicker()
  end
  return heartbeatSec
end

--- If the last row is login (no logout was saved), insert a logout using the last heartbeat, if valid.
local function RecoverOrphanLogout()
  EnsureDB()
  local last = TimeLoggerStorage:GetLastEvent()
  if not last or (last.event or "") ~= "login" then
    return
  end

  local t = TimeLoggerStorage:GetTempLogout()
  if type(t) ~= "table" or not t.unix then
    return
  end

  local now = GetUnix()
  if t.unix < (last.unix or 0) then
    return
  end
  if t.unix >= now then
    return
  end

  TimeLoggerStorage:InsertEvent(BuildEventFields("logout", t.unix, {
    utc = t.utc or UtcIso(),
    character = t.character or last.character,
    realm = t.realm or last.realm,
    recovery = true,
    patch = t.patch or last.patch,
    expansion = t.expansion or last.expansion,
    location = t.location,
    weekday = t.weekday,
    subscription = t.subscription or last.subscription,
    local_dt = t.local_dt,
  }))
end

local function Record(kind)
  EnsureDB()
  TimeLoggerStorage:InsertEvent(BuildEventFields(kind))
end

local function EnrichLastLoginLocation()
  local char = UnitName("player") or ""
  local realm = GetRealmName() or ""
  local last = TimeLoggerStorage:GetLastEventForCharacter(char, realm)
  if not last or last.event ~= "login" then
    return
  end
  local location = TimeLoggerContext:GetLocationName()
  if location == "" or location == (last.location or "") then
    return
  end
  TimeLoggerStorage:UpdateEvent(last.id, { location = location })
  if exportFrame and exportFrame:IsShown() then
    RefreshTableView()
  end
end

local function CurrentCharKey()
  return TimeLoggerStorage:MakeCharKey(GetRealmName() or "", UnitName("player") or "")
end

-- Export Helpers (clipboard serialization) -----------------------------------

local function FormatDuration(sec)
  sec = math.max(0, math.floor(sec or 0))
  local h = math.floor(sec / 3600)
  local m = math.floor((sec % 3600) / 60)
  local s = sec % 60
  return string.format("%02d:%02d:%02d", h, m, s)
end

local function GetCurrentSessionDurationSec()
  EnsureDB()
  local char = UnitName("player") or ""
  local realm = GetRealmName() or ""
  local last = TimeLoggerStorage:GetLastEventForCharacter(char, realm)
  if not last then
    return nil
  end
  if last.event == "logout" then
    return nil
  end
  if last.event == "login" then
    return GetUnix() - (last.unix or 0)
  end
  return nil
end

local function BuildCurrentSessionLabel()
  local sec = GetCurrentSessionDurationSec()
  local value = sec and FormatDuration(sec) or TimeLoggerL("UI_SESSION_NA")
  return TimeLoggerL("UI_SESSION_LABEL", value)
end

local function SaveCurrentCharacterPlayed(totalSec)
  EnsureDB()
  local n = tonumber(totalSec)
  if not n then
    return
  end
  TimeLoggerStorage:SetPlayedTotal(CurrentCharKey(), math.max(0, math.floor(n)))
end

local function RequestPlayedTotals(force)
  if not RequestTimePlayed then
    return
  end
  local now = GetUnix()
  if not force and lastPlayedRequestUnix and (now - lastPlayedRequestUnix) < 60 then
    return
  end
  lastPlayedRequestUnix = now
  RequestTimePlayed()
end

local function BuildPlaytimeTotals()
  EnsureDB()
  local currentTotal = TimeLoggerStorage:GetPlayedTotal(CurrentCharKey()) or 0
  return currentTotal, TimeLoggerStorage:SumPlayedTotals()
end

local function DoPrune(days)
  EnsureDB()
  local now = GetUnix()
  local cutoff = now - (days * 86400)

  if TimeLoggerStorage:ShouldRefreshBackup(now) then
    TimeLoggerStorage:WriteEventsBackup(TimeLoggerStorage:CopyEventsSnapshot(), now)
  end

  local keptCount = TimeLoggerStorage:PruneBefore(cutoff)
  TimeLoggerLocale:Print(
    "MSG_PRUNE_DONE",
    days,
    keptCount,
    TimeLoggerStorage:GetBackupRowCount()
  )
end

local function RestoreEventsBackup()
  EnsureDB()
  local restoredCount = TimeLoggerStorage:RestoreEventsBackup()
  if restoredCount == nil then
    TimeLoggerLocale:PrintWarning("MSG_NO_BACKUP")
    return
  end
  TimeLoggerLocale:Print("MSG_RESTORE_DONE", restoredCount)
end

-- Export UI -----------------------------------------------------------------

local exportFrame
local dataTableView
local sessionDurationLabel
local currentCharacterTotalLabel
local allCharactersTotalLabel

local UI_COLORS = {
  frameBg = { 0.05, 0.05, 0.06, 0.96 },
  frameBorder = { 0.78, 0.62, 0.18, 0.9 },
  title = { 0.95, 0.78, 0.28, 1 },
  subtitle = { 0.72, 0.72, 0.76, 1 },
  divider = { 0.42, 0.36, 0.22, 0.55 },
  buttonActive = { 0.22, 0.18, 0.10, 1 },
  buttonInactive = { 0.10, 0.10, 0.11, 0.85 },
}

local function GetEventColumns()
  return {
    { key = "unix", title = TimeLoggerL("COL_UNIX"), width = 72 },
    { key = "utc", title = TimeLoggerL("COL_UTC"), width = 128 },
    { key = "local_dt", title = TimeLoggerL("COL_LOCAL_DT"), width = 128 },
    {
      key = "weekday",
      title = TimeLoggerL("COL_WEEKDAY"),
      width = 72,
      getValue = function(row)
        return TimeLoggerLocale:FormatWeekday(row.weekday)
      end,
    },
    {
      key = "event",
      title = TimeLoggerL("COL_EVENT"),
      width = 64,
      getValue = function(row)
        return TimeLoggerLocale:FormatEventType(row.event)
      end,
    },
    { key = "character", title = TimeLoggerL("COL_CHARACTER"), width = 96 },
    { key = "realm", title = TimeLoggerL("COL_REALM"), width = 96 },
    { key = "location", title = TimeLoggerL("COL_LOCATION"), width = 140 },
    { key = "patch", title = TimeLoggerL("COL_PATCH"), width = 56 },
    { key = "expansion", title = TimeLoggerL("COL_EXPANSION"), width = 100 },
    {
      key = "recovery",
      title = TimeLoggerL("COL_RECOVERY"),
      width = 60,
      getValue = function(row)
        return TimeLoggerLocale:FormatRecovery(row.recovery)
      end,
      muted = function(row)
        return not row.recovery
      end,
    },
  }
end

local function GetSessionColumns()
  return {
    { key = "id", title = TimeLoggerL("COL_ID"), width = 32 },
    { key = "start_unix", title = TimeLoggerL("COL_START"), width = 72 },
    { key = "start_utc", title = TimeLoggerL("COL_START_UTC"), width = 120 },
    { key = "start_local_dt", title = TimeLoggerL("COL_START_LOCAL"), width = 120 },
    { key = "end_unix", title = TimeLoggerL("COL_END"), width = 72 },
    { key = "end_utc", title = TimeLoggerL("COL_END_UTC"), width = 120 },
    { key = "end_local_dt", title = TimeLoggerL("COL_END_LOCAL"), width = 120 },
    {
      key = "duration_sec",
      title = TimeLoggerL("COL_DURATION"),
      width = 72,
      getValue = function(row)
        return FormatDuration(row.duration_sec or 0)
      end,
    },
    { key = "patch", title = TimeLoggerL("COL_PATCH"), width = 52 },
    { key = "expansion", title = TimeLoggerL("COL_EXPANSION"), width = 92 },
    { key = "start_location", title = TimeLoggerL("COL_START_LOCATION"), width = 120 },
    { key = "end_location", title = TimeLoggerL("COL_END_LOCATION"), width = 120 },
    {
      key = "weekday",
      title = TimeLoggerL("COL_WEEKDAY"),
      width = 68,
      getValue = function(row)
        return TimeLoggerLocale:FormatWeekday(row.weekday)
      end,
    },
    { key = "character", title = TimeLoggerL("COL_CHARACTER"), width = 88 },
    { key = "realm", title = TimeLoggerL("COL_REALM"), width = 88 },
    {
      key = "status",
      title = TimeLoggerL("COL_STATUS"),
      width = 68,
      getValue = function(row)
        return TimeLoggerLocale:FormatSessionStatus(row.status)
      end,
    },
  }
end

local function BuildEventRows()
  local rows = {}
  TimeLoggerStorage:IterateEvents(function(event)
    rows[#rows + 1] = {
      unix = event.unix or 0,
      utc = event.utc or "",
      local_dt = event.local_dt or "",
      weekday = event.weekday,
      event = event.event or "",
      character = event.character or "",
      realm = event.realm or "",
      location = event.location or "",
      patch = event.patch or "",
      expansion = event.expansion or "",
      subscription = event.subscription or "",
      recovery = event.recovery,
      subActive = event.subActive,
    }
  end)
  return rows
end

local function BuildSessionRows()
  local rows = {}
  local sessions = TimeLoggerStorage:BuildSessions(false)
  for i = #sessions, 1, -1 do
    local session = sessions[i]
    rows[#rows + 1] = {
      id = #rows + 1,
      start_unix = session.start_unix or 0,
      start_utc = session.start_utc or "",
      start_local_dt = session.start_local_dt or "",
      end_unix = session.end_unix or 0,
      end_utc = session.end_utc or "",
      end_local_dt = session.end_local_dt or "",
      duration_sec = session.duration_sec or 0,
      patch = session.patch or "",
      expansion = session.expansion or "",
      start_location = session.start_location or "",
      end_location = session.end_location or "",
      weekday = session.weekday,
      subscription = session.subscription or "",
      subActive = session.subActive,
      character = session.character or "",
      realm = session.realm or "",
      status = session.status or "",
    }
  end
  return rows
end

local function IsSessionsMode()
  -- Always show sessions now
  return true
end

local function BuildCSVFromEvents(rows)
  local lines = {
    "unix,utc_iso,local_dt,weekday,event,character,realm,location,patch,expansion,subscription,subActive,recovery",
  }
  for _, event in ipairs(rows) do
    table.insert(lines, string.format(
      "%d,%s,%s,%d,%s,%s,%s,%s,%s,%s,%s,%d,%d",
      event.unix or 0,
      CsvEscape(event.utc),
      CsvEscape(event.local_dt),
      event.weekday or 0,
      CsvEscape(event.event),
      CsvEscape(event.character),
      CsvEscape(event.realm),
      CsvEscape(event.location),
      CsvEscape(event.patch),
      CsvEscape(event.expansion),
      CsvEscape(event.subscription),
      event.subActive and 1 or 0,
      event.recovery and 1 or 0))
  end
  return table.concat(lines, "\n")
end

local function BuildJSONFromEvents(rows)
  local parts = { "[" }
  local n = #rows
  for i, event in ipairs(rows) do
    local rec = event.recovery and ',"recovery":true' or ""
    local chunk = string.format(
      '{"unix":%d,"utc":"%s","local_dt":"%s","weekday":%d,"event":"%s","character":"%s","realm":"%s","location":"%s","patch":"%s","expansion":"%s","subscription":"%s","subActive":%s%s}',
      event.unix or 0,
      JsonEscape(event.utc),
      JsonEscape(event.local_dt),
      event.weekday or 0,
      JsonEscape(event.event),
      JsonEscape(event.character),
      JsonEscape(event.realm),
      JsonEscape(event.location),
      JsonEscape(event.patch),
      JsonEscape(event.expansion),
      JsonEscape(event.subscription),
      event.subActive and "true" or "false",
      rec
    )
    if i < n then
      chunk = chunk .. ","
    end
    parts[#parts + 1] = chunk
  end
  parts[#parts + 1] = "]"
  return table.concat(parts, "\n")
end

local function BuildCSVFromSessions(rows)
  local lines = {
    "session_id,start_unix,start_utc,start_local_dt,end_unix,end_utc,end_local_dt,duration_sec,patch,expansion,start_location,end_location,weekday,subscription,subActive,character,realm,status",
  }
  for _, session in ipairs(rows) do
    table.insert(lines, string.format(
      "%d,%d,%s,%s,%d,%s,%s,%d,%s,%s,%s,%s,%d,%s,%d,%s,%s,%s",
      session.id or 0,
      session.start_unix or 0,
      CsvEscape(session.start_utc),
      CsvEscape(session.start_local_dt),
      session.end_unix or 0,
      CsvEscape(session.end_utc),
      CsvEscape(session.end_local_dt),
      session.duration_sec or 0,
      CsvEscape(session.patch),
      CsvEscape(session.expansion),
      CsvEscape(session.start_location),
      CsvEscape(session.end_location),
      session.weekday or 0,
      CsvEscape(session.subscription),
      session.subActive and 1 or 0,
      CsvEscape(session.character),
      CsvEscape(session.realm),
      CsvEscape(session.status)))
  end
  return table.concat(lines, "\n")
end

local function BuildJSONFromSessions(rows)
  local lines = {}
  for _, session in ipairs(rows) do
    table.insert(lines, string.format(
      '  {"id":%d,"start_unix":%d,"start_utc":"%s","start_local_dt":"%s","end_unix":%d,"end_utc":"%s","end_local_dt":"%s","duration":%d,"patch":"%s","expansion":"%s","start_location":"%s","end_location":"%s","weekday":%d,"subscription":"%s","subActive":%s,"char":"%s","realm":"%s","status":"%s"}',
      session.id or 0,
      session.start_unix or 0,
      JsonEscape(session.start_utc),
      JsonEscape(session.start_local_dt),
      session.end_unix or 0,
      JsonEscape(session.end_utc),
      JsonEscape(session.end_local_dt),
      session.duration_sec or 0,
      JsonEscape(session.patch),
      JsonEscape(session.expansion),
      JsonEscape(session.start_location),
      JsonEscape(session.end_location),
      session.weekday or 0,
      JsonEscape(session.subscription),
      session.subActive and "true" or "false",
      JsonEscape(session.character),
      JsonEscape(session.realm),
      JsonEscape(session.status)))
  end
  return "[\n" .. table.concat(lines, ",\n") .. "\n]"
end

local function GetExportRows()
  if dataTableView and dataTableView:HasActiveFilters() then
    return dataTableView:GetFilteredRows()
  end
  -- Always return sessions
  return BuildSessionRows()
end

local function GetExportTextAsCSV()
  EnsureDB()
  local rows = GetExportRows()
  return BuildCSVFromSessions(rows)
end

local function GetExportTextAsJSON()
  EnsureDB()
  local rows = GetExportRows()
  return BuildJSONFromSessions(rows)
end

local function CopyTextToClipboard(text)
  text = text or ""
  if C_ChatInfo and type(C_ChatInfo.CopyStringToClipboard) == "function" then
    local ok, copied = pcall(C_ChatInfo.CopyStringToClipboard, text)
    if ok and copied ~= false then
      TimeLoggerLocale:Print("MSG_COPIED", #text)
      return true
    end
  end
  return false
end

local function CreateGoldButton(parent, width, height, labelText)
  local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
  btn:SetSize(width, height)
  btn:EnableMouse(true)
  btn:RegisterForClicks("LeftButtonUp")
  btn:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    tile = false,
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
  })
  btn:SetBackdropColor(0.14, 0.12, 0.08, 1)
  btn:SetBackdropBorderColor(0.78, 0.62, 0.18, 0.95)

  local label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  label:SetPoint("CENTER")
  label:SetText(labelText)
  label:SetTextColor(0.95, 0.78, 0.28, 1)
  btn:SetFontString(label)

  btn:SetScript("OnEnter", function(self)
    self:SetBackdropColor(0.20, 0.16, 0.10, 1)
  end)
  btn:SetScript("OnLeave", function(self)
    self:SetBackdropColor(0.14, 0.12, 0.08, 1)
  end)

  return btn
end

-- Show a large popup with a selectable edit box so the user can manually copy exported text.
local function ShowExportTextPopup(text, title)
  title = title or TimeLoggerL("UI_TITLE")
  if not TimeLoggerClipboardPopup then
    local f = CreateFrame("Frame", "TimeLoggerClipboardPopup", UIParent, "BackdropTemplate")
    f:SetSize(900, 520)
    f:SetPoint("CENTER")
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetFrameLevel(200)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8x8",
      edgeFile = "Interface\\Buttons\\WHITE8x8",
      tile = false,
      edgeSize = 1,
      insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    f:SetBackdropColor(UI_COLORS.frameBg[1], UI_COLORS.frameBg[2], UI_COLORS.frameBg[3], UI_COLORS.frameBg[4])
    f:SetBackdropBorderColor(UI_COLORS.frameBorder[1], UI_COLORS.frameBorder[2], UI_COLORS.frameBorder[3], UI_COLORS.frameBorder[4])

    local titleText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleText:SetPoint("TOPLEFT", 12, -10)
    titleText:SetJustifyH("LEFT")
    f.titleText = titleText

    local scroll = CreateFrame("ScrollFrame", "TimeLoggerClipboardScrollFrame", f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 12, -40)
    scroll:SetPoint("BOTTOMRIGHT", -28, 40)

    local eb = CreateFrame("EditBox", nil, scroll)
    eb:SetWidth(840)
    eb:SetHeight(420)
    eb:SetMultiLine(true)
    eb:EnableMouse(true)
    eb:SetAutoFocus(false)
    eb:SetFontObject(GameFontNormal)
    eb:SetScript("OnEscapePressed", function()
      f:Hide()
    end)
    scroll:SetScrollChild(eb)
    f.editBox = eb

    local selectBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    selectBtn:SetSize(110, 22)
    selectBtn:SetPoint("BOTTOMLEFT", 12, 8)
    selectBtn:RegisterForClicks("LeftButtonUp")
    selectBtn:SetScript("OnClick", function()
      eb:HighlightText(0, -1)
      eb:SetFocus()
    end)
    f.selectBtn = selectBtn

    local copyBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    copyBtn:SetSize(180, 22)
    copyBtn:SetPoint("LEFT", selectBtn, "RIGHT", 8, 0)
    copyBtn:RegisterForClicks("LeftButtonUp")
    copyBtn:SetScript("OnClick", function()
      local text = eb:GetText() or ""
      if not CopyTextToClipboard(text) then
        eb:HighlightText(0, -1)
        eb:SetFocus()
        TimeLoggerLocale:PrintWarning("MSG_CLIPBOARD_UNAVAILABLE")
      end
    end)
    f.copyBtn = copyBtn

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    closeBtn:SetSize(80, 22)
    closeBtn:SetPoint("BOTTOMRIGHT", -12, 8)
    closeBtn:SetText(CLOSE)
    closeBtn:SetScript("OnClick", function()
      f:Hide()
    end)

    TimeLoggerClipboardPopup = f
  end

  TimeLoggerClipboardPopup.titleText:SetText(title)
  if TimeLoggerClipboardPopup.selectBtn then
    TimeLoggerClipboardPopup.selectBtn:SetText(TimeLoggerL("BTN_SELECT_ALL"))
  end
  if TimeLoggerClipboardPopup.copyBtn then
    TimeLoggerClipboardPopup.copyBtn:SetText(TimeLoggerL("BTN_COPY"))
  end
  TimeLoggerClipboardPopup.editBox:SetText(text or "")
  TimeLoggerClipboardPopup.editBox:HighlightText(0, -1)
  TimeLoggerClipboardPopup:Show()
  TimeLoggerClipboardPopup:Raise()
  TimeLoggerClipboardPopup.editBox:SetFocus()
end

-- Mode button functions removed - no longer needed (single Sessions view only)

local function RefreshTableView()
  if not dataTableView then
    return
  end
  -- Always show sessions view
  dataTableView:SetColumns(GetSessionColumns())
  dataTableView:SetRows(BuildSessionRows())
end

local function RefreshCurrentSessionLabel()
  if sessionDurationLabel then
    sessionDurationLabel:SetText(BuildCurrentSessionLabel())
  end
end

local function RefreshPlaytimeSummaryLabels()
  if not currentCharacterTotalLabel and not allCharactersTotalLabel then
    return
  end
  local currentTotal, allTotal = BuildPlaytimeTotals()
  if currentCharacterTotalLabel then
    currentCharacterTotalLabel:SetText(TimeLoggerL("UI_TOTAL_THIS_CHAR", FormatDuration(currentTotal)))
  end
  if allCharactersTotalLabel then
    allCharactersTotalLabel:SetText(TimeLoggerL("UI_TOTAL_ALL_CHARS", FormatDuration(allTotal)))
  end
end

local function SaveCurrentPlayedFromEventsFallback()
  EnsureDB()
  local key = CurrentCharKey()
  if TimeLoggerStorage:GetPlayedTotal(key) then
    return
  end

  local total = TimeLoggerStorage:SumCharacterPlaytimeFromEvents(
    UnitName("player") or "",
    GetRealmName() or "",
    GetUnix()
  )
  if total > 0 then
    TimeLoggerStorage:SetPlayedTotal(key, math.floor(total))
  end
end

local function CreateExportUI()
  local f = CreateFrame("Frame", "TimeLoggerExportFrame", UIParent, "BackdropTemplate")
  f:SetSize(1140, 640)
  f:SetPoint("CENTER")
  f:SetFrameStrata("DIALOG")
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  f:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    tile = false,
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
  })
  f:SetBackdropColor(UI_COLORS.frameBg[1], UI_COLORS.frameBg[2], UI_COLORS.frameBg[3], UI_COLORS.frameBg[4])
  f:SetBackdropBorderColor(
    UI_COLORS.frameBorder[1],
    UI_COLORS.frameBorder[2],
    UI_COLORS.frameBorder[3],
    UI_COLORS.frameBorder[4]
  )

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 20, -16)
  title:SetJustifyH("LEFT")
  title:SetText(TimeLoggerL("UI_TITLE"))
  title:SetTextColor(UI_COLORS.title[1], UI_COLORS.title[2], UI_COLORS.title[3], 1)

  local subtitle = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
  subtitle:SetText(TimeLoggerL("UI_SUBTITLE"))
  subtitle:SetTextColor(UI_COLORS.subtitle[1], UI_COLORS.subtitle[2], UI_COLORS.subtitle[3], 1)

  local sessionLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  sessionLabel:SetPoint("TOPLEFT", 20, -52)
  sessionLabel:SetText(BuildCurrentSessionLabel())
  sessionLabel:SetTextColor(UI_COLORS.subtitle[1], UI_COLORS.subtitle[2], UI_COLORS.subtitle[3], 1)
  sessionDurationLabel = sessionLabel

  local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  closeBtn:SetPoint("TOPRIGHT", -4, -4)
  closeBtn:SetScript("OnClick", function()
    f:Hide()
  end)

  -- Export buttons header label
  local exportLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  exportLabel:SetPoint("TOPLEFT", 20, -78)
  exportLabel:SetText(TimeLoggerL("UI_EXPORT_SESSIONS"))
  exportLabel:SetTextColor(UI_COLORS.subtitle[1], UI_COLORS.subtitle[2], UI_COLORS.subtitle[3], 1)

  local exportCsvBtn = CreateGoldButton(f, 120, 24, TimeLoggerL("BTN_SESSIONS_CSV"))
  exportCsvBtn:SetPoint("LEFT", exportLabel, "RIGHT", 12, 0)
  exportCsvBtn:SetFrameLevel(f:GetFrameLevel() + 2)
  exportCsvBtn:SetScript("OnClick", function()
    ShowExportTextPopup(GetExportTextAsCSV(), TimeLoggerL("BTN_SESSIONS_CSV"))
  end)

  local exportJsonBtn = CreateGoldButton(f, 120, 24, TimeLoggerL("BTN_SESSIONS_JSON"))
  exportJsonBtn:SetPoint("LEFT", exportCsvBtn, "RIGHT", 12, 0)
  exportJsonBtn:SetFrameLevel(f:GetFrameLevel() + 2)
  exportJsonBtn:SetScript("OnClick", function()
    ShowExportTextPopup(GetExportTextAsJSON(), TimeLoggerL("BTN_SESSIONS_JSON"))
  end)

  local minimapCheck = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
  minimapCheck:SetSize(24, 24)
  minimapCheck:SetPoint("TOPRIGHT", -20, -76)
  minimapCheck:SetChecked(TimeLoggerMinimap:IsEnabled())
  minimapCheck:SetScript("OnClick", function(self)
    TimeLoggerMinimap:SetEnabled(self:GetChecked())
  end)
  f.minimapCheck = minimapCheck

  local minimapLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  minimapLabel:SetPoint("RIGHT", minimapCheck, "LEFT", -4, 0)
  minimapLabel:SetText(TimeLoggerL("UI_MINIMAP_BUTTON"))
  minimapLabel:SetTextColor(UI_COLORS.subtitle[1], UI_COLORS.subtitle[2], UI_COLORS.subtitle[3], 1)

  local topDivider = f:CreateTexture(nil, "ARTWORK")
  topDivider:SetColorTexture(
    UI_COLORS.divider[1],
    UI_COLORS.divider[2],
    UI_COLORS.divider[3],
    UI_COLORS.divider[4]
  )
  topDivider:SetPoint("TOPLEFT", 20, -108)
  topDivider:SetPoint("TOPRIGHT", -20, -108)
  topDivider:SetHeight(1)

  local pruneLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  pruneLabel:SetPoint("BOTTOMLEFT", 20, 44)
  pruneLabel:SetText(TimeLoggerL("UI_DATA_CLEANUP"))
  pruneLabel:SetTextColor(UI_COLORS.subtitle[1], UI_COLORS.subtitle[2], UI_COLORS.subtitle[3], 1)

  local pruneDays = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
  pruneDays:SetSize(50, 20)
  pruneDays:SetPoint("LEFT", pruneLabel, "RIGHT", 8, 0)
  pruneDays:SetAutoFocus(false)
  pruneDays:SetText("30")
  if pruneDays.SetNumeric then
    pruneDays:SetNumeric(true)
  end
  f.pruneDaysEdit = pruneDays

  local daysSuffix = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  daysSuffix:SetPoint("LEFT", pruneDays, "RIGHT", 6, 0)
  daysSuffix:SetText(TimeLoggerL("UI_DAYS_OLD"))
  daysSuffix:SetTextColor(UI_COLORS.subtitle[1], UI_COLORS.subtitle[2], UI_COLORS.subtitle[3], 1)

  local pruneBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  pruneBtn:SetSize(72, 22)
  pruneBtn:SetPoint("LEFT", daysSuffix, "RIGHT", 12, 0)
  pruneBtn:SetText(TimeLoggerL("BTN_PRUNE"))
  pruneBtn:SetScript("OnClick", function()
    local d = tonumber(pruneDays:GetText())
    if not d or d < 1 then
      TimeLoggerLocale:PrintWarning("MSG_INVALID_DAYS")
      return
    end
    pendingPruneDays = math.floor(d)
    StaticPopup_Show("TIMELOGGER_PRUNE_CONFIRM", tostring(pendingPruneDays))
  end)

  local restoreBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  restoreBtn:SetSize(112, 22)
  restoreBtn:SetPoint("LEFT", pruneBtn, "RIGHT", 8, 0)
  restoreBtn:SetText(TimeLoggerL("BTN_RESTORE_BACKUP"))
  restoreBtn:SetScript("OnClick", function()
    local backupRows = TimeLoggerStorage:GetBackupRowCount()
    if backupRows < 1 then
      TimeLoggerLocale:PrintWarning("MSG_NO_BACKUP")
      return
    end
    pendingRestoreRows = backupRows
    StaticPopup_Show("TIMELOGGER_RESTORE_CONFIRM", tostring(backupRows))
  end)

  local heartbeatLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  heartbeatLabel:SetPoint("BOTTOMLEFT", 20, 18)
  heartbeatLabel:SetText(TimeLoggerL("UI_HEARTBEAT_INTERVAL"))
  heartbeatLabel:SetTextColor(UI_COLORS.subtitle[1], UI_COLORS.subtitle[2], UI_COLORS.subtitle[3], 1)

  local heartbeatSlider
  local ok, slider = pcall(CreateFrame, "Slider", nil, f, "OptionsSliderTemplate")
  if ok and slider then
    heartbeatSlider = slider
  else
    heartbeatSlider = CreateFrame("Slider", nil, f, "HorizontalSliderTemplate")
  end
  heartbeatSlider:SetPoint("LEFT", heartbeatLabel, "RIGHT", 10, 0)
  heartbeatSlider:SetSize(150, 16)
  heartbeatSlider:SetOrientation("HORIZONTAL")
  heartbeatSlider:SetMinMaxValues(MIN_HEARTBEAT_SEC, MAX_HEARTBEAT_SEC)
  heartbeatSlider:SetValueStep(HEARTBEAT_STEP_SEC)
  heartbeatSlider:SetObeyStepOnDrag(true)

  local heartbeatValue = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  heartbeatValue:SetPoint("LEFT", heartbeatSlider, "RIGHT", 8, 0)
  heartbeatValue:SetTextColor(UI_COLORS.subtitle[1], UI_COLORS.subtitle[2], UI_COLORS.subtitle[3], 1)
  local function RefreshHeartbeatControl(value)
    local heartbeatSec = NormalizeHeartbeatSeconds(value or GetHeartbeatSeconds())
    heartbeatValue:SetText(TimeLoggerL("UI_HEARTBEAT_VALUE", math.floor(heartbeatSec / 60)))
  end
  heartbeatSlider:SetScript("OnValueChanged", function(_, value, userInput)
    local heartbeatSec = NormalizeHeartbeatSeconds(value)
    if userInput then
      heartbeatSec = SetHeartbeatSeconds(heartbeatSec)
    end
    RefreshHeartbeatControl(heartbeatSec)
  end)
  heartbeatSlider:SetValue(GetHeartbeatSeconds())
  RefreshHeartbeatControl()
  f.heartbeatSlider = heartbeatSlider

  local totalsHeader = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  totalsHeader:SetPoint("BOTTOMRIGHT", -20, 62)
  totalsHeader:SetText(TimeLoggerL("UI_TOTALS_HEADER"))
  totalsHeader:SetTextColor(UI_COLORS.title[1], UI_COLORS.title[2], UI_COLORS.title[3], 1)

  local currentTotalLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  currentTotalLabel:SetPoint("TOPRIGHT", totalsHeader, "BOTTOMRIGHT", 0, -4)
  currentTotalLabel:SetText(TimeLoggerL("UI_TOTAL_THIS_CHAR", "00:00:00"))
  currentTotalLabel:SetTextColor(UI_COLORS.subtitle[1], UI_COLORS.subtitle[2], UI_COLORS.subtitle[3], 1)
  currentCharacterTotalLabel = currentTotalLabel

  local allTotalLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  allTotalLabel:SetPoint("TOPRIGHT", currentTotalLabel, "BOTTOMRIGHT", 0, -2)
  allTotalLabel:SetText(TimeLoggerL("UI_TOTAL_ALL_CHARS", "00:00:00"))
  allTotalLabel:SetTextColor(UI_COLORS.subtitle[1], UI_COLORS.subtitle[2], UI_COLORS.subtitle[3], 1)
  allCharactersTotalLabel = allTotalLabel

  local bottomDivider = f:CreateTexture(nil, "ARTWORK")
  bottomDivider:SetColorTexture(
    UI_COLORS.divider[1],
    UI_COLORS.divider[2],
    UI_COLORS.divider[3],
    UI_COLORS.divider[4]
  )
  bottomDivider:SetPoint("BOTTOMLEFT", 20, 74)
  bottomDivider:SetPoint("BOTTOMRIGHT", -20, 74)
  bottomDivider:SetHeight(1)

  dataTableView = TimeLoggerTableView:Create(f, "TimeLoggerDataTable", {
    colors = TimeLoggerTableView.DEFAULT_COLORS,
  })
  dataTableView:SetPoint("TOPLEFT", 16, -112)
  dataTableView:SetPoint("BOTTOMRIGHT", -16, 80)

  exportFrame = f
  f:EnableKeyboard(true)
  f:SetScript("OnKeyDown", function(self, key)
    if key == "ESCAPE" then
      self:Hide()
    end
  end)
  f.sessionRefreshElapsed = 0
  f:SetScript("OnUpdate", function(self, elapsed)
    self.sessionRefreshElapsed = (self.sessionRefreshElapsed or 0) + elapsed
    if self.sessionRefreshElapsed >= 1 then
      self.sessionRefreshElapsed = 0
      RefreshCurrentSessionLabel()
      RefreshPlaytimeSummaryLabels()
    end
  end)
end

local function ShowExport()
  EnsureDB()
  if not exportFrame then
    CreateExportUI()
  end
  if exportFrame.minimapCheck then
    exportFrame.minimapCheck:SetChecked(TimeLoggerMinimap:IsEnabled())
  end
  if exportFrame.heartbeatSlider then
    exportFrame.heartbeatSlider:SetValue(GetHeartbeatSeconds())
  end
  RequestPlayedTotals(false)
  RefreshTableView()
  RefreshCurrentSessionLabel()
  RefreshPlaytimeSummaryLabels()
  exportFrame:Show()
  exportFrame:Raise()
  C_Timer.After(0, function()
    if dataTableView and exportFrame and exportFrame:IsShown() then
      dataTableView:UpdateVisibleRows()
    end
  end)
end

local function ToggleExport()
  if exportFrame and exportFrame:IsShown() then
    exportFrame:Hide()
    return
  end
  ShowExport()
end

  StaticPopupDialogs["TIMELOGGER_PRUNE_CONFIRM"] = {
  text = TimeLoggerL("POPUP_PRUNE"),
  button1 = YES,
  button2 = NO,
  OnAccept = function()
    if pendingPruneDays then
      DoPrune(pendingPruneDays)
      pendingPruneDays = nil
      if exportFrame and exportFrame:IsShown() then
        RefreshTableView()
      end
    end
  end,
  OnCancel = function()
    pendingPruneDays = nil
  end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
}

StaticPopupDialogs["TIMELOGGER_RESTORE_CONFIRM"] = {
  text = TimeLoggerL("POPUP_RESTORE"),
  button1 = YES,
  button2 = NO,
  OnAccept = function()
    if pendingRestoreRows then
      RestoreEventsBackup()
      pendingRestoreRows = nil
      if exportFrame and exportFrame:IsShown() then
        RefreshTableView()
        RefreshPlaytimeSummaryLabels()
        RefreshCurrentSessionLabel()
      end
    end
  end,
  OnCancel = function()
    pendingRestoreRows = nil
  end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
}

-- Events --------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:RegisterEvent("TIME_PLAYED_MSG")

eventFrame:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
    EnsureDB()
    TimeLoggerMinimap:Init(ToggleExport)
  elseif event == "PLAYER_LOGIN" then
    RecoverOrphanLogout()
    Record("login")
    UpdateTempLogout()
    StartTempLogoutTicker()
    SaveCurrentPlayedFromEventsFallback()
    C_Timer.After(2, EnrichLastLoginLocation)
    C_Timer.After(2, function()
      RequestPlayedTotals(true)
    end)
  elseif event == "PLAYER_LOGOUT" then
    StopTempLogoutTicker()
    EnsureDB()
    RequestPlayedTotals(true)
    TimeLoggerStorage:ClearTempLogout()
    Record("logout")
  elseif event == "TIME_PLAYED_MSG" then
    local totalTime = tonumber(arg1)
    if totalTime then
      SaveCurrentCharacterPlayed(totalTime)
      if exportFrame and exportFrame:IsShown() then
        RefreshPlaytimeSummaryLabels()
      end
    end
  end
end)

SLASH_TIMELOGGER1 = "/timelogger"
SLASH_TIMELOGGER2 = "/tlog"
SLASH_TIMELOGGER3 = "/tl"
SlashCmdList["TIMELOGGER"] = function(msg)
  msg = msg or ""
  msg = strtrim(msg)
  if msg == "" then
    ShowExport()
    return
  end
  local cmd, arg = strsplit(" ", msg, 2)
  cmd = (cmd or ""):lower()
  if cmd == "sub" and tonumber(arg) then
    local days = tonumber(arg)
    if days < 0 then
      print("|cffff9900TimeLogger:|r Subscription days must be non-negative.")
      return
    end
    local currentUnix = GetUnix()
    local db
    if TimeLoggerStorage and type(TimeLoggerStorage.GetDB) == "function" then
      db = TimeLoggerStorage:GetDB()
    end
    if db then
      db.subExpiresUnix = currentUnix + (days * 86400)
      print("|cffFFD700TimeLogger:|r Subscription expiration updated to " .. days .. " days from now.")
    else
      print("|cffFFD700TimeLogger:|r Could not access storage to set subscription expiration.")
    end
    return
  end

  print("TimeLogger Commands:")
  print("/tl sub <days> - Sets your subscription expiration (e.g., /tl sub 30)")
end
