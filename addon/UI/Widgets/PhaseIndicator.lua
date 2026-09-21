------------------------------------------------------------------------
-- RotaAssist - PhaseIndicator Widget
-- 战斗阶段指示器 / Combat Phase Indicator UI
------------------------------------------------------------------------

local _, NS = ...
local RA = NS.RA

-- Design tokens (D-016) / 设计令牌（D-016）
-- Round 19: the 12-entry PHASE_COLORS table moved to Theme.phases — it is a
-- semantic palette, therefore a theme concern. Icons stay here (they are data,
-- not tokens).
-- Round 19：12 色的 PHASE_COLORS 已迁入 Theme.phases —— 它是语义色板，属主题范畴。
-- 图标留在本文件（那是数据，不是令牌）。
local Theme = RA.Theme

if not RA.UI then RA.UI = {} end

local RA_PhaseIndicator = {}
RA_PhaseIndicator.__index = RA_PhaseIndicator

-- Badge fill opacity, taken from the theme's "inset element" token so the
-- phase tint sits at the same weight as every other small filled surface.
-- 徽章填充不透明度取自主题的"内嵌元素"令牌，与其他小型填充面保持一致。
local BADGE_ALPHA = Theme.colors.bgLight[4]

local PHASE_ICONS = {
    BURST_PREPARE    = "Interface\\Icons\\Ability_Warrior_InnerRage",
    BURST_ACTIVE     = "Interface\\Icons\\Spell_Nature_BloodLust",
    BURST_COOLDOWN   = "Interface\\Icons\\Spell_Holy_AshesToAshes",
    AOE              = "Interface\\Icons\\Spell_Fire_MeteorStorm",
    EMERGENCY        = "Interface\\Icons\\Spell_Holy_GuardianSpirit",
    NORMAL           = "Interface\\Icons\\Ability_MeleeDamage",
    OPENER           = "Interface\\Icons\\Ability_Rogue_Ambush",
    PREPULL          = "Interface\\Icons\\Spell_Nature_TimeStop",
    EXECUTE          = "Interface\\Icons\\Ability_Rogue_Eviscerate",
    RESOURCE_CAP     = "Interface\\Icons\\Ability_Monk_ChiBurst",
    RESOURCE_STARVED = "Interface\\Icons\\Ability_DeathKnight_HungeringCold"
}

---Create a new PhaseIndicator widget.
---@param parent frame
---@return table
function RA_PhaseIndicator:Create(parent)
    local widget = setmetatable({}, self)

    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetSize(100, 20)
    
    Theme.ApplyBackdrop(frame, "badge", "bg", "borderDim")
    widget.frame = frame

    -- Icon
    local icon = frame:CreateTexture(nil, "OVERLAY")
    icon:SetSize(14, 14)
    icon:SetPoint("LEFT", frame, "LEFT", 4, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    widget.icon = icon

    -- Text
    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("LEFT", icon, "RIGHT", 4, 0)
    Theme.SetTextColor(text, "text")
    text:SetText(RA.L and RA.L["UNKNOWN"] or "Unknown")
    widget.text = text

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
    widget.currentPhase = nil

    return widget
end

---Update the phase safely.
---@param phase string Enum value
---@param confidence number 0.0 to 1.0
function RA_PhaseIndicator:Update(phase, confidence)
    if not phase or confidence < 0.4 then
        self:Hide()
        return
    end

    if self.currentPhase ~= phase then
        self.currentPhase = phase
        
        -- Localization / 本地化支持
        local displayStr = (RA.L and RA.L[phase]) or phase
        self.text:SetText(displayStr)
        
        -- Resize to fit / 自动调整宽度
        local textWidth = self.text:GetStringWidth()
        self.frame:SetWidth(textWidth + 26) -- 4 + 14 + 4 + text + 4

        -- Colors / 配色（来自 Theme.phases 语义色板）
        local color = Theme.PhaseColor(phase)
        self.frame:SetBackdropColor(color[1], color[2], color[3], BADGE_ALPHA)
        self.frame:SetBackdropBorderColor(color[1] * 0.5, color[2] * 0.5, color[3] * 0.5, 1.0)

        -- Icon
        local tex = PHASE_ICONS[phase] or Theme.textures.questionMark
        self.icon:SetTexture(tex)
    end

    self:Show()
end

function RA_PhaseIndicator:Show()
    if self.isVisible then return end
    self.isVisible = true
    self.agHide:Stop()
    self.agShow:Play()
end

function RA_PhaseIndicator:Hide()
    if not self.isVisible then return end
    self.isVisible = false
    self.agShow:Stop()
    self.agHide:Play()
end

---Hide immediately and cancel pending animation callbacks during module teardown.
---模块停用时立即隐藏，并取消未完成的动画回调。
function RA_PhaseIndicator:HideImmediate()
    self.isVisible = false
    self.agShow:Stop()
    self.agHide:Stop()
    self.frame:SetAlpha(1)
    self.frame:Hide()
end

RA.UI.PhaseIndicator = RA_PhaseIndicator
