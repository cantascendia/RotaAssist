------------------------------------------------------------------------
-- RotaAssist - AccuracyMeter Widget
-- 准确率指示灯 / Accuracy Meter UI
------------------------------------------------------------------------

local _, NS = ...
local RA = NS.RA

-- Design tokens (D-016) / 设计令牌（D-016）
local Theme = RA.Theme

if not RA.UI then RA.UI = {} end

local RA_AccuracyMeter = {}
RA_AccuracyMeter.__index = RA_AccuracyMeter

---Create a new AccuracyMeter widget.
---@param parent frame
---@param width number
---@param height number
---@return table
function RA_AccuracyMeter:Create(parent, width, height)
    width = width or 120
    height = height or 14

    local widget = setmetatable({}, self)

    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(width, height)
    widget.frame = frame

    -- Background
    local bg = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    bg:SetAllPoints()
    Theme.ApplyBackdrop(bg, "badge", "bg", "borderDim")
    widget.bg = bg

    -- StatusBar
    local bar = CreateFrame("StatusBar", nil, frame)
    bar:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
    bar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
    bar:SetStatusBarTexture(Theme.textures.statusBar)
    bar:SetMinMaxValues(0, 100)
    bar:SetValue(100)
    widget.bar = bar

    -- Label
    local text = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("CENTER", bar, "CENTER", 0, 0)
    Theme.SetTextColor(text, "text")
    text:SetText("100%")
    widget.text = text

    -- Icon (Optional, anchor left)
    local icon = frame:CreateTexture(nil, "OVERLAY")
    icon:SetSize(height, height)
    icon:SetPoint("RIGHT", frame, "LEFT", -4, 0)
    icon:SetTexture("Interface\\Icons\\Achievement_BG_trueAVshutout")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    widget.icon = icon

    -- Fade animations
    widget.agShow = frame:CreateAnimationGroup()
    local alphaIn = widget.agShow:CreateAnimation("Alpha")
    alphaIn:SetFromAlpha(0)
    alphaIn:SetToAlpha(1)
    alphaIn:SetDuration(Theme.durations.fadeIn)
    widget.agShow:SetScript("OnPlay", function() frame:SetAlpha(0); frame:Show() end)
    widget.agShow:SetScript("OnFinished", function() frame:SetAlpha(1) end)

    widget.agHide = frame:CreateAnimationGroup()
    local alphaOut = widget.agHide:CreateAnimation("Alpha")
    alphaOut:SetFromAlpha(1)
    alphaOut:SetToAlpha(0)
    alphaOut:SetDuration(Theme.durations.fadeIn)
    widget.agHide:SetScript("OnFinished", function() frame:Hide(); frame:SetAlpha(1) end)

    frame:Hide()
    widget.isVisible = false
    widget.mode = "smart"

    return widget
end

---Update the accuracy value smoothly.
---@param accuracy number 0 to 100
function RA_AccuracyMeter:Update(accuracy)
    if not accuracy then accuracy = 0 end
    accuracy = math.max(0, math.min(100, accuracy))
    
    self.bar:SetValue(accuracy)
    
    -- Color rules / 配色规则（全部走 Theme 语义令牌，不再自带三套绿/黄/红）
    if accuracy >= 80 then
        self.bar:SetStatusBarColor(Theme.Unpack(Theme.colors.success))
    elseif accuracy >= 60 then
        self.bar:SetStatusBarColor(Theme.Unpack(Theme.colors.warning))
    else
        self.bar:SetStatusBarColor(Theme.Unpack(Theme.colors.alert))
    end

    -- 模式后缀走 i18n：S = SmartQueue 融合推荐，B = 暴雪原生推荐
    -- Localized mode suffix: S = SmartQueue blend, B = Blizzard's own recommendation.
    local suffix
    if self.mode == "smart" then
        suffix = RA.L and RA.L["ACCURACY_SUFFIX_SMART"] or "S"
    else
        suffix = RA.L and RA.L["ACCURACY_SUFFIX_BLIZZARD"] or "B"
    end
    self.text:SetText(string.format("%d%% (%s)", math.floor(accuracy), suffix))
end

---Set the display mode ("smart" or "blizzard").
---@param mode string
function RA_AccuracyMeter:SetMode(mode)
    self.mode = mode == "blizzard" and "blizzard" or "smart"
end

function RA_AccuracyMeter:Show()
    if self.isVisible then return end
    self.isVisible = true
    self.agHide:Stop()
    self.agShow:Play()
end

function RA_AccuracyMeter:Hide()
    if not self.isVisible then return end
    self.isVisible = false
    self.agShow:Stop()
    self.agHide:Play()
end

---Hide immediately and cancel pending animation callbacks during module teardown.
---模块停用时立即隐藏，并取消未完成的动画回调。
function RA_AccuracyMeter:HideImmediate()
    self.isVisible = false
    self.agShow:Stop()
    self.agHide:Stop()
    self.frame:SetAlpha(1)
    self.frame:Hide()
end

RA.UI.AccuracyMeter = RA_AccuracyMeter
