--[[
  TimeLoggerMinimap — draggable minimap launcher for the export window.
]]

TimeLoggerMinimap = TimeLoggerMinimap or {}

local Minimap = TimeLoggerMinimap

local BUTTON_SIZE = 31
local ICON_PATH = "Interface\\AddOns\\TimeLogger\\TimeLoggerButton.png"
local FALLBACK_ICON = "Interface\\Icons\\INV_Misc_PocketWatch_01"

local button
local onToggle

local function GetOrbitRadius()
  local minimap = _G.Minimap
  local width = minimap and minimap:GetWidth() or 0
  if width <= 0 then
    width = 140
  end
  -- LibDBIcon-style orbit: half minimap width + fixed inset (80px at default 140px size).
  return (width / 2) + 10
end

local function GetSettings()
  TimeLoggerStorage:EnsureDB()
  local db = TimeLoggerStorage:GetDB()
  if type(db.minimap) ~= "table" then
    db.minimap = {
      enabled = true,
      angle = 220,
    }
  end
  if db.minimap.enabled == nil then
    db.minimap.enabled = true
  end
  if db.minimap.angle == nil then
    db.minimap.angle = 220
  end
  return db.minimap
end

local function UpdatePosition()
  if not button then
    return
  end
  local settings = GetSettings()
  local angle = math.rad(settings.angle or 220)
  local radius = GetOrbitRadius()
  button:ClearAllPoints()
  button:SetPoint("CENTER", _G.Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function UpdateAngleFromCursor()
  local mx, my = _G.Minimap:GetCenter()
  local px, py = GetCursorPosition()
  local scale = _G.Minimap:GetEffectiveScale()
  px = px / scale
  py = py / scale
  GetSettings().angle = math.deg(math.atan2(py - my, px - mx))
  UpdatePosition()
end

local function CreateButton()
  if button then
    return button
  end

  button = CreateFrame("Button", "TimeLoggerMinimapButton", _G.Minimap)
  button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
  button:SetFrameStrata("MEDIUM")
  button:SetFrameLevel(8)
  button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  button:RegisterForDrag("LeftButton")
  button:SetMovable(true)

  local icon = button:CreateTexture(nil, "BACKGROUND")
  icon:SetSize(20, 20)
  icon:SetPoint("CENTER", 0, 1)
  icon:SetTexture(ICON_PATH)
  if not icon:GetTexture() then
    icon:SetTexture(FALLBACK_ICON)
  end
  button.icon = icon

  local border = button:CreateTexture(nil, "OVERLAY")
  border:SetSize(53, 53)
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)

  local dragging = false

  button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText(TimeLoggerL("MINIMAP_TOOLTIP_TITLE"), 1, 1, 1)
    GameTooltip:AddLine(TimeLoggerL("MINIMAP_TOOLTIP_HINT"), nil, nil, nil, true)
    GameTooltip:AddLine(TimeLoggerL("MINIMAP_TOOLTIP_RELOAD"), nil, nil, nil, true)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)
  button:SetScript("OnDragStart", function(self)
    dragging = true
    self:SetScript("OnUpdate", UpdateAngleFromCursor)
  end)
  button:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
    C_Timer.After(0, function()
      dragging = false
    end)
  end)
  button:SetScript("OnClick", function(_, mouseButton)
    if dragging then
      return
    end
    if mouseButton == "LeftButton" and onToggle then
      onToggle()
    end
  end)
  button:SetScript("OnMouseUp", function(_, mouseButton)
    if mouseButton == "RightButton" and IsControlKeyDown() then
      ReloadUI()
    end
  end)

  if not _G.Minimap._TimeLoggerSizeHook then
    _G.Minimap._TimeLoggerSizeHook = true
    _G.Minimap:HookScript("OnSizeChanged", UpdatePosition)
  end

  UpdatePosition()
  return button
end

function Minimap:Init(toggleCallback)
  onToggle = toggleCallback
  CreateButton()
  self:Refresh()
end

function Minimap:IsEnabled()
  return GetSettings().enabled ~= false
end

function Minimap:SetEnabled(enabled)
  GetSettings().enabled = enabled and true or false
  self:Refresh()
end

function Minimap:Refresh()
  if not button then
    return
  end
  if self:IsEnabled() then
    button:Show()
    UpdatePosition()
  else
    button:Hide()
  end
end
