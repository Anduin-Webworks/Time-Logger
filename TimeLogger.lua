--[[
  TimeLogger — login/logout events, session export, prune, and temp_logout heartbeat for crash recovery.
  Commands: /timelogger, /tlog
]]

local ADDON_NAME = ...

local HEARTBEAT_SEC = 300 -- 5 minutes

local db
local pendingPruneDays
local tempLogoutTicker

--- Centralized time collection using server time for timezone-independent timestamps
local function GetUnix()
  if C_DateAndTime and C_DateAndTime.GetServerTimeLocal then
    return C_DateAndTime.GetServerTimeLocal()
  end
  return time()
end

local function EnsureDB()
  if type(TimeLoggerDB) ~= "table" then
    TimeLoggerDB = {}
  end
  if type(TimeLoggerDB.events) ~= "table" then
    TimeLoggerDB.events = {}
  end
  db = TimeLoggerDB
end

local function UtcIso()
  return date("!%Y-%m-%dT%H:%M:%SZ")
end

--- Last-known-alive snapshot (same shape as an event). Updated every HEARTBEAT_SEC while in-game.
--- Used only when the last stored event is login and we need a synthetic logout after crash / missing PLAYER_LOGOUT.
local function UpdateTempLogout()
  EnsureDB()
  local char = UnitName("player") or ""
  local realm = GetRealmName() or ""
  db.temp_logout = {
    unix = GetUnix(),
    utc = UtcIso(),
    event = "logout",
    character = char,
    realm = realm,
  }
end

local function StopTempLogoutTicker()
  if tempLogoutTicker then
    tempLogoutTicker:Cancel()
    tempLogoutTicker = nil
  end
end

local function StartTempLogoutTicker()
  StopTempLogoutTicker()
  tempLogoutTicker = C_Timer.NewTicker(HEARTBEAT_SEC, UpdateTempLogout)
end

--- If the last row is login (no logout was saved), insert a logout using the last heartbeat, if valid.
local function RecoverOrphanLogout()
  EnsureDB()
  local ev = db.events
  local n = #ev
  if n == 0 then
    return
  end
  local last = ev[n]
  if (last.event or "") ~= "login" then
    return
  end
  local t = db.temp_logout
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
  ev[n + 1] = {
    unix = t.unix,
    utc = t.utc or UtcIso(),
    event = "logout",
    character = t.character or last.character,
    realm = t.realm or last.realm,
    recovery = true,
  }
end

local function Record(kind)
  EnsureDB()
  local char = UnitName("player") or ""
  local realm = GetRealmName() or ""
  db.events[#db.events + 1] = {
    unix = GetUnix(),
    utc = UtcIso(),
    event = kind,
    character = char,
    realm = realm,
  }
end

local function CharKey(e)
  return (e.realm or "") .. "|" .. (e.character or "")
end

-- OPTIMIZED: Linear Session Builder
local function BuildSessions()
    local sessions = {}
    local openSessions = {}

    for i, e in ipairs(db.events) do
        local key = e.character .. "-" .. e.realm
        
        if e.event == "login" then
            if openSessions[key] then
                local prevIdx = openSessions[key]
                sessions[prevIdx].status = "no_logout"
            end
            
            table.insert(sessions, {
                start_unix = e.unix,
                start_utc = e.utc,
                character = e.character,
                realm = e.realm,
                status = "open",
                end_unix = 0,
                end_utc = ""
            })
            openSessions[key] = #sessions
            
        elseif e.event == "logout" then
            if openSessions[key] then
                local sIdx = openSessions[key]
                local s = sessions[sIdx]
                -- FIXED: Removed trailing commas that caused the syntax error
                s.end_unix = e.unix
                s.end_utc = e.utc
                s.duration_sec = e.unix - s.start_unix
                s.status = e.recovery and "recovered" or "closed"
                openSessions[key] = nil
            end
        end
    end
    return sessions
end

-- Export Helpers
local function BuildCSV()
    local lines = {"unix,utc_iso,event,character,realm,recovery"}
    for _, e in ipairs(db.events) do
        table.insert(lines, string.format("%d,%s,%s,%s,%s,%d", 
            e.unix, e.utc, e.event, e.character, e.realm, e.recovery and 1 or 0))
    end
    return table.concat(lines, "\n")
end

local function BuildSessionsCSV()
    local sessions = BuildSessions()
    local lines = {"session_id,start_unix,start_utc,end_unix,end_utc,duration_sec,character,realm,status"}
    for i, s in ipairs(sessions) do
        table.insert(lines, string.format("%d,%d,%s,%d,%s,%d,%s,%s,%s",
            i, s.start_unix, s.start_utc, s.end_unix, s.end_utc, s.duration_sec or 0, s.character, s.realm, s.status))
    end
    return table.concat(lines, "\n")
end

local function BuildSessionsJSON()
    local sessions = BuildSessions()
    local lines = {}
    for i, s in ipairs(sessions) do
        table.insert(lines, string.format('  {"id":%d,"start_unix":%d,"start_utc":"%s","end_unix":%d,"end_utc":"%s","duration":%d,"char":"%s","realm":"%s","status":"%s"}',
            i, s.start_unix, s.start_utc, s.end_unix, s.end_utc, s.duration_sec or 0, s.character, s.realm, s.status))
    end
    return "[\n" .. table.concat(lines, ",\n") .. "\n]"
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
  return s:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\r", "\\r"):gsub("\n", "\\n")
end

local function BuildJSON()
  local parts = { "[" }
  local n = #db.events
  for i = 1, n do
    local e = db.events[i]
    local rec = e.recovery and ',"recovery":true' or ""
    local chunk = string.format(
      '{"unix":%d,"utc":"%s","event":"%s","character":"%s","realm":"%s"%s}',
      e.unix or 0,
      JsonEscape(e.utc),
      JsonEscape(e.event),
      JsonEscape(e.character),
      JsonEscape(e.realm),
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

local function CopyEventsSnapshot()
  local t = {}
  for i = 1, #db.events do
    local e = db.events[i]
    if CopyTable then
      t[i] = CopyTable(e)
    else
      t[i] = {
        unix = e.unix,
        utc = e.utc,
        event = e.event,
        character = e.character,
        realm = e.realm,
        recovery = e.recovery,
      }
    end
  end
  return t
end

local function DoPrune(days)
  EnsureDB()
  local cutoff = GetUnix() - (days * 86400)
  
  -- Only create backup if one doesn't exist for this session or if it's old
  if not db.events_backup or not db.events_backup_time or (GetUnix() - db.events_backup_time) > 3600 then
    db.events_backup = CopyEventsSnapshot()
    db.events_backup_time = GetUnix()
  end
  
  local kept = {}
  for i = 1, #db.events do
    local e = db.events[i]
    if (e.unix or 0) >= cutoff then
      kept[#kept + 1] = e
    end
  end
  db.events = kept
  print(
    string.format(
      "|cff00ff00TimeLogger:|r Pruned events older than %d days. Kept %d rows; full pre-prune snapshot in events_backup (%d rows).",
      days,
      #db.events,
      #db.events_backup
    )
  )
end

-- Export UI -----------------------------------------------------------------

local exportFrame
local exportEdit
local exportMode = "events_csv"

local function ResizeExportEdit()
  if not exportEdit or not exportFrame then
    return
  end
  local scroll = exportFrame.scroll
  local w = math.max(scroll:GetWidth() - 24, 1)
  exportEdit:SetWidth(w)
  local insetL, insetR, insetT, insetB = exportEdit:GetTextInsets()
  insetL = insetL or 0
  insetR = insetR or 0
  insetT = insetT or 0
  insetB = insetB or 0
  local contentW = math.max(w - insetL - insetR, 1)
  local fs = exportFrame.measureFS
  local font, size, flags = exportEdit:GetFont()
  if font then
    fs:SetFont(font, size, flags)
  end
  fs:SetWidth(contentW)
  if fs.SetWordWrap then
    fs:SetWordWrap(true)
  end
  fs:SetText(exportEdit:GetText() or "")
  local textH = fs:GetStringHeight() or 0
  local h = math.max(textH + insetT + insetB + 4, scroll:GetHeight())
  exportEdit:SetHeight(h)
end

local function GetExportText()
  EnsureDB()
  if exportMode == "events_json" then
    return BuildJSON()
  elseif exportMode == "sessions_csv" then
    return BuildSessionsCSV()
  elseif exportMode == "sessions_json" then
    return BuildSessionsJSON()
  end
  return BuildCSV()
end

local function RefreshExportText()
  if not exportEdit then
    return
  end
  exportEdit:SetText(GetExportText())
  ResizeExportEdit()
end

local function CreateExportUI()
  local f = CreateFrame("Frame", "TimeLoggerExportFrame", UIParent, "BackdropTemplate")
  f:SetSize(800, 600)
  f:SetPoint("CENTER")
  f:SetFrameStrata("DIALOG")
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  f:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 8, right = 8, top = 10, bottom = 8 },
  })

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  title:SetPoint("TOP", 0, -14)
  title:SetText("TimeLogger — events & sessions (copy below)")

  local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  closeBtn:SetPoint("TOPRIGHT", -4, -4)
  closeBtn:SetScript("OnClick", function()
    f:Hide()
  end)

  local evCsv = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  evCsv:SetSize(88, 22)
  evCsv:SetPoint("TOPLEFT", 16, -38)
  evCsv:SetText("Events CSV")
  evCsv:SetScript("OnClick", function()
    exportMode = "events_csv"
    RefreshExportText()
  end)

  local evJson = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  evJson:SetSize(88, 22)
  evJson:SetPoint("LEFT", evCsv, "RIGHT", 6, 0)
  evJson:SetText("Events JSON")
  evJson:SetScript("OnClick", function()
    exportMode = "events_json"
    RefreshExportText()
  end)

  local copyBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  copyBtn:SetSize(120, 22)
  copyBtn:SetPoint("TOPRIGHT", -32, -38)
  copyBtn:SetText("Copy to clipboard")
  copyBtn:SetScript("OnClick", function()
    local text = exportEdit:GetText() or ""
    if C_ChatInfo and C_ChatInfo.CopyStringToClipboard then
      C_ChatInfo.CopyStringToClipboard(text)
      print("|cff00ff00TimeLogger:|r Copied " .. #text .. " characters to clipboard.")
    else
      exportEdit:SetFocus()
      exportEdit:HighlightText()
      print("|cffff9900TimeLogger:|r Select all (Ctrl+A) and copy (Ctrl+C).")
    end
  end)

  local sessCsv = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  sessCsv:SetSize(108, 22)
  sessCsv:SetPoint("TOPLEFT", 16, -66)
  sessCsv:SetText("Sessions CSV")
  sessCsv:SetScript("OnClick", function()
    exportMode = "sessions_csv"
    RefreshExportText()
  end)

  local sessJson = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  sessJson:SetSize(108, 22)
  sessJson:SetPoint("LEFT", sessCsv, "RIGHT", 6, 0)
  sessJson:SetText("Sessions JSON")
  sessJson:SetScript("OnClick", function()
    exportMode = "sessions_json"
    RefreshExportText()
  end)

  local pruneLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  pruneLabel:SetPoint("BOTTOMLEFT", 20, 38)
  pruneLabel:SetText("Prune events older than")

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
  daysSuffix:SetText("days")

  local pruneBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  pruneBtn:SetSize(72, 22)
  pruneBtn:SetPoint("LEFT", daysSuffix, "RIGHT", 12, 0)
  pruneBtn:SetText("Prune")
  pruneBtn:SetScript("OnClick", function()
    local d = tonumber(pruneDays:GetText())
    if not d or d < 1 then
      print("|cffff9900TimeLogger:|r Enter a number of days (1 or more).")
      return
    end
    pendingPruneDays = math.floor(d)
    StaticPopup_Show("TIMELOGGER_PRUNE_CONFIRM", tostring(pendingPruneDays))
  end)

  local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 16, -94)
  scroll:SetPoint("BOTTOMRIGHT", -32, 68)
  f.scroll = scroll

  local measureFS = f:CreateFontString(nil, "ARTWORK", "ChatFontNormal")
  measureFS:SetPoint("TOPLEFT", UIParent, "BOTTOMRIGHT", 10000, 10000)
  measureFS:Hide()
  f.measureFS = measureFS

  local edit = CreateFrame("EditBox", nil, scroll)
  edit:SetMultiLine(true)
  edit:SetAutoFocus(false)
  edit:SetFontObject(ChatFontNormal)
  edit:SetWidth(460)
  edit:SetTextInsets(8, 8, 8, 8)
  edit:SetScript("OnEscapePressed", function()
    f:Hide()
  end)
  edit:SetScript("OnTextChanged", function(self, userInput)
    if userInput then
      return
    end
    ResizeExportEdit()
  end)
  scroll:SetScrollChild(edit)

  exportFrame = f
  exportEdit = edit
end

local function ShowExport()
  EnsureDB()
  if not exportFrame then
    CreateExportUI()
  end
  RefreshExportText()
  exportFrame:Show()
  exportFrame:Raise()
  C_Timer.After(0, function()
    if exportFrame and exportFrame:IsShown() then
      ResizeExportEdit()
    end
  end)
end

StaticPopupDialogs["TIMELOGGER_PRUNE_CONFIRM"] = {
  text = "Prune events older than %s days?|nYour full current event list will be copied to events_backup first.",
  button1 = YES,
  button2 = NO,
  OnAccept = function()
    if pendingPruneDays then
      DoPrune(pendingPruneDays)
      pendingPruneDays = nil
      if exportFrame and exportFrame:IsShown() then
        RefreshExportText()
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

-- Events --------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_LOGOUT")

eventFrame:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
    EnsureDB()
  elseif event == "PLAYER_LOGIN" then
    RecoverOrphanLogout()
    Record("login")
    UpdateTempLogout()
    StartTempLogoutTicker()
  elseif event == "PLAYER_LOGOUT" then
    StopTempLogoutTicker()
    EnsureDB()
    db.temp_logout = nil
    Record("logout")
  end
end)

SLASH_TIMELOGGER1 = "/timelogger"
SLASH_TIMELOGGER2 = "/tlog"
SlashCmdList["TIMELOGGER"] = function()
  ShowExport()
end
