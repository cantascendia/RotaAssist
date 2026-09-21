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

    -- `pcall` does not make a protected value safe to truth-test. Check secrecy
    -- before every type/comparison operation, and only pass a secret current value
    -- directly to StatusBar:SetValue(), which is permitted by the Midnight API.
    -- `pcall` 不会让受保护值变得可比较。所有类型/大小判断前先查 secret；
    -- secret 当前值只直传给 Midnight 允许的 StatusBar:SetValue()。
    local curIsSecret = okCur and issecretvalue(curPowerRaw) or false
    local maxIsSecret = okMax and issecretvalue(maxPowerRaw) or false

    local maxPower = 1
    if okMax and not maxIsSecret
       and type(maxPowerRaw) == "number" and maxPowerRaw > 0 then
        maxPower = maxPowerRaw
    end

    local displayCur = 0
    if okCur and (curIsSecret or type(curPowerRaw) == "number") then
        -- Assignment is safe: it does not inspect or branch on the value.
        -- 赋值不会检查该值，可安全把 secret 值送入状态条。
        displayCur = curPowerRaw
    end

    self.statusBar:SetMinMaxValues(0, maxPower)
    self.statusBar:SetValue(displayCur)

    -- Numeric text is optional. Avoid formatting a secret value; the bar remains
    -- useful while preventing protected data from entering string operations.
    -- 数字文字是辅助信息；secret 值不做字符串格式化，资源条本身仍正常显示。
    if okCur and not curIsSecret and type(curPowerRaw) == "number" then
        self.text:SetText(string.format("%.0f/%.0f", curPowerRaw, maxPower))
    else
        self.text:SetText("")
    end

    -- Set color based on power type (non-secret color choice)
    if self.lastPowerType ~= powerType then
        local r, g, b = getPowerTypeColor(powerType)
        self.statusBar:SetStatusBarColor(r, g, b)
        self.lastPowerType = powerType
    end
end
