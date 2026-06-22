--[[
  TimeLoggerTableView — self-contained spreadsheet-style table with per-column header filters.

  Parent frames can embed this widget and change columns/rows independently of the shell UI.
]]

TimeLoggerTableView = TimeLoggerTableView or {}

local TableView = TimeLoggerTableView

local DEFAULTS = {
  rowHeight = 24,
  headerTitleHeight = 20,
  headerFilterHeight = 22,
  rowPoolPadding = 4,
  filterDebounceSec = 0.12,
}

TableView.DEFAULT_COLORS = {
  panelBg = { 0.05, 0.05, 0.06, 0.98 },
  panelBorder = { 0.78, 0.62, 0.18, 0.85 },
  headerBg = { 0.11, 0.10, 0.09, 1 },
  headerTitle = { 0.95, 0.78, 0.28, 1 },
  headerFilterBg = { 0.03, 0.03, 0.04, 0.95 },
  headerFilterBorder = { 0.62, 0.62, 0.66, 0.55 },
  headerFilterText = { 0.78, 0.78, 0.82, 1 },
  rowBg = { 0.08, 0.08, 0.09, 1 },
  rowAltBg = { 0.10, 0.10, 0.11, 1 },
  rowText = { 0.82, 0.82, 0.86, 1 },
  rowTextMuted = { 0.58, 0.58, 0.62, 1 },
  gridLine = { 0.34, 0.30, 0.20, 0.35 },
  statusBg = { 0.07, 0.07, 0.08, 0.95 },
  statusText = { 0.70, 0.70, 0.74, 1 },
  scrollbar = { 0.78, 0.62, 0.18, 0.75 },
}

local function ApplyColor(textureOrFrame, color, isBackdrop)
  if not color then
    return
  end
  if isBackdrop then
    textureOrFrame:SetBackdropColor(color[1], color[2], color[3], color[4] or 1)
  elseif textureOrFrame.SetColorTexture then
    textureOrFrame:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
  elseif textureOrFrame.SetTextColor then
    textureOrFrame:SetTextColor(color[1], color[2], color[3], color[4] or 1)
  end
end

local function ApplyBorder(frame, color)
  if frame.SetBackdropBorderColor and color then
    frame:SetBackdropBorderColor(color[1], color[2], color[3], color[4] or 1)
  end
end

local function GetCellValue(row, column)
  if column.getValue then
    return column.getValue(row)
  end
  if column.key and row then
    return row[column.key]
  end
  return ""
end

local function NormalizeFilterText(text)
  text = tostring(text or ""):lower()
  text = text:gsub("^%s+", ""):gsub("%s+$", "")
  return text
end

local function RowMatchesFilters(row, columns, filters)
  for i = 1, #columns do
    local filterText = filters[i]
    if filterText and filterText ~= "" then
      local value = tostring(GetCellValue(row, columns[i]) or ""):lower()
      if not value:find(filterText, 1, true) then
        return false
      end
    end
  end
  return true
end

local function CreateBackdropFrame(parent, name)
  local frame = CreateFrame("Frame", name, parent, "BackdropTemplate")
  frame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    tile = false,
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
  })
  return frame
end

local function CreateRoundedPanel(parent, name, colors)
  local frame = CreateFrame("Frame", name, parent)
  frame:SetClipsChildren(true)

  local bg = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
  bg:SetPoint("TOPLEFT", 2, -2)
  bg:SetPoint("BOTTOMRIGHT", -2, 2)
  bg:SetColorTexture(colors.panelBg[1], colors.panelBg[2], colors.panelBg[3], colors.panelBg[4] or 1)

  local border = CreateBackdropFrame(frame, nil)
  border:SetAllPoints()
  ApplyColor(border, colors.panelBg, true)
  ApplyBorder(border, colors.panelBorder)

  frame.bg = bg
  frame.border = border
  return frame
end

local function CreateFilterEdit(parent, colors, onChanged)
  local box = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
  box:SetAutoFocus(false)
  box:SetHeight(DEFAULTS.headerFilterHeight - 6)
  box:SetFontObject(GameFontHighlightSmall)
  box:SetTextInsets(6, 6, 2, 2)
  box:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    tile = false,
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
  })
  ApplyColor(box, colors.headerFilterBg, true)
  ApplyBorder(box, colors.headerFilterBorder)
  box:SetTextColor(
    colors.headerFilterText[1],
    colors.headerFilterText[2],
    colors.headerFilterText[3],
    colors.headerFilterText[4] or 1
  )

  box:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
  end)
  box:SetScript("OnEditFocusLost", function(self)
    self:HighlightText(0, 0)
  end)
  box:SetScript("OnTextChanged", function(self, userInput)
    if userInput and onChanged then
      onChanged()
    end
  end)

  return box
end

local function CreateRowFrame(parent, columns, colors, rowHeight)
  local row = CreateFrame("Frame", nil, parent)
  row:SetHeight(rowHeight)
  row.cells = {}

  row.bg = row:CreateTexture(nil, "BACKGROUND")
  row.bg:SetAllPoints()

  for i = 1, #columns do
    local cell = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cell:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -4)
    cell:SetJustifyH("LEFT")
    cell:SetWordWrap(false)
    ApplyColor(cell, colors.rowText)
    row.cells[i] = cell
  end

  row.divider = row:CreateTexture(nil, "BORDER")
  row.divider:SetHeight(1)
  row.divider:SetPoint("BOTTOMLEFT", 0, 0)
  row.divider:SetPoint("BOTTOMRIGHT", 0, 0)
  ApplyColor(row.divider, colors.gridLine)

  return row
end

function TableView:Create(parent, name, options)
  options = options or {}
  local colors = options.colors or self.DEFAULT_COLORS
  local rowHeight = options.rowHeight or DEFAULTS.rowHeight
  local headerTitleHeight = options.headerTitleHeight or DEFAULTS.headerTitleHeight
  local headerFilterHeight = options.headerFilterHeight or DEFAULTS.headerFilterHeight
  local headerHeight = headerTitleHeight + headerFilterHeight + 6
  local filterDebounceSec = options.filterDebounceSec or DEFAULTS.filterDebounceSec

  local widget = CreateRoundedPanel(parent, name, colors)
  widget.columns = {}
  widget.allRows = {}
  widget.filteredRows = {}
  widget.filters = {}
  widget.colors = colors
  widget.rowHeight = rowHeight
  widget.headerHeight = headerHeight
  widget.filterDebounceSec = filterDebounceSec
  widget.onFiltersChanged = options.onFiltersChanged

  local header = CreateFrame("Frame", nil, widget)
  header:SetPoint("TOPLEFT", 8, -8)
  header:SetPoint("TOPRIGHT", -8, -8)
  header:SetHeight(headerHeight)
  widget.header = header

  local headerBg = header:CreateTexture(nil, "BACKGROUND")
  headerBg:SetAllPoints()
  ApplyColor(headerBg, colors.headerBg)

  local headerBottom = header:CreateTexture(nil, "ARTWORK")
  headerBottom:SetHeight(1)
  headerBottom:SetPoint("BOTTOMLEFT", 0, 0)
  headerBottom:SetPoint("BOTTOMRIGHT", 0, 0)
  ApplyColor(headerBottom, colors.gridLine)

  widget.headerTitles = {}
  widget.headerFilters = {}

  local status = CreateFrame("Frame", nil, widget)
  status:SetPoint("BOTTOMLEFT", 8, 8)
  status:SetPoint("BOTTOMRIGHT", -8, 8)
  status:SetHeight(18)
  widget.status = status

  local statusBg = status:CreateTexture(nil, "BACKGROUND")
  statusBg:SetAllPoints()
  ApplyColor(statusBg, colors.statusBg)

  local statusText = status:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  statusText:SetPoint("LEFT", 8, 0)
  statusText:SetJustifyH("LEFT")
  ApplyColor(statusText, colors.statusText)
  widget.statusText = statusText

  local body = CreateFrame("Frame", nil, widget)
  body:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
  body:SetPoint("BOTTOMRIGHT", status, "TOPRIGHT", 0, 4)
  widget.body = body

  local scroll = CreateFrame("ScrollFrame", nil, body, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 0, 0)
  scroll:SetPoint("BOTTOMRIGHT", -24, 18)
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel", function(self, delta)
    local vertical = not IsShiftKeyDown()
    if vertical then
      local current = self:GetVerticalScroll() or 0
      local max = self:GetVerticalScrollRange() or 0
      local newScroll = math.max(0, math.min(max, current - (delta * 20)))
      self:SetVerticalScroll(newScroll)
    else
      local current = self:GetHorizontalScroll() or 0
      local max = self:GetHorizontalScrollRange() or 0
      local newScroll = math.max(0, math.min(max, current - (delta * 20)))
      self:SetHorizontalScroll(newScroll)
    end
  end)

  local hSliderUpdating = false
  scroll:SetScript("OnVerticalScroll", function(self)
    widget:UpdateVisibleRows()
  end)
  scroll:SetScript("OnHorizontalScroll", function(self)
    local x = self:GetHorizontalScroll() or 0
    widget:UpdateHeaderScroll()
    if widget.hSlider and not hSliderUpdating then
      hSliderUpdating = true
      widget.hSlider:SetValue(x)
      hSliderUpdating = false
    end
  end)
  widget.scroll = scroll

  local hSlider = CreateFrame("Slider", nil, body, "HorizontalSliderTemplate")
  hSlider:SetPoint("BOTTOMLEFT", 0, 0)
  hSlider:SetPoint("BOTTOMRIGHT", -24, 0)
  hSlider:SetHeight(16)
  hSlider:SetOrientation("HORIZONTAL")
  hSlider:SetMinMaxValues(0, 0)
  hSlider:SetValueStep(1)
  hSlider:SetObeyStepOnDrag(true)
  hSlider:SetScript("OnValueChanged", function(self, value, userInput)
    if hSliderUpdating then
      return
    end
    if widget.scroll and userInput then
      widget.scroll:SetHorizontalScroll(value)
    end
  end)
  widget.hSlider = hSlider

  if scroll.ScrollBar then
    scroll.ScrollBar:GetThumbTexture():SetVertexColor(
      colors.scrollbar[1],
      colors.scrollbar[2],
      colors.scrollbar[3],
      colors.scrollbar[4] or 1
    )
  end

  local scrollChild = CreateFrame("Frame", nil, scroll)
  scrollChild:SetWidth(1)
  scrollChild:SetHeight(1)
  scroll:SetScrollChild(scrollChild)
  widget.scrollChild = scrollChild
  widget.rowFrames = {}
  widget.filterTimer = nil

  if scroll.ScrollBar then
    scroll.ScrollBar:HookScript("OnValueChanged", function()
      widget:UpdateVisibleRows()
    end)
  end

  function widget:ScheduleFilterRefresh()
    if self.filterTimer then
      self.filterTimer:Cancel()
      self.filterTimer = nil
    end
    self.filterTimer = C_Timer.NewTimer(self.filterDebounceSec, function()
      self.filterTimer = nil
      self:ApplyFilters()
    end)
  end

  function widget:ClearHeader()
    for _, title in ipairs(self.headerTitles) do
      title:Hide()
    end
    for _, filter in ipairs(self.headerFilters) do
      filter:Hide()
    end
  end

  function widget:LayoutHeader()
    self:ClearHeader()
    local x = 0
    local totalWidth = 0

    for i, column in ipairs(self.columns) do
      local width = column.width or 100
      totalWidth = totalWidth + width

      local title = self.headerTitles[i]
      if not title then
        title = self.header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        title:SetJustifyH("LEFT")
        ApplyColor(title, self.colors.headerTitle)
        self.headerTitles[i] = title
      end
      title:ClearAllPoints()
      title:SetPoint("TOPLEFT", self.header, "TOPLEFT", x + 6, -4)
      title:SetWidth(width - 8)
      title:SetText(column.title or column.key or "")
      title:Show()

      local filter = self.headerFilters[i]
      if not filter then
        filter = CreateFilterEdit(self.header, self.colors, function()
          widget:ScheduleFilterRefresh()
        end)
        self.headerFilters[i] = filter
      end
      filter:ClearAllPoints()
      filter:SetPoint("TOPLEFT", self.header, "TOPLEFT", x + 4, -(headerTitleHeight + 2))
      filter:SetWidth(width - 8)
      filter:Show()
      if self.filters[i] == nil then
        filter:SetText("")
      end

      if i < #self.columns then
        local sep = column._sep
        if not sep then
          sep = self.header:CreateTexture(nil, "ARTWORK")
          column._sep = sep
        end
        sep:ClearAllPoints()
        sep:SetWidth(1)
        sep:SetPoint("TOPLEFT", self.header, "TOPLEFT", x + width, 0)
        sep:SetPoint("BOTTOMLEFT", self.header, "BOTTOMLEFT", x + width, 0)
        ApplyColor(sep, self.colors.gridLine)
        sep:Show()
      end

      x = x + width
    end

    self.contentWidth = math.max(totalWidth, 1)
    self.scrollChild:SetWidth(self.contentWidth)
    self.header:SetWidth(self.contentWidth + 16)
    self.scroll:SetHorizontalScroll(0)
  end

  function widget:EnsureRowPool(visibleCount)
    visibleCount = visibleCount + DEFAULTS.rowPoolPadding
    for i = 1, visibleCount do
      if not self.rowFrames[i] then
        local row = CreateRowFrame(self.scrollChild, self.columns, self.colors, self.rowHeight)
        self.rowFrames[i] = row
      end
    end
  end

  function widget:UpdateScrollRanges()
    local scrollWidth = math.max(self.scroll:GetWidth() or 1, 1)
    local maxH = math.max(0, self.contentWidth - scrollWidth)
    if self.hSlider then
      self.hSlider:SetMinMaxValues(0, maxH)
      if self.hSlider:GetValue() > maxH then
        self.hSlider:SetValue(maxH)
      end
    end

    if self.scroll.ScrollBar then
      local maxV = math.max(0, (self.scrollChild:GetHeight() or 1) - (self.scroll:GetHeight() or 1))
      self.scroll.ScrollBar:SetMinMaxValues(0, maxV)
      if self.scroll.ScrollBar:GetValue() > maxV then
        self.scroll.ScrollBar:SetValue(maxV)
      end
    end
  end

  function widget:UpdateHeaderScroll()
    local x = self.scroll:GetHorizontalScroll() or 0
    self.header:SetPoint("TOPLEFT", self, "TOPLEFT", -x + 8, -8)
  end

  function widget:LayoutRowFrame(row, rowIndex, dataIndex)
    local rowData = self.filteredRows[dataIndex]
    local x = 0

    if rowIndex % 2 == 0 then
      ApplyColor(row.bg, self.colors.rowBg)
    else
      ApplyColor(row.bg, self.colors.rowAltBg)
    end

    for i, column in ipairs(self.columns) do
      local width = column.width or 100
      local cell = row.cells[i]
      cell:ClearAllPoints()
      cell:SetPoint("TOPLEFT", row, "TOPLEFT", x + 6, -5)
      cell:SetWidth(width - 10)
      local value = GetCellValue(rowData, column)
      cell:SetText(tostring(value or ""))
      if column.muted and column.muted(rowData) then
        ApplyColor(cell, self.colors.rowTextMuted)
      else
        ApplyColor(cell, self.colors.rowText)
      end
      x = x + width
    end

    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", self.scrollChild, "TOPLEFT", 0, -((dataIndex - 1) * self.rowHeight))
    row:SetWidth(self.contentWidth)
    row:Show()
  end

  function widget:UpdateVisibleRows()
    local totalRows = #self.filteredRows
    local viewportHeight = math.max(self.body:GetHeight() or 1, 1)
    local offset = 0
    if self.scroll.GetVerticalScroll then
      offset = self.scroll:GetVerticalScroll() or 0
    elseif self.scroll.ScrollBar then
      offset = self.scroll.ScrollBar:GetValue() or 0
    end
    local firstIndex = math.floor(offset / self.rowHeight) + 1
    local visibleCount = math.ceil(viewportHeight / self.rowHeight) + DEFAULTS.rowPoolPadding

    if firstIndex < 1 then
      firstIndex = 1
    end

    self:EnsureRowPool(visibleCount)

    local poolIndex = 1
    for dataIndex = firstIndex, math.min(firstIndex + visibleCount - 1, totalRows) do
      self:LayoutRowFrame(self.rowFrames[poolIndex], dataIndex, dataIndex)
      poolIndex = poolIndex + 1
    end

    for i = poolIndex, #self.rowFrames do
      self.rowFrames[i]:Hide()
    end

    self.scrollChild:SetHeight(math.max(totalRows * self.rowHeight, 1))
    self:UpdateScrollRanges()
    self:UpdateStatusText()
  end

  function widget:UpdateStatusText()
    local total = #self.allRows
    local shown = #self.filteredRows
    if shown == total then
      self.statusText:SetText(TimeLoggerL("TABLE_ROWS", total))
    else
      self.statusText:SetText(TimeLoggerL("TABLE_ROWS_FILTERED", shown, total))
    end
  end

  function widget:CollectFilters()
    self.filters = {}
    for i = 1, #self.columns do
      local filter = self.headerFilters[i]
      if filter then
        self.filters[i] = NormalizeFilterText(filter:GetText())
      else
        self.filters[i] = ""
      end
    end
  end

  function widget:ApplyFilters()
    self:CollectFilters()
    self.filteredRows = {}

    for i = 1, #self.allRows do
      local row = self.allRows[i]
      if RowMatchesFilters(row, self.columns, self.filters) then
        self.filteredRows[#self.filteredRows + 1] = row
      end
    end

    self.scroll:SetVerticalScroll(0)
    self.scroll:SetHorizontalScroll(0)
    if self.hSlider then
      self.hSlider:SetValue(0)
    end
    self:UpdateHeaderScroll()
    self:UpdateVisibleRows()

    if self.onFiltersChanged then
      self.onFiltersChanged(self)
    end
  end

  function widget:ColumnsDiffer(nextColumns)
    nextColumns = nextColumns or {}
    if #self.columns ~= #nextColumns then
      return true
    end
    for i = 1, #self.columns do
      local left = self.columns[i]
      local right = nextColumns[i]
      if (left.key or left.title) ~= (right.key or right.title) then
        return true
      end
    end
    return false
  end

  function widget:SetColumns(columns)
    columns = columns or {}
    if self:ColumnsDiffer(columns) then
      for i = 1, #self.headerFilters do
        self.headerFilters[i]:SetText("")
      end
      for _, row in ipairs(self.rowFrames) do
        row:Hide()
      end
      self.rowFrames = {}
    end
    self.columns = columns
    self:LayoutHeader()
  end

  function widget:SetRows(rows)
    self.allRows = rows or {}
    self:ApplyFilters()
    self:UpdateVisibleRows()
  end

  function widget:Refresh()
    self:ApplyFilters()
  end

  function widget:ClearFilters()
    for i = 1, #self.headerFilters do
      self.headerFilters[i]:SetText("")
    end
    self:ApplyFilters()
  end

  function widget:GetFilteredRows()
    return self.filteredRows
  end

  function widget:HasActiveFilters()
    self:CollectFilters()
    for i = 1, #self.filters do
      if self.filters[i] and self.filters[i] ~= "" then
        return true
      end
    end
    return false
  end

  scroll:SetScript("OnScrollRangeChanged", function()
    widget:UpdateVisibleRows()
  end)
  scroll:SetScript("OnVerticalScroll", function()
    widget:UpdateVisibleRows()
  end)

  widget:SetScript("OnSizeChanged", function()
    widget:UpdateVisibleRows()
  end)

  return widget
end
