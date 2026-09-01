------------------------------------------------------------------------
-- RotaAssist - MainDisplay UI Tests (Round 19 fusion)
--
-- ORIGIN / 来源
--   Adapted from tests/test_main_display_ui.lua on
--   origin/improve/round15-ui-overhaul (129 lines). That file never reached
--   main, so its assertions are NOT protected by the test-lock rule
--   (.claude/rules/test-lock.md legitimate scenario #3: new coverage).
--   本文件改编自 round15 分支的同名测试（129 行）。该文件从未进入 main，
--   因此其断言不受 test-lock 保护（属"新增覆盖"合法场景 #3）。
--
-- ADJUSTMENTS vs the round15 original / 相对 round15 原版的调整
--   1. "filter CD predictions" asserted that UpdateDisplay had mutated the
--      table SmartQueueManager returned (`#mockData.next == 1`). The fused
--      build treats the engine queue as READ-ONLY (Round 19 constraint), so
--      the assertion now checks the rendered widgets instead — and adds a
--      positive assertion that the engine table is left intact.
--      原版断言 UpdateDisplay 就地改写了引擎返回的表；融合版视引擎队列为只读，
--      故改为断言渲染结果，并额外断言引擎表未被改写。
--   2. The cooldown-hiding behaviour is now opt-in
--      (`display.hideCooldownPredictions`), so the test enables it explicitly.
--      冷却隐藏改为可选项，测试显式打开。
--   3. The interrupt case asserted nothing ("assume no crash"). It now asserts
--      the floating container's visibility both ways.
--      打断用例原本只求"不崩"，现改为双向断言浮窗可见性。
--   4. SmartQueueManager is stubbed as a plain module table rather than loaded
--      from addon/Engine — the UI must not depend on engine internals.
--      SmartQueueManager 改为纯桩模块，UI 不应依赖引擎内部实现。
------------------------------------------------------------------------

local helpers = require("tests.helpers")

describe("MainDisplay UI (Round 19 fusion)", function()
    local RA, ns, EH, MD
    local created
    local queueData
    -- Pristine C_Spell stubs. Individual cases swap these to simulate
    -- cooldowns / passives / range, and before_each puts them back — the
    -- runner only insulates globals BETWEEN files, not between cases.
    -- 原始 C_Spell 桩：各用例会替换它们模拟冷却/被动/距离，before_each 负责还原
    -- （运行器只在文件之间隔离全局，不在用例之间隔离）。
    local pristineSpellAPI

    -- Layout constants mirrored from addon/UI/MainDisplay.lua.
    -- 与 addon/UI/MainDisplay.lua 保持一致的布局常量。
    local MAIN_ICON_SIZE = 48
    local PRED_ICON_SIZE = 32
    local STRIP_PADDING  = 8

    ---Wrap every widget class's Create so the test can reach the instances
    ---MainDisplay builds internally.
    ---包装各挂件类的 Create，让测试能拿到 MainDisplay 内部建出的实例。
    local function captureCreates()
        created = {}
        local classes = {
            "IconWidget", "PhaseIndicator", "ResourceBar",
            "AccuracyMeter", "PrePullPanel", "DefensiveAlert", "InterruptAlert",
        }
        for _, key in ipairs(classes) do
            local class = RA.UI[key]
            if class and not class._testWrapped then
                local orig = class.Create
                class._testWrapped = true
                class.Create = function(self, ...)
                    local obj = orig(self, ...)
                    created[key] = created[key] or {}
                    created[key][#created[key] + 1] = obj
                    return obj
                end
            end
        end
    end

    setup(function()
        RA, ns = helpers.loadAddon()
        helpers.loadRegistry(ns)
        helpers.loadAddonFile("addon/Core/EventHandler.lua", "RotaAssist", ns)

        -- Theme first: the .toc guarantees this order at runtime.
        -- Theme 先加载：.toc 在运行期保证同样的顺序。
        helpers.loadAddonFile("addon/UI/Theme.lua", "RotaAssist", ns)
        helpers.loadAddonFile("addon/UI/Widgets/GlowWidget.lua", "RotaAssist", ns)
        helpers.loadAddonFile("addon/UI/Widgets/IconWidget.lua", "RotaAssist", ns)
        helpers.loadAddonFile("addon/UI/Widgets/ResourceBar.lua", "RotaAssist", ns)
        helpers.loadAddonFile("addon/UI/Widgets/PhaseIndicator.lua", "RotaAssist", ns)
        helpers.loadAddonFile("addon/UI/Widgets/AccuracyMeter.lua", "RotaAssist", ns)
        helpers.loadAddonFile("addon/UI/Widgets/PrePullPanel.lua", "RotaAssist", ns)
        helpers.loadAddonFile("addon/UI/Widgets/DefensiveAlert.lua", "RotaAssist", ns)
        helpers.loadAddonFile("addon/UI/Widgets/InterruptAlert.lua", "RotaAssist", ns)
        helpers.loadAddonFile("addon/UI/MainDisplay.lua", "RotaAssist", ns)

        EH = RA:GetModule("EventHandler")
        MD = RA:GetModule("MainDisplay")
        assert.is_not_nil(EH)
        assert.is_not_nil(MD)
        assert.is_not_nil(RA.Theme)

        pristineSpellAPI = {
            IsSpellPassive   = _G.C_Spell.IsSpellPassive,
            GetSpellCooldown = _G.C_Spell.GetSpellCooldown,
            IsSpellInRange   = _G.C_Spell.IsSpellInRange,
        }
    end)

    before_each(function()
        for name, fn in pairs(pristineSpellAPI) do
            _G.C_Spell[name] = fn
        end

        RA.L = setmetatable({}, { __index = function(_, key) return key end })
        RA.db = {
            profile = {
                general = { enabled = true },
                display = {
                    iconCount   = 3,
                    iconSpacing = 4,
                    scale = 1.0,
                    alpha = 1.0,
                    locked = true,
                    hideBackground = false,
                    showOutOfCombat = true,
                    fadeOutOfCombat = false,
                    showKeybinds = true,
                    showCooldownSwirl = true,
                    showRangeIndicator = true,
                    showProcGlow = true,
                    hideCooldownPredictions = false,
                    showResourceBar = true,
                    showPrePullPanel = true,
                },
                coach     = { enabled = true },
                accuracy  = { enabled = true },
                interrupt = { enabled = true, soundAlert = true },
                defensive = { enabled = true, soundAlert = true },
            },
        }

        captureCreates()

        queueData = {
            main = { spellID = 1000, source = "APL" },
            next = {
                { spellID = 1001, confidence = 1.0 },
                { spellID = 1002, confidence = 0.6 },
            },
        }

        RA.modules["SmartQueueManager"] = {
            GetFinalQueue = function() return queueData end,
        }

        if EH.OnEnable then pcall(EH.OnEnable, EH) end
        MD:OnInitialize()
        MD:OnEnable()
    end)

    ------------------------------------------------------------------
    -- Layout: the round15 horizontal strip + main's coach attachments
    -- 布局：round15 水平条 + main 的教练挂件
    ------------------------------------------------------------------

    it("lays the icons out as a horizontal strip", function()
        -- 1 main + 4 prediction slots are built on the strip; DefensiveAlert
        -- and InterruptAlert each own one more icon inside their own frames.
        -- 条上建 1 主 + 4 预测；减伤与打断浮窗各自另有 1 个图标。
        assert.equals(7, #created.IconWidget)
        assert.equals(MAIN_ICON_SIZE, select(1, created.IconWidget[1].frame:GetSize()))
        assert.equals(PRED_ICON_SIZE, select(1, created.IconWidget[2].frame:GetSize()))
        assert.equals(PRED_ICON_SIZE, select(1, created.IconWidget[5].frame:GetSize()))
    end)

    it("sizes the strip and the resource bar from the icon count", function()
        -- iconCount = 3 prediction slots, spacing 4
        local stripWidth = MAIN_ICON_SIZE + 3 * (PRED_ICON_SIZE + 4)
        local frameWidth = select(1, _G.RotaAssistMainFrame:GetSize())
        assert.equals(stripWidth + STRIP_PADDING * 2, frameWidth)

        -- The resource bar spans the strip exactly / 资源条与条同宽
        assert.equals(stripWidth, created.ResourceBar[1].bg:GetWidth())
    end)

    it("builds every coach attachment that differentiates the addon", function()
        assert.equals(1, #created.PhaseIndicator)
        assert.equals(1, #created.ResourceBar)
        assert.equals(1, #created.AccuracyMeter)
        assert.equals(1, #created.PrePullPanel)
        assert.equals(1, #created.DefensiveAlert)
        assert.equals(1, #created.InterruptAlert)
    end)

    ------------------------------------------------------------------
    -- Attachment toggles / 挂件开关
    ------------------------------------------------------------------

    it("honours the per-attachment visibility toggles", function()
        EH:Fire("ROTAASSIST_QUEUE_UPDATED")
        assert.is_true(created.ResourceBar[1].bg:IsShown())

        RA.db.profile.display.showResourceBar = false
        RA.db.profile.coach.enabled = false
        RA.db.profile.accuracy.enabled = false
        EH:Fire("ROTAASSIST_QUEUE_UPDATED")

        assert.is_false(created.ResourceBar[1].bg:IsShown())
        assert.is_false(created.PhaseIndicator[1].isVisible)
        assert.is_false(created.AccuracyMeter[1].isVisible)
    end)

    ------------------------------------------------------------------
    -- Predictions: cooldown filtering (round15) without mutating the engine
    -- 预测：round15 的冷却过滤，且不改写引擎表
    ------------------------------------------------------------------

    it("hides predictions that are on cooldown when the option is enabled", function()
        RA.db.profile.display.hideCooldownPredictions = true

        _G.C_Spell.GetSpellCooldown = function(spellID)
            if spellID == 1002 then
                -- On a real (non-GCD) cooldown / 处于真实冷却
                return { startTime = GetTime(), duration = 10 }
            end
            return { startTime = 0, duration = 0 }
        end

        EH:Fire("ROTAASSIST_QUEUE_UPDATED")

        -- Slot 1 keeps the ready spell, slot 2 is emptied.
        -- 第 1 槽保留就绪技能，第 2 槽被清空。
        assert.is_true(created.IconWidget[2].frame:IsShown())
        assert.is_false(created.IconWidget[3].frame:IsShown())

        -- The engine's queue must come back untouched (Round 19 constraint).
        -- 引擎队列必须原样保留（第 19 轮约束）。
        assert.equals(2, #queueData.next)
        assert.equals(1002, queueData.next[2].spellID)
    end)

    it("keeps cooldown predictions visible when the option is off", function()
        RA.db.profile.display.hideCooldownPredictions = false

        _G.C_Spell.GetSpellCooldown = function(spellID)
            if spellID == 1002 then
                return { startTime = GetTime(), duration = 10 }
            end
            return { startTime = 0, duration = 0 }
        end

        EH:Fire("ROTAASSIST_QUEUE_UPDATED")

        assert.is_true(created.IconWidget[2].frame:IsShown())
        assert.is_true(created.IconWidget[3].frame:IsShown())
    end)

    ------------------------------------------------------------------
    -- Passive safety net carried over from main (commit 1c04669)
    -- 来自 main 的被动技能安全网（commit 1c04669）
    ------------------------------------------------------------------

    it("never lets a passive spell reach the main icon", function()
        _G.C_Spell.IsSpellPassive = function(spellID) return spellID == 1000 end

        EH:Fire("ROTAASSIST_QUEUE_UPDATED")

        assert.is_false(created.IconWidget[1].frame:IsShown())
        -- ...and the engine's queue still owns its own data.
        assert.is_not_nil(queueData.main)
        assert.equals(1000, queueData.main.spellID)
    end)

    ------------------------------------------------------------------
    -- Out-of-range pulse (round15 IconWidget增量)
    ------------------------------------------------------------------

    it("marks the main icon out of range when the target is too far", function()
        _G.C_Spell.IsSpellInRange = function() return false end

        EH:Fire("ROTAASSIST_QUEUE_UPDATED")

        assert.is_true(created.IconWidget[1].outOfRange)

        _G.C_Spell.IsSpellInRange = function() return true end
        EH:Fire("ROTAASSIST_QUEUE_UPDATED")
        assert.is_false(created.IconWidget[1].outOfRange)
    end)

    ------------------------------------------------------------------
    -- Independent floating alerts (round15)
    ------------------------------------------------------------------

    it("shows DefensiveAlert as an independent floating frame", function()
        local defAlert = created.DefensiveAlert[1]
        assert.is_not_nil(defAlert.container)
        assert.is_false(defAlert.container:IsShown())

        defAlert:Trigger(5000, 134400, "Shield Wall")
        assert.is_true(defAlert.container:IsShown())

        defAlert:Dismiss()
        assert.is_nil(defAlert.activeSpell)
    end)

    it("shows and hides InterruptAlert on ROTAASSIST_INTERRUPT_ALERT", function()
        local alert = created.InterruptAlert[1]
        assert.is_false(alert.container:IsShown())

        EH:Fire("ROTAASSIST_INTERRUPT_ALERT", true, { spellID = 6552, urgency = 0.9 })
        assert.is_true(alert.container:IsShown())
        assert.is_true(alert:IsActive())

        EH:Fire("ROTAASSIST_INTERRUPT_ALERT", false, nil)
        assert.is_false(alert.container:IsShown())
        assert.is_false(alert:IsActive())
    end)

    ------------------------------------------------------------------
    -- Theme (D-016) / 主题令牌
    ------------------------------------------------------------------

    it("routes the fallback icon through the theme instead of a literal", function()
        assert.equals(134400, RA.Theme.FALLBACK_ICON)

        local widget = created.IconWidget[2]
        widget:Clear()
        assert.equals(RA.Theme.FALLBACK_ICON, widget.icon:GetTexture())
    end)

    it("exposes one green, one red and one gold as semantic tokens", function()
        assert.is_table(RA.Theme.colors.success)
        assert.is_table(RA.Theme.colors.alert)
        -- confidence gold and the generic gold are literally the same table
        -- 置信度金与通用金是同一张表
        assert.equals(RA.Theme.colors.gold, RA.Theme.colors.confidence)
        assert.equals(RA.Theme.colors.alert, RA.Theme.colors.outOfRange)
    end)
end)
