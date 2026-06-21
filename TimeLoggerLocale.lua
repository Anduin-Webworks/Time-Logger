--[[
  TimeLoggerLocale — localization loader for all WoW client locales.

  Load order: this file, Locales/enUS.lua (base), Locales/LocaleData.lua (overlays).
]]

TimeLoggerLocale = TimeLoggerLocale or {}

local Locale = TimeLoggerLocale

Locale.base = Locale.base or {}
Locale.overlay = Locale.overlay or {}
Locale.active = Locale.active or {}

local SUPPORTED = {
  enUS = true,
  deDE = true,
  esES = true,
  esMX = true,
  frFR = true,
  itIT = true,
  koKR = true,
  ptBR = true,
  ruRU = true,
  zhCN = true,
  zhTW = true,
}

function Locale:ResolveLocale()
  local loc = GetLocale and GetLocale() or "enUS"
  if loc == "enGB" then
    return "enUS"
  end
  if not SUPPORTED[loc] then
    return "enUS"
  end
  return loc
end

function Locale:RefreshActive()
  local active = {}
  for key, value in pairs(self.base) do
    active[key] = value
  end
  for key, value in pairs(self.overlay) do
    active[key] = value
  end
  self.active = active
end

function Locale:LoadBase(strings)
  for key, value in pairs(strings) do
    self.base[key] = value
  end
  self:RefreshActive()
end

function Locale:Merge(strings)
  for key, value in pairs(strings) do
    self.overlay[key] = value
  end
  self:RefreshActive()
end

function Locale:Get(key, ...)
  local str = self.active[key] or self.base[key] or key
  if select("#", ...) > 0 then
    return string.format(str, ...)
  end
  return str
end

function Locale:Print(key, ...)
  print(string.format("|cff00ff00%s:|r %s", self:Get("ADDON_TAG"), self:Get(key, ...)))
end

function Locale:PrintWarning(key, ...)
  print(string.format("|cffff9900%s:|r %s", self:Get("ADDON_TAG"), self:Get(key, ...)))
end

function Locale:FormatEventType(eventType)
  if eventType == "login" then
    return self:Get("EVENT_LOGIN")
  end
  if eventType == "logout" then
    return self:Get("EVENT_LOGOUT")
  end
  return tostring(eventType or "")
end

function Locale:FormatSessionStatus(status)
  if status == "open" then
    return self:Get("STATUS_OPEN")
  end
  if status == "closed" then
    return self:Get("STATUS_CLOSED")
  end
  if status == "no_logout" then
    return self:Get("STATUS_NO_LOGOUT")
  end
  if status == "recovered" then
    return self:Get("STATUS_RECOVERED")
  end
  return tostring(status or "")
end

function Locale:FormatRecovery(recovery)
  if recovery then
    return self:Get("VAL_YES")
  end
  return ""
end

function Locale:FormatWeekday(weekdayIndex)
  weekdayIndex = tonumber(weekdayIndex)
  if weekdayIndex and weekdayIndex >= 1 and weekdayIndex <= 7 then
    return self:Get("WEEKDAY_" .. weekdayIndex)
  end
  return ""
end

function Locale:FormatSubscription(status)
  if status == "subscribed" then
    return self:Get("SUB_SUBSCRIBED")
  end
  if status == "not_subscribed" then
    return self:Get("SUB_NOT_SUBSCRIBED")
  end
  if status == "trial" then
    return self:Get("SUB_TRIAL")
  end
  if status == "veteran" then
    return self:Get("SUB_VETERAN")
  end
  if status == "unknown" or status == nil or status == "" then
    return self:Get("SUB_UNKNOWN")
  end
  return tostring(status)
end

function TimeLoggerL(key, ...)
  return TimeLoggerLocale:Get(key, ...)
end
