------------------------------------------------------------------------
-- RotaAssist - Resource Bar Widget
-- A compact bar displaying current resource percentage and value.
-- WOW 12.0 SECRET VALUE SAFE: Uses StatusBar widget for in-combat
-- updates — StatusBar:SetValue() accepts secret values natively.
------------------------------------------------------------------------

local _, NS = ...
local RA = NS.RA

-- Design tokens (D-016) / 设计令牌（D-016）
local Theme = RA.Theme

RA.UI = RA.UI or {}
RA.UI.ResourceBar = {}
local ResourceBar = RA.UI.ResourceBar
ResourceBar.__index = ResourceBar

---Create a new Resource Bar.
---@param parent table
---@param width number
---@param height number
---@return table widget
function ResourceBar:Create(parent, width, height)
    local obj = setmetatable({}, self)

    width = width or 48
    height = height or 8

    -- Background Bar
    obj.bg = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    obj.bg:SetSize(width, height)
    Theme.ApplyBackdrop(obj.bg, "solid", "bgLight")

    -- StatusBar (WOW 12.0 SECRET VALUE SAFE: SetValue accepts secrets)
    obj.statusBar = CreateFrame("StatusBar", nil, obj.bg)
    obj.statusBar:SetAllPoints(obj.bg)
    obj.statusBar:SetStatusBarTexture(Theme.textures.solidBg)
    obj.statusBar:SetMinMaxValues(0, 1)
    obj.statusBar:SetValue(0)

    -- Text Overlay
    -- Round 19: 9pt was below the legibility floor; Theme pins the minimum at 10.
    -- Round 19：9pt 低于可读下限，Theme 把最小字号定在 10。
    obj.text = obj.bg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    obj.text:SetPoint("CENTER", obj.bg, "CENTER", 0, 7) -- slightly above the bar
    Theme.ApplyFont(obj.text, "small")

    obj.width = width
    obj.lastPowerType = nil

    return obj
end

---Get color scheme for power type.
---取资源类型对应的配色。
---D-016: the 17/0/1/3/8/11/4 magic-number ladder moved into Theme.power,
---which keys off Enum.PowerType (with literal-id fallbacks).
---D-016：原本 17/0/1/3/8/11/4 的魔法数字阶梯已移入 Theme.power，
---改以 Enum.PowerType 为键（并保留字面 id 回落）。
---@param powerType number Enum.PowerType
---@return number r, number g, number b
local function getPowerTypeColor(powerType)
    return Theme.PowerColor(powerType)
end

---Update the resource bar for non-secret values (out of combat).
---@param current number
---@param max number
---@param powerType number|nil Enum.PowerType
function ResourceBar:Update(current, max, powerType)
    if not current or not max or max <= 0 then
        self.statusBar:SetValue(0)
        self.text:SetText("")
        return
    end

    local pct = current / max
    if pct > 1 then pct = 1 end
    if pct < 0 then pct = 0 end

    self.statusBar:SetMinMaxValues(0, max)
    self.statusBar:SetValue(current)

    -- Text "current/max"
    self.text:SetText(string.format("%.0f/%.0f", current, max))

    -- Set color based on power type
    local r, g, b = getPowerTypeColor(powerType or -1)
    self.statusBar:SetStatusBarColor(r, g, b)
end

---WOW 12.0 SECRET VALUE SAFE: Update using secret-safe widget APIs.
---StatusBar:SetValue() and SetMinMaxValues() accept secret values natively.
---@param powerType number Enum.PowerType
function ResourceBar:UpdateSecretSafe(powerType)
    if not powerType then
        self.statusBar:SetValue(0)
        self.text:SetText("")
        return
    end

    local okCur, curPowerRaw = pcall(UnitPower, "player", powerType)
    local okMax, maxPowerRaw = pcall(UnitPowerMax, "player", powerType)

    local curPower = (okCur and curPowerRaw and not issecretvalue(curPowerRaw)) and curPowerRaw or 0
    local maxPower = (okMax and maxPowerRaw and not issecretvalue(maxPowerRaw) and maxPowerRaw > 0) and maxPowerRaw or 1

    local displayCur = (okCur and curPowerRaw) and curPowerRaw or 0

    self.statusBar:SetMinMaxValues(0, maxPower)
    self.statusBar:SetValue(displayCur)

    -- WOW 12.0 SECRET VALUE SAFE: Use string.format with secrets (produces secret string)
    self.text:SetText(string.format("%.0f/%.0f", displayCur, maxPower))

    -- Set color based on power type (non-secret color choice)
    if self.lastPowerType ~= powerType then
        local r, g, b = getPowerTypeColor(powerType)
        self.statusBar:SetStatusBarColor(r, g, b)
        self.lastPowerType = powerType
    end
end
