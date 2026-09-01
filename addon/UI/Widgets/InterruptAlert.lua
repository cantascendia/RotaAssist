------------------------------------------------------------------------
-- RotaAssist - InterruptAlert Widget
-- Standalone floating frame for interrupt recommendations.
-- 打断提醒：独立浮动窗口。
--
-- Round 19: introduced from origin/improve/round15-ui-overhaul. Previously
-- the interrupt icon lived inside MainDisplay's frame, which meant it had to
-- fight the main recommendation for the same pixels and could never be moved
-- into the player's actual line of sight.
-- Round 19：从 round15 分支引入。此前打断图标塞在 MainDisplay 主框里，
-- 与主推荐抢同一块像素，且无法单独挪到玩家真正在看的位置。
------------------------------------------------------------------------

local _, NS = ...
local RA = NS.RA

-- Design tokens (D-016) / 设计令牌（D-016）
local Theme = RA.Theme

RA.UI = RA.UI or {}
RA.UI.InterruptAlert = {}
local InterruptAlert = RA.UI.InterruptAlert
InterruptAlert.__index = InterruptAlert

local ICON_SIZE = 48

---Create a new Interrupt Alert widget as an independent floating frame.
---创建独立浮动的打断提醒窗口。
---@return table widget
function InterruptAlert:Create()
    local obj = setmetatable({}, self)

    -- Container frame attached to UIParent / 挂在 UIParent 上的容器
    local f = CreateFrame("Frame", "RA_InterruptAlertContainer", UIParent)
    f:SetSize(ICON_SIZE, ICON_SIZE)
    -- Default position: just above where the main strip sits by default.
    -- 默认位置：主条默认位置的正上方。
    f:SetPoint("BOTTOM", UIParent, "CENTER", 0, -100)
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
        if RA.db and RA.db.profile.interrupt then
            RA.db.profile.interrupt.point = { point, relPoint, x, y }
        end
    end)

    obj.container = f

    -- Restore saved position / 恢复已保存位置
    local intDb = RA.db and RA.db.profile and RA.db.profile.interrupt
    local p = intDb and intDb.point
    if p and #p == 4 then
        f:ClearAllPoints()
        f:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    end

    -- IconWidget
    obj.iconWidget = RA.UI.IconWidget:Create(f, ICON_SIZE, "RA_InterruptAlertIcon")
    obj.iconWidget.frame:SetPoint("CENTER", f, "CENTER", 0, 0)

    -- Overlay text / 覆盖文本
    obj.useText = obj.iconWidget.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    obj.useText:SetPoint("CENTER", obj.iconWidget.frame, "CENTER", 0, 0)
    Theme.ApplyFont(obj.useText, "large")
    Theme.SetTextColor(obj.useText, "alert")
    obj.useText:SetText(RA.L and RA.L["INTERRUPT_ALERT"] or "INTERRUPT!")

    obj.activeSpell = nil
    obj.container:Hide()

    return obj
end

---Whether the audible interrupt warning is enabled.
---是否启用打断语音提示。
---@return boolean
local function soundEnabled()
    local db = RA.db and RA.db.profile and RA.db.profile.interrupt
    return (db and db.soundAlert) and true or false
end

---Whether the cooldown swirl should be drawn.
---是否绘制冷却转圈（沿用主显示的 showCooldownSwirl 开关）。
---@return boolean
local function swirlEnabled()
    local db = RA.db and RA.db.profile and RA.db.profile.display
    return not db or db.showCooldownSwirl ~= false
end

---Whether an interrupt alert is currently on screen.
---当前是否正在显示打断提醒（供 MainDisplay 抑制主图标高亮）。
---@return boolean
function InterruptAlert:IsActive()
    return self.container:IsShown() and self.activeSpell ~= nil
end

---Trigger the interrupt alert visually.
---@param spellID number   already override-resolved by the caller / 调用方已解析覆盖
---@param texture number
---@param data table       Interrupt data from SmartQueueManager
function InterruptAlert:Trigger(spellID, texture, data)
    self.activeSpell = spellID
    self.iconWidget:SetSpell(spellID, texture)

    if data and data.onCooldown then
        -- Kick is on cooldown: show it greyed out with the sweep so the player
        -- knows the answer is "someone else has to interrupt".
        -- 打断技能在冷却：置灰 + 转圈，让玩家知道"该由别人打断"。
        self.container:SetAlpha(0.6)
        self.iconWidget:SetDesaturated(true)
        self.iconWidget:SetAlert(false)
        if swirlEnabled() and data.startTime and data.duration then
            self.iconWidget:SetCooldown(data.startTime, data.duration)
        else
            self.iconWidget:SetCooldown(nil, nil)
        end
    else
        self.container:SetAlpha(1.0)
        self.iconWidget:SetDesaturated(false)
        self.iconWidget:SetAlert(true)
        self.iconWidget:SetCooldown(nil, nil)

        -- High urgency sound alert / 高紧急度语音提示
        if data and data.urgency and data.urgency >= 0.8 and soundEnabled() then
            pcall(PlaySound, SOUNDKIT.RAID_WARNING)
        end
    end

    self.container:Show()
end

---Dismiss the interrupt alert.
function InterruptAlert:Dismiss()
    self.activeSpell = nil
    self.iconWidget:SetAlert(false)
    if not self.container:IsShown() then return end
    self.iconWidget:Clear()
    self.container:Hide()
end
