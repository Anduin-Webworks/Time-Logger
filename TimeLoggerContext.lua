--[[
  TimeLoggerContext — captures client metadata at login/logout time.
]]

TimeLoggerContext = TimeLoggerContext or {}

local Context = TimeLoggerContext

function Context:GetPatchVersion()
  if GetBuildInfo then
    local version = GetBuildInfo()
    if version and version ~= "" then
      return version
    end
  end
  return ""
end

function Context:GetExpansionName()
  -- The client level is available during PLAYER_LOGIN and identifies the
  -- actual game flavor. The server level can still be 0 at that point.
  local level = (GetClientDisplayExpansionLevel and GetClientDisplayExpansionLevel())
    or (GetExpansionLevel and GetExpansionLevel())
    or (GetServerExpansionLevel and GetServerExpansionLevel())
    or LE_EXPANSION_LEVEL_CURRENT

  if level and _G["EXPANSION_NAME" .. level] then
    return _G["EXPANSION_NAME" .. level]
  end

  return ""
end

function Context:GetLocationName()
  local zone = GetZoneText and GetZoneText() or ""
  local sub = GetSubZoneText and GetSubZoneText() or ""

  zone = zone or ""
  sub = sub or ""

  if sub ~= "" and sub ~= zone then
    return zone .. " - " .. sub
  end
  if zone ~= "" then
    return zone
  end

  if C_Map and C_Map.GetBestMapForUnit then
    local mapID = C_Map.GetBestMapForUnit("player")
    if mapID and C_Map.GetMapInfo then
      local info = C_Map.GetMapInfo(mapID)
      if info and info.name and info.name ~= "" then
        return info.name
      end
    end
  end

  return ""
end

function Context:GetWeekdayIndex(unix)
  unix = unix or time()
  local w = tonumber(date("%w", unix)) or 0
  if w == 0 then
    return 7
  end
  return w
end

function Context:GetLocalDateTime(unix)
  unix = unix or time()
  return date("%Y-%m-%d %H:%M:%S", unix)
end

function Context:GetSubscriptionStatus()
  if IsTrialAccount and IsTrialAccount() then
    return "trial"
  end
  if IsVeteranTrialAccount and IsVeteranTrialAccount() then
    return "veteran"
  end
  if IsSubscribed then
    if IsSubscribed() then
      return "subscribed"
    end
    return "not_subscribed"
  end
  return "unknown"
end

function Context:Collect(unix)
  unix = unix or time()
  return {
    patch = self:GetPatchVersion(),
    expansion = self:GetExpansionName(),
    location = self:GetLocationName(),
    weekday = self:GetWeekdayIndex(unix),
    subscription = self:GetSubscriptionStatus(),
    local_dt = self:GetLocalDateTime(unix),
  }
end
