------------------------------------------------------------------------
-- RotaAssist - Main Display (Horizontal Strip + Coach Attachments)
-- Round 19 fusion of two lineages / 第 19 轮：两条血脉的语义融合
--
--   * Skeleton  ← origin/improve/round15-ui-overhaul (HekiLight-style strip)
--   * Coaching  ← main (PhaseIndicator / ResourceBar / AccuracyMeter /
--                 PrePullPanel — the entire differentiation vs the 7
--                 C_AssistedCombat icon-bar competitors, see VISION.md)
--   * 骨架 ← round15 水平图标条；教练挂件 ← main（本产品对 7 个竞品的全部差异化）
--
--             [PHASE]                  <- badge above the strip / 条上方徽章
--   [MAIN] [PRED1] [PRED2] [PRED3]     <- round15 horizontal strip / 水平条
--          [RESOURCE ========]         <- same width as the strip / 与条同宽
--            [ACCURACY]                <- below the resource bar / 资源条下方
--            [PRE-PULL]                <- out-of-combat checklist / 战前清单
--
--   DefensiveAlert and InterruptAlert are INDEPENDENT floating frames.
--   减伤提示与打断提示为独立浮动窗口。
------------------------------------------------------------------------

local _, NS = ...
local RA = NS.RA
local MainDisplay = {}
RA:RegisterModule("MainDisplay", MainDisplay)

local FRAME_NAME = "RotaAssistMainFrame"

-- Layout metrics / 布局尺寸（非主题令牌：这些是几何量，不是颜色/字号/时长）
local MAX_PREDICTIONS = 4
local MAIN_ICON_SIZE  = 48
local PRED_ICON_SIZE  = 32
local STRIP_PADDING   = 8
local WIDGET_GAP      = 4
local RESOURCE_HEIGHT = 8
local ACCURACY_WIDTH  = 120
local ACCURACY_HEIGHT = 14

------------------------------------------------------------------------
-- Theme access / 主题访问
-- The .toc loads UI\Theme.lua before this file, so RA.Theme is always
-- present at runtime. The nil-guards below exist solely so the file can be
-- unit-tested in isolation (tests/test_main_display.lua loads MainDisplay
-- alone with every widget stubbed).
-- .toc 保证 UI\Theme.lua 先加载，运行期 RA.Theme 恒存在。下面的 nil 兜底
-- 只为让"单独加载本文件"的既有单测继续可跑。
------------------------------------------------------------------------

---@return number|nil iconID  the shared "?" fallback icon / 统一的问号占位图标
local function fallbackIcon()
    local T = RA.Theme
    return T and T.FALLBACK_ICON
end

---Apply (or clear) the strip backdrop using theme tokens.
---按主题令牌套用（或清除）主条背景。
---@param frame table
---@param hidden boolean
---@param bgAlpha number
local function applyStripBackdrop(frame, hidden, bgAlpha)
    if hidden then
        frame:SetBackdrop(nil)
        return
    end
    local T = RA.Theme
    if not T then return end
    T.ApplyBackdrop(frame, "panel", "bg", "border", bgAlpha, math.min(1.0, bgAlpha + 0.3))
end

---Tint the strip border (used to show the locked / unlocked state).
---给主条边框着色（表示锁定 / 解锁状态）。
---@param frame table
---@param alpha number
local function setStripBorderAlpha(frame, alpha)
    local T = RA.Theme
    if not T then return end
    frame:SetBackdropBorderColor(T.Unpack(T.colors.border, alpha))
end

------------------------------------------------------------------------
-- Internal State & UI Elements
------------------------------------------------------------------------

local mainFrame = nil
local elements = {
    phaseIndicator = nil,
    mainIcon       = nil,
    predictions    = {},
    resource       = nil,
    accuracy       = nil,
    prePull        = nil,
    defensive      = nil,   -- independent floating frame / 独立浮窗
    interruptAlert = nil,   -- independent floating frame / 独立浮窗
}

local inCombat = false
local outOfCombatTimer = nil
local lastDisplayed = {
    mainSpell = nil,
    predSpells = {}
}

-- Reusable prediction buffer.
-- UpdateDisplay runs every 0.15–0.6s, so it must not allocate; and per the
-- Round 19 constraints the UI must never mutate the table SmartQueueManager
-- returns (main used to `table.remove` from the engine's live queue).
-- 复用的预测缓冲：UpdateDisplay 每 0.15–0.6s 跑一次，必须零分配；且 UI 不得
-- 改写 SmartQueueManager 返回的活队列（main 此前直接 table.remove 引擎的表）。
local predBuffer = {}

------------------------------------------------------------------------
-- Keybind Cache
------------------------------------------------------------------------

local keybindCache = {}
local keybindCacheDirty = true

local function FindKeybindForSpell(spellID)
    if not spellID then return nil end
    -- 检查缓存 / check the cache
    if keybindCache[spellID] and not keybindCacheDirty then
        return keybindCache[spellID]
    end
    -- 遍历所有动作条槽位 (1-180) / walk every action bar slot
    for slot = 1, 180 do
        local actionType, id = GetActionInfo(slot)
        if actionType == "spell" and id == spellID then
            local key = GetBindingKey("ACTIONBUTTON" .. slot)
            if not key and slot > 12 and slot <= 24 then
                key = GetBindingKey("MULTIACTIONBAR3BUTTON" .. (slot - 12))
            elseif not key and slot > 24 and slot <= 36 then
                key = GetBindingKey("MULTIACTIONBAR4BUTTON" .. (slot - 24))
            elseif not key and slot > 36 and slot <= 48 then
                key = GetBindingKey("MULTIACTIONBAR2BUTTON" .. (slot - 36))
            elseif not key and slot > 48 and slot <= 60 then
                key = GetBindingKey("MULTIACTIONBAR1BUTTON" .. (slot - 48))
            elseif not key and slot > 60 and slot <= 72 then
                key = GetBindingKey("MULTIACTIONBAR5BUTTON" .. (slot - 60))
            elseif not key and slot > 72 and slot <= 84 then
                key = GetBindingKey("MULTIACTIONBAR6BUTTON" .. (slot - 72))
            elseif not key and slot > 84 and slot <= 96 then
                key = GetBindingKey("MULTIACTIONBAR7BUTTON" .. (slot - 84))
            end
            if key then
                -- 简化显示：SHIFT-F → S-F, CTRL-1 → C-1, ALT-Q → A-Q
                key = key:gsub("SHIFT%-", "S-")
                key = key:gsub("CTRL%-", "C-")
                key = key:gsub("ALT%-", "A-")
                key = key:gsub("NUMPAD", "N")
                keybindCache[spellID] = key
                return key
            end
        end
    end
    keybindCache[spellID] = false  -- 标记为"查过了但没找到" / negative cache
    return nil
end

------------------------------------------------------------------------
-- Shared update helpers
-- Hoisted to module scope: main defined these as closures INSIDE
-- UpdateDisplay, allocating two closures on every 0.15–0.6s tick.
-- 提升到模块作用域：main 把它们定义在 UpdateDisplay 内部，每个刷新周期
-- 都会分配两个闭包。
------------------------------------------------------------------------

---Resolve talent overrides so the icon matches the button the player presses.
---解析天赋覆盖，保证显示的图标与玩家实际按下的按钮一致。
---@param spellID number|nil
---@return number|nil
local function resolveDisplaySpellID(spellID)
    if not spellID then return nil end
    if RA.ResolveSpellOverride then
        local resolvedID = RA:ResolveSpellOverride(spellID)
        if resolvedID and resolvedID ~= 0 then
            return resolvedID
        end
    end
    return spellID
end

---Drive an icon's cooldown sweep.
---驱动图标的冷却转圈。
---AGENTS.md rule: every cooldown read goes through RA:GetSpellCooldownSafe()
---(secret-value safe); never call C_Spell.GetSpellCooldown directly.
---AGENTS.md 规则：所有冷却读取必须走 RA:GetSpellCooldownSafe()（secret 安全），
---不得直接调用 C_Spell.GetSpellCooldown。
---@param widget table|nil
---@param spellID number|nil
---@param showSwirl boolean
local function updateWidgetCooldown(widget, spellID, showSwirl)
    if not widget then return end
    if not showSwirl or not spellID then
        widget:SetCooldown(nil, nil)
        return
    end

    local remaining, ready, startTime, duration = RA:GetSpellCooldownSafe(spellID)
    if remaining == nil or ready or not startTime or not duration or duration <= 1.5 then
        widget:SetCooldown(nil, nil)
        return
    end

    widget:SetCooldown(startTime, duration)
end

---Fetch a spell's icon texture, falling back to the theme's "?" icon.
---取技能图标纹理，失败时回落到主题的问号图标。
---@param spellID number|nil
---@return number|nil texture
local function iconTextureFor(spellID)
    local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
    return (ok and info and info.iconID) or fallbackIcon()
end

---Whether a predicted spell is currently on a real (non-GCD) cooldown.
---预测技能当前是否处于真实冷却（非 GCD）。
---@param spellID number|nil
---@return boolean
local function isOnRealCooldown(spellID)
    if not spellID then return false end
    local _, ready, _, duration = RA:GetSpellCooldownSafe(spellID)
    if ready then return false end
    return (duration ~= nil) and duration > 1.5
end

------------------------------------------------------------------------
-- Layout Engine
------------------------------------------------------------------------

local function buildLayout()
    mainFrame = CreateFrame("Button", FRAME_NAME, UIParent, "BackdropTemplate")
    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:SetClampedToScreen(true)

    -- 1. Horizontal strip: main recommendation + lookahead predictions
    --    水平条：主推荐 + 前瞻预测（round15 骨架）
    elements.mainIcon = RA.UI.IconWidget:Create(mainFrame, MAIN_ICON_SIZE, "RA_MainIcon")

    for i = 1, MAX_PREDICTIONS do
        local pred = RA.UI.IconWidget:Create(mainFrame, PRED_ICON_SIZE)
        pred.frame:SetAlpha(0.8)
        elements.predictions[i] = pred
    end

    -- 2. Phase badge above the strip / 条上方的阶段徽章
    elements.phaseIndicator = RA.UI.PhaseIndicator:Create(mainFrame)
    elements.phaseIndicator.frame:SetPoint("BOTTOM", mainFrame, "TOP", 0, WIDGET_GAP)

    -- 3. Resource bar below the strip (width synced in applySettings)
    --    条下方的资源条（宽度在 applySettings 中与条同步）
    elements.resource = RA.UI.ResourceBar:Create(mainFrame, MAIN_ICON_SIZE, RESOURCE_HEIGHT)
    elements.resource.bg:SetPoint("TOP", mainFrame, "BOTTOM", 0, -WIDGET_GAP)

    -- 4. Accuracy meter below the resource bar / 资源条下方的准确率仪表
    elements.accuracy = RA.UI.AccuracyMeter:Create(mainFrame, ACCURACY_WIDTH, ACCURACY_HEIGHT)
    elements.accuracy.frame:SetPoint("TOP", elements.resource.bg, "BOTTOM", 0, -WIDGET_GAP)

    -- 5. Pre-pull checklist.
    --    Deliberately kept a CHILD of mainFrame: the Round 16 fix (Bug1) in
    --    PrePullPanel:Update() ends with an unconditional Show(), and its
    --    correctness argument is that MainDisplay's explicit Hide() calls plus
    --    parent visibility still win. Re-parenting it to UIParent would silently
    --    invalidate that fix, so it stays anchored under the coach stack instead.
    --    刻意保持为 mainFrame 的子框体：R16 (Bug1) 修复让 Update() 结尾无条件 Show()，
    --    其正确性依赖"父框体隐藏时子框体一并不可见"。改挂 UIParent 会静默废掉该修复。
    elements.prePull = RA.UI.PrePullPanel:Create(mainFrame)
    elements.prePull.frame:SetPoint("TOP", elements.accuracy.frame, "BOTTOM", 0, -WIDGET_GAP)

    -- 6. Independent floating alerts (round15) / 独立浮动警报（round15）
    elements.defensive = RA.UI.DefensiveAlert:Create()
    if RA.UI.InterruptAlert then
        elements.interruptAlert = RA.UI.InterruptAlert:Create()
    end

    -- Load position — schema unchanged from main so existing saved coordinates
    -- keep working (no migration). / 位置 schema 与 main 一致，老坐标直接可用。
    local dbDisplay = RA.db and RA.db.profile.display or {}
    local p = dbDisplay.point
    if p and #p == 4 then
        mainFrame:ClearAllPoints()
        mainFrame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    else
        mainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
    end
end

------------------------------------------------------------------------
-- Settings application (geometry, backdrop, drag)
------------------------------------------------------------------------

---How many prediction slots the user wants to see.
---用户希望看到几个预测槽。
---`display.iconCount` keeps main's meaning — the number of PREDICTION icons,
---not the total icon count — so existing profiles are not reinterpreted.
---`display.iconCount` 沿用 main 的语义（预测图标数，而非图标总数），老配置不被误读。
---@param display table
---@return number
local function predictionSlots(display)
    local n = display.iconCount or 2
    if n < 1 then n = 1 end
    if n > MAX_PREDICTIONS then n = MAX_PREDICTIONS end
    return n
end

-- Forward declaration: applySettings() ends by re-running visibility, which is
-- defined further down next to the combat-state handlers.
-- 前置声明：applySettings() 结尾要跑可见性判断，而后者定义在战斗状态处理旁。
local checkVisibility

local function applySettings()
    local display = RA.db and RA.db.profile.display or {}
    local isLocked = display.locked or false

    mainFrame:SetScale(display.scale or 1.0)
    applyStripBackdrop(mainFrame, display.hideBackground, display.bgAlpha or 0.5)

    -- Drag handling + the lock affordance.
    -- FIX (Round 19): main tinted the border for the lock state BEFORE
    -- re-applying the backdrop, and the backdrop's own border colour then
    -- overwrote it — so locking/unlocking never showed. Order corrected here.
    -- FIX（第 19 轮）：main 先给边框着色表示锁定状态，随后重设 backdrop 又把
    -- 边框色覆盖掉，导致锁定/解锁在视觉上毫无反馈。此处修正了顺序。
    if isLocked then
        mainFrame:RegisterForDrag()
        mainFrame:SetScript("OnDragStart", nil)
        mainFrame:SetScript("OnDragStop", nil)
        if not display.hideBackground then setStripBorderAlpha(mainFrame, 0) end
    else
        mainFrame:RegisterForDrag("LeftButton")
        mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
        mainFrame:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            local point, _, relPoint, x, y = self:GetPoint()
            if RA.db then
                RA.db.profile.display.point = { point, relPoint, x, y }
            end
        end)
        if not display.hideBackground then setStripBorderAlpha(mainFrame, 0.8) end
    end

    -- Horizontal strip geometry / 水平条几何
    local slots = predictionSlots(display)
    local spacing = display.iconSpacing or WIDGET_GAP

    local stripWidth = MAIN_ICON_SIZE + slots * (PRED_ICON_SIZE + spacing)
    mainFrame:SetSize(stripWidth + STRIP_PADDING * 2, MAIN_ICON_SIZE + STRIP_PADDING * 2)

    elements.mainIcon.frame:ClearAllPoints()
    elements.mainIcon.frame:SetPoint("LEFT", mainFrame, "LEFT", STRIP_PADDING, 0)

    for i = 1, MAX_PREDICTIONS do
        local pred = elements.predictions[i]
        pred.frame:ClearAllPoints()
        if i == 1 then
            pred.frame:SetPoint("LEFT", elements.mainIcon.frame, "RIGHT", spacing, 0)
        else
            pred.frame:SetPoint("LEFT", elements.predictions[i - 1].frame, "RIGHT", spacing, 0)
        end
    end

    -- Resource bar spans the strip / 资源条与条同宽
    if elements.resource and elements.resource.bg then
        elements.resource.bg:SetWidth(stripWidth)
    end

    checkVisibility()
end

------------------------------------------------------------------------
-- Update Logic
------------------------------------------------------------------------

local function UpdateDisplay()
    local smartQ = RA:GetModule("SmartQueueManager")
    if not smartQ then return end

    local data = smartQ:GetFinalQueue()
    if not data then return end

    local display  = RA.db and RA.db.profile.display or {}
    local showKeybinds     = display.showKeybinds ~= false
    local showCooldownSwirl = display.showCooldownSwirl ~= false
    local showProcGlow     = display.showProcGlow ~= false
    local showRange        = display.showRangeIndicator ~= false
    -- Opt-in (round15 behaviour): drop predicted spells that are currently on
    -- cooldown instead of showing them greyed out with a sweep. Default OFF so
    -- existing profiles keep main's lookahead semantics.
    -- 可选（round15 行为）：把处于冷却的预测技能直接隐去，而不是灰显加转圈。
    -- 默认关闭，老用户仍保留 main 的前瞻语义。
    local hideCDPredictions = display.hideCooldownPredictions == true
    local slots = predictionSlots(display)

    ------------------------------------------------------------------
    -- 0. Read-only projection of the engine queue.
    --    引擎队列的只读投影：绝不改写 SmartQueueManager 返回的表。
    ------------------------------------------------------------------

    -- UI safety net: filter passive spells before display.
    -- 【安全网】过滤被动技能，防止 assisted-combat 的辅助图标漏进主显示。
    -- (introduced in 1c04669 — keep it: Blizzard's recommendation stream can
    --  contain passive talent ids that must never reach the strip.)
    local mainData = data.main
    if mainData and RA:IsSpellPassive(mainData.spellID) then
        mainData = nil
    end

    wipe(predBuffer)
    if data.next then
        for i = 1, #data.next do
            local predData = data.next[i]
            if predData and not RA:IsSpellPassive(predData.spellID) then
                if not (hideCDPredictions and isOnRealCooldown(predData.spellID)) then
                    predBuffer[#predBuffer + 1] = predData
                end
            end
        end
    end

    local interruptActive = elements.interruptAlert and elements.interruptAlert:IsActive() or false

    ------------------------------------------------------------------
    -- 1. Main Icon / 主图标
    ------------------------------------------------------------------
    if mainData then
        local mainDisplaySpellID = resolveDisplaySpellID(mainData.spellID)
        if lastDisplayed.mainSpell ~= mainDisplaySpellID then
            elements.mainIcon:SetSpell(mainDisplaySpellID, iconTextureFor(mainDisplaySpellID))
            lastDisplayed.mainSpell = mainDisplaySpellID
        end

        -- Proc glow (round15): Blizzard's own spell-activation overlay wins.
        -- Proc 高亮（round15）：优先采用暴雪自己的技能激活覆盖状态。
        local hasProc = false
        if showProcGlow then
            local overlay = _G.C_SpellActivationOverlay
            if overlay and overlay.IsSpellOverlayed then
                local pOk, pRes = pcall(overlay.IsSpellOverlayed, mainDisplaySpellID)
                if pOk and pRes then hasProc = true end
            end
        end

        -- 如果正在显示中断提醒，不覆盖其视觉效果
        -- Do not compete with an active interrupt alert for the player's attention.
        if interruptActive then
            elements.mainIcon:SetGlow(false)
        else
            elements.mainIcon:SetGlow(hasProc or mainData.source ~= "DEFENSIVE")
        end

        -- Range indicator (round15): pulse red when the target is out of reach.
        -- 超距提示（round15）：目标不在范围内时红色脉冲。
        -- SetOutOfRange is an OPTIONAL icon capability: it arrived with the
        -- round15 lineage, so MainDisplay must not hard-require it of every
        -- IconWidget implementation.
        -- SetOutOfRange 属于可选的图标能力（随 round15 血脉引入），
        -- MainDisplay 不得强制要求所有 IconWidget 实现都提供它。
        if elements.mainIcon.SetOutOfRange then
            local outOfRange = false
            if showRange and C_Spell and C_Spell.IsSpellInRange then
                local rOk, rRes = pcall(C_Spell.IsSpellInRange, mainDisplaySpellID, "target")
                if rOk and rRes == false then outOfRange = true end
            end
            elements.mainIcon:SetOutOfRange(outOfRange)
        end

        local mainKey = showKeybinds and FindKeybindForSpell(mainDisplaySpellID) or ""
        elements.mainIcon:SetKeybind(mainKey or "")
        updateWidgetCooldown(elements.mainIcon, mainDisplaySpellID, showCooldownSwirl)

        -- 盲区技能标识：显示来源标签
        -- SetConfidence 接受 0–1 浮点（>=0.8 → ★★★，>=0.5 → ★★☆，>0 → ★☆☆，<=0 → 清空）
        -- SetConfidence takes a 0–1 float (>=0.8 → ★★★, >=0.5 → ★★☆, >0 → ★☆☆, <=0 → cleared)
        if mainData.source == "APL_BLINDSPOT" then
            elements.mainIcon:SetConfidence(0.9)  -- 高置信星标：这是我们的补充推荐 / high-confidence badge
        else
            elements.mainIcon:SetConfidence(0)    -- 清除星标 / clear the stars
        end

        elements.mainIcon.frame:Show()
    else
        elements.mainIcon:Clear()
        elements.mainIcon:SetKeybind("")
        elements.mainIcon:SetCooldown(nil, nil)
        elements.mainIcon.frame:Hide()
        lastDisplayed.mainSpell = nil
    end

    ------------------------------------------------------------------
    -- 2. Predictions / 前瞻预测（本产品的核心差异化）
    ------------------------------------------------------------------
    for i = 1, MAX_PREDICTIONS do
        local widget = elements.predictions[i]
        local predData = (i <= slots) and predBuffer[i] or nil

        if predData then
            local predDisplaySpellID = resolveDisplaySpellID(predData.spellID)
            if lastDisplayed.predSpells[i] ~= predDisplaySpellID then
                widget:SetSpell(predDisplaySpellID, iconTextureFor(predDisplaySpellID))
                lastDisplayed.predSpells[i] = predDisplaySpellID
            end
            -- predData.confidence 本就是 0–1 浮点，与 SetConfidence 的分档语义一致
            -- predData.confidence is already a 0–1 float, matching SetConfidence's thresholds
            widget:SetConfidence(predData.confidence or 1.0)

            local predKey = showKeybinds and FindKeybindForSpell(predDisplaySpellID) or ""
            widget:SetKeybind(predKey or "")
            updateWidgetCooldown(widget, predDisplaySpellID, showCooldownSwirl)

            widget.frame:Show()
        else
            widget:Clear()
            widget:SetKeybind("")
            widget:SetCooldown(nil, nil)
            widget.frame:Hide()
            lastDisplayed.predSpells[i] = nil
        end
    end

    ------------------------------------------------------------------
    -- 3. Defensive Alert (independent floating frame) / 减伤提示（独立浮窗）
    ------------------------------------------------------------------
    if data.defensive then
        local defensiveDisplaySpellID = resolveDisplaySpellID(data.defensive.spellID)
        elements.defensive:Trigger(defensiveDisplaySpellID,
            iconTextureFor(defensiveDisplaySpellID), data.defensive.name)
    else
        elements.defensive:Dismiss()
    end

    ------------------------------------------------------------------
    -- 4. Resource Bar / 资源条
    -- WOW 12.0 SECRET VALUE SAFE: UpdateSecretSafe passes secret UnitPower
    -- values straight to StatusBar:SetValue() (allowed) — never branches on them.
    ------------------------------------------------------------------
    if display.showResourceBar ~= false then
        local specDetector = RA:GetModule("SpecDetector")
        if specDetector then
            local powerType = specDetector:GetPrimaryPowerType()
            if powerType then
                elements.resource:UpdateSecretSafe(powerType)
            end
        end
        elements.resource.bg:Show()
    else
        elements.resource.bg:Hide()
    end

    ------------------------------------------------------------------
    -- 5. Phase Indicator / 阶段徽章
    ------------------------------------------------------------------
    local showCoach = RA.db and RA.db.profile.coach and RA.db.profile.coach.enabled
    if showCoach and data.aiContext and data.aiContext.phase then
        elements.phaseIndicator:Update(data.aiContext.phase, data.aiContext.phaseConfidence or 1.0)
    else
        elements.phaseIndicator:Hide()
    end

    ------------------------------------------------------------------
    -- 6. Accuracy Meter / 准确率仪表
    ------------------------------------------------------------------
    local showAcc = RA.db and RA.db.profile.accuracy and RA.db.profile.accuracy.enabled
    if showAcc and inCombat then
        local accTracker = RA:GetModule("AccuracyTracker")
        if accTracker then
            local stats = accTracker:GetSessionStats()
            if stats then
                elements.accuracy:Update(stats.smartAccuracy)
                elements.accuracy:Show()
            end
        end
    else
        elements.accuracy:Hide()
    end

    ------------------------------------------------------------------
    -- 7. Pre-Pull Panel / 战前清单
    ------------------------------------------------------------------
    if not inCombat and display.showPrePullPanel ~= false then
        local ppc = RA:GetModule("PrePullChecker")
        if ppc then
            local ok, checks = pcall(ppc.RunChecks, ppc)
            if ok and checks then
                elements.prePull:Update(checks)
            end
        end
    else
        elements.prePull:Hide()
    end
end

------------------------------------------------------------------------
-- Interrupt Alert Handler
-- Round 19: delegates to the standalone InterruptAlert widget (round15).
-- The override resolution and the "suppress the main glow" rule are main's.
-- Round 19：委托给独立的 InterruptAlert 挂件（round15）；覆盖解析与
-- "压制主图标高亮"的规则来自 main。
------------------------------------------------------------------------

local function UpdateInterrupt(_, active, data)
    if not elements.interruptAlert then return end

    if active and data then
        local interruptDisplaySpellID = resolveDisplaySpellID(data.spellID)
        elements.interruptAlert:Trigger(interruptDisplaySpellID,
            iconTextureFor(interruptDisplaySpellID), data)
    else
        elements.interruptAlert:Dismiss()
    end

    -- Re-render so the main icon's glow reflects the new interrupt state.
    -- 重绘一次，让主图标高亮反映新的打断状态。
    UpdateDisplay()
end

------------------------------------------------------------------------
-- Combat State & Visibility
------------------------------------------------------------------------

-- luacheck: ignore checkVisibility (assigns the forward-declared local above)
checkVisibility = function()
    if not mainFrame then return end

    local generalEnabled = RA.db and RA.db.profile.general and RA.db.profile.general.enabled
    local display = RA.db and RA.db.profile.display or {}
    local combatOnly = display.combatOnly or false
    local showOutOfCombat = display.showOutOfCombat ~= false
    local baseAlpha = display.alpha or 1.0
    local effectiveAlpha = baseAlpha

    if not generalEnabled then
        if outOfCombatTimer then
            outOfCombatTimer:Cancel()
            outOfCombatTimer = nil
        end
        mainFrame:Hide()
        elements.prePull:Hide()
        return
    end

    if not inCombat and display.fadeOutOfCombat and showOutOfCombat and not combatOnly then
        effectiveAlpha = math.max(0.1, math.min(baseAlpha, display.fadeAlpha or 0.3))
    end
    mainFrame:SetAlpha(effectiveAlpha)

    if (combatOnly or not showOutOfCombat) and not inCombat then
        if not outOfCombatTimer then
            outOfCombatTimer = C_Timer.NewTimer(3.0, function()
                if not inCombat then
                    mainFrame:Hide()
                    elements.prePull:Hide()
                end
                outOfCombatTimer = nil
            end)
        end
    else
        if outOfCombatTimer then
            outOfCombatTimer:Cancel()
            outOfCombatTimer = nil
        end
        mainFrame:Show()
        if not inCombat and display.showPrePullPanel ~= false then
            local ppc = RA:GetModule("PrePullChecker")
            if ppc then
                local ok, checks = pcall(ppc.RunChecks, ppc)
                if ok and checks then
                    elements.prePull:Update(checks)
                end
            end
        end
    end
    UpdateDisplay()
end

------------------------------------------------------------------------
-- Context Menu
------------------------------------------------------------------------

local function buildMenu(ownerFrame, rootDescription)
    -- Lock/Unlock
    local lockedText = (RA.L and RA.L["UNLOCK_POSITION"] or "Unlock Position")
    if RA.db and not RA.db.profile.display.locked then
        lockedText = (RA.L and RA.L["LOCK_POSITION"] or "Lock Position")
    end
    rootDescription:CreateButton(lockedText, function()
        RA.db.profile.display.locked = not RA.db.profile.display.locked
        applySettings()
    end)

    -- Combat Only
    local combatOnly = RA.db and RA.db.profile.display.combatOnly or false
    local combatText = (RA.L and RA.L["COMBAT_ONLY_TOOLTIP"] or "Combat Only")
    rootDescription:CreateCheckbox(combatText, function() return combatOnly end, function()
        RA.db.profile.display.combatOnly = not RA.db.profile.display.combatOnly
        checkVisibility()
    end)

    -- Phase Indicator
    local coachText = (RA.L and RA.L["SHOW_PHASE_INDICATOR"] or "Show Phase Indicator")
    rootDescription:CreateCheckbox(coachText,
        function() return RA.db and RA.db.profile.coach and RA.db.profile.coach.enabled end,
        function()
            if RA.db and RA.db.profile.coach then
                RA.db.profile.coach.enabled = not RA.db.profile.coach.enabled
                UpdateDisplay()
            end
        end
    )

    -- Resource Bar
    local resText = (RA.L and RA.L["SHOW_RESOURCE_BAR"] or "Show Resource Bar")
    rootDescription:CreateCheckbox(resText,
        function() return RA.db and RA.db.profile.display.showResourceBar ~= false end,
        function()
            if RA.db then
                RA.db.profile.display.showResourceBar =
                    not (RA.db.profile.display.showResourceBar ~= false)
                UpdateDisplay()
            end
        end
    )

    -- Accuracy Meter
    local accText = (RA.L and RA.L["SHOW_ACCURACY_METER"] or "Show Accuracy Meter")
    rootDescription:CreateCheckbox(accText,
        function() return RA.db and RA.db.profile.accuracy and RA.db.profile.accuracy.enabled end,
        function()
            if RA.db and RA.db.profile.accuracy then
                RA.db.profile.accuracy.enabled = not RA.db.profile.accuracy.enabled
                UpdateDisplay()
            end
        end
    )

    -- Scale sub-menu
    local scaleStr = (RA.L and RA.L["ICON_SIZE_TOOLTIP"] or "Scale")
    local scaleMenu = rootDescription:CreateButton(scaleStr)
    for _, val in ipairs({0.75, 1.0, 1.25, 1.5}) do
        scaleMenu:CreateRadio(string.format("%d%%", val * 100),
        function() return RA.db and RA.db.profile.display.scale == val end,
        function()
            RA.db.profile.display.scale = val
            applySettings()
        end)
    end

    rootDescription:CreateDivider()

    -- Open Options
    local optsStr = (RA.L and RA.L["OPTIONS"] or "Options")
    rootDescription:CreateButton(optsStr, function()
        if Settings and Settings.OpenToCategory then
            Settings.OpenToCategory(RA.name)
        elseif InterfaceOptionsFrame_OpenToCategory then
            InterfaceOptionsFrame_OpenToCategory(RA.name)
        end
    end)
end

------------------------------------------------------------------------
-- Module Lifecycle
------------------------------------------------------------------------

function MainDisplay:OnInitialize()
    buildLayout()
end

function MainDisplay:OnEnable()
    applySettings()

    if MenuUtil and MenuUtil.CreateContextMenu then
        mainFrame:SetScript("OnMouseUp", function(_, button)
            if button == "RightButton" then
                MenuUtil.CreateContextMenu(mainFrame, buildMenu)
            end
        end)
    end

    local eh = RA:GetModule("EventHandler")
    if not eh then return end

    -- Use new SmartQueue events for primary drive
    eh:Subscribe("ROTAASSIST_QUEUE_UPDATED", "MainDisplay", UpdateDisplay)

    eh:Subscribe("ROTAASSIST_INTERRUPT_ALERT", "MainDisplay", UpdateInterrupt)
    eh:Subscribe("ROTAASSIST_SETTINGS_RESET", "MainDisplay", applySettings)

    eh:Subscribe("ACTIONBAR_SLOT_CHANGED", "MainDisplay", function()
        keybindCacheDirty = true
        keybindCache = {}
        UpdateDisplay()
    end)

    eh:Subscribe("UPDATE_BINDINGS", "MainDisplay", function()
        keybindCacheDirty = true
        keybindCache = {}
        UpdateDisplay()
    end)

    eh:Subscribe("PLAYER_REGEN_DISABLED", "MainDisplay", function()
        inCombat = true
        checkVisibility()
    end)

    eh:Subscribe("PLAYER_REGEN_ENABLED", "MainDisplay", function()
        inCombat = false
        checkVisibility()
    end)

    checkVisibility()
end

---Public API
function MainDisplay:Toggle()
    if RA.db then
        local current = RA.db.profile.general.enabled ~= false
        RA.db.profile.general.enabled = not current
        checkVisibility()
        if RA.db.profile.general.enabled then
            RA:Print(RA.L and RA.L["DISPLAY_ENABLED"] or "Display enabled.")
        else
            RA:Print(RA.L and RA.L["DISPLAY_DISABLED"] or "Display hidden.")
        end
    end
end

function MainDisplay:ToggleLock()
    if RA.db then
        RA.db.profile.display.locked = not RA.db.profile.display.locked
        applySettings()
        if RA.db.profile.display.locked then
            RA:Print(RA.L and RA.L["DISPLAY_LOCKED"] or "Display locked.")
        else
            RA:Print(RA.L and RA.L["DISPLAY_UNLOCKED"] or "Display unlocked.")
        end
    end
end
