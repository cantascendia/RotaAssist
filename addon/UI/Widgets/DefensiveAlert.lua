------------------------------------------------------------------------
-- RotaAssist - DefensiveAlert Widget
-- Pulsing icon popping up for low HP defensive recommendation.
-- 生命值过低时弹出的减伤技能提示（独立浮动窗口）。
--
-- Round 19: promoted from a child of the main strip to an INDEPENDENT
-- floating frame (round15 design). A defensive prompt must be readable
-- wherever the player's eyes already are, not glued under the icon bar.
-- Round 19：从主条子框体改为独立浮动窗口（round15 设计）。减伤提示要出现在
-- 玩家视线所在处，而不是黏在图标条下方。
------------------------------------------------------------------------

local _, NS = ...
local RA = NS.RA

-- Design tokens (D-016) / 设计令牌（D-016）
local Theme = RA.Theme

RA.UI = RA.UI or {}
RA.UI.DefensiveAlert = {}
local DefensiveAlert = RA.UI.DefensiveAlert
DefensiveAlert.__index = DefensiveAlert

local ICON_SIZE = 64

---Create a new Defensive Alert widget as an independent floating frame.
---创建独立浮动的减伤提示窗口。
---@return table widget
function DefensiveAlert:Create()
    local obj = setmetatable({}, self)

    -- Container frame attached to UIParent / 挂在 UIParent 上的容器
    local f = CreateFrame("Frame", "RA_DefensiveAlertContainer", UIParent)
    f:SetSize(ICON_SIZE, ICON_SIZE)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 150) -- Default: upper centre / 默认屏幕上方居中
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(frame)
        -- Honour the shared display lock / 复用主显示的锁定开关
        if RA.db and RA.db.profile.display and RA.db.profile.display.locked then return end
        frame:StartMoving()
    end)
    f:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        local point, _, relPoint, x, y = frame:GetPoint()
        if RA.db and RA.db.profile.defensive then
            RA.db.profile.defensive.point = { point, relPoint, x, y }
        end
    end)

    obj.container = f

    -- Restore saved position / 恢复已保存位置
    local defDb = RA.db and RA.db.profile and RA.db.profile.defensive
    local p = defDb and defDb.point
    if p and #p == 4 then
        f:ClearAllPoints()
        f:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    end

    -- IconWidget
    obj.iconWidget = RA.UI.IconWidget:Create(f, ICON_SIZE, "RA_DefensiveAlertIcon")
    obj.iconWidget.frame:SetPoint("CENTER", f, "CENTER", 0, 0)

    -- Extra text above the icon / 图标上方额外文本
    obj.useText = obj.iconWidget.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    obj.useText:SetPoint("BOTTOM", obj.iconWidget.frame, "TOP", 0, 4)
    Theme.ApplyFont(obj.useText, "large")
    Theme.SetTextColor(obj.useText, "alert")
    obj.useText:SetText(RA.L and RA.L["USE_DEFENSIVE"] or "USE!")

    obj.activeSpell = nil
    obj.fadeTimer = nil

    -- Hide container initially / 初始隐藏
    obj.container:Hide()

    return obj
end

---Whether the audible defensive warning is enabled.
---是否启用减伤语音提示。
---FIX (Round 19): 此前 PlaySoundFile 无任何开关，玩家无法关掉。
---FIX (Round 19): the sound used to fire unconditionally with no way to turn it off.
---@return boolean
local function soundEnabled()
    local db = RA.db and RA.db.profile and RA.db.profile.defensive
    if not db then return false end
    return db.soundAlert ~= false
end

---Arm (or re-arm) the auto-dismiss timer.
---装载 / 重置自动消失定时器。
---@param self table
local function armAutoDismiss(self)
    if self.fadeTimer then self.fadeTimer:Cancel() end
    self.fadeTimer = C_Timer.NewTimer(Theme.durations.hold, function()
        self.fadeTimer = nil
        self:Dismiss()
    end)
end

---Trigger the defensive alert visually.
---@param spellID number
---@param texture number
---@param name string
function DefensiveAlert:Trigger(spellID, texture, name)
    if self.activeSpell == spellID and self.container:IsShown() then
        -- Already pulsing this exact defensive: just keep it alive.
        -- 同一技能已在闪烁：仅续期，不重播动画与音效。
        armAutoDismiss(self)
        return
    end

    self.activeSpell = spellID
    self.iconWidget:SetSpell(spellID, texture)
    self.iconWidget:SetAlert(true) -- enable the red pulsating border / 启用红色脉冲边框

    local defaultUseText = RA.L and RA.L["USE_DEFENSIVE"] or "USE!"
    self.useText:SetText(name or defaultUseText)

    -- Audible warning, now behind db.profile.defensive.soundAlert.
    -- 语音提示，受 db.profile.defensive.soundAlert 控制。
    if soundEnabled() then
        pcall(PlaySoundFile, "Sound\\Interface\\RaidWarning.ogg", "Master")
    end

    self.container:SetAlpha(0)
    self.container:Show()
    UIFrameFadeIn(self.container, Theme.durations.fadeIn, 0, 1)

    armAutoDismiss(self)
end

---Dismiss the defensive alert.
---@param immediate boolean|nil Skip the fade during module teardown
function DefensiveAlert:Dismiss(immediate)
    if self.fadeTimer then
        self.fadeTimer:Cancel()
        self.fadeTimer = nil
    end
    self.activeSpell = nil
    self.iconWidget:SetAlert(false)

    if immediate then
        if UIFrameFadeRemoveFrame then
            UIFrameFadeRemoveFrame(self.container)
        end
        self.iconWidget:Clear()
        self.container:SetAlpha(1)
        self.container:Hide()
        return
    end

    if not self.container:IsShown() then return end

    UIFrameFadeOut(self.container, Theme.durations.fadeOut, self.container:GetAlpha(), 0)
    self.fadeTimer = C_Timer.NewTimer(Theme.durations.fadeOut, function()
        self.fadeTimer = nil
        self.container:Hide()
    end)
end
