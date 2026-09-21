-- UI release-blocker regressions: Midnight secret values, lazy cooldown
-- population, and lifecycle teardown. / UI 发布阻断回归测试。

local helpers = require("tests.helpers")

describe("ResourceBar protected-value handling", function()
    local RA, ns, ResourceBar
    local originalUnitPower, originalUnitPowerMax, originalIsSecret

    setup(function()
        RA, ns = helpers.loadAddon()
        helpers.loadAddonFile("addon/UI/Theme.lua", "RotaAssist", ns)
        helpers.loadAddonFile("addon/UI/Widgets/ResourceBar.lua", "RotaAssist", ns)
        ResourceBar = RA.UI.ResourceBar
        originalUnitPower = _G.UnitPower
        originalUnitPowerMax = _G.UnitPowerMax
        originalIsSecret = _G.issecretvalue
    end)

    before_each(function()
        _G.UnitPower = originalUnitPower
        _G.UnitPowerMax = originalUnitPowerMax
        _G.issecretvalue = originalIsSecret
    end)

    it("passes a secret current value only to the StatusBar and hides numeric text", function()
        local secretPower = {}
        _G.UnitPower = function() return secretPower end
        _G.UnitPowerMax = function() return 100 end
        _G.issecretvalue = function(value) return value == secretPower end

        local widget = ResourceBar:Create(UIParent, 100, 8)
        assert.has_no.errors(function() widget:UpdateSecretSafe(17) end)
        assert.equals(secretPower, widget.statusBar._value)
        assert.equals("", widget.text:GetText())
    end)

    it("falls back safely when UnitPower succeeds with a nonnumeric value", function()
        _G.UnitPower = function() return nil end
        _G.UnitPowerMax = function() return 100 end

        local widget = ResourceBar:Create(UIParent, 100, 8)
        assert.has_no.errors(function() widget:UpdateSecretSafe(17) end)
        assert.equals(0, widget.statusBar:GetValue())
        assert.equals("", widget.text:GetText())
    end)
end)

describe("CooldownPanel late state population", function()
    local RA, ns, EH, panel, states, created, iconCreate

    setup(function()
        RA, ns = helpers.loadAddon()
        helpers.loadRegistry(ns)
        helpers.loadAddonFile("addon/Core/EventHandler.lua", "RotaAssist", ns)
        helpers.loadAddonFile("addon/UI/Theme.lua", "RotaAssist", ns)
        helpers.loadAddonFile("addon/UI/Widgets/GlowWidget.lua", "RotaAssist", ns)
        helpers.loadAddonFile("addon/UI/Widgets/IconWidget.lua", "RotaAssist", ns)
        helpers.loadAddonFile("addon/UI/CooldownPanel.lua", "RotaAssist", ns)
        EH = RA:GetModule("EventHandler")
        panel = RA:GetModule("CooldownPanel")
        iconCreate = RA.UI.IconWidget.Create
    end)

    before_each(function()
        RA.L = setmetatable({}, { __index = function(_, key) return key end })
        RA.db = { profile = { cooldowns = {
            enabled = true, showPanel = true, panelScale = 1,
            panelLocked = true, trackedSpells = {},
        } } }
        states = {}
        RA.modules["CooldownOverlay"] = {
            GetCooldownStates = function() return states end,
        }

        created = {}
        RA.UI.IconWidget.Create = function(self, ...)
            local widget = iconCreate(self, ...)
            created[#created + 1] = widget
            return widget
        end

        EH:OnEnable()
        panel:OnEnable()
    end)

    after_each(function()
        panel:OnDisable()
    end)

    it("hides an empty panel, then builds icons when cooldown state arrives", function()
        assert.is_false(_G.RotaAssist_CooldownPanel:IsShown())
        assert.equals(0, #created)

        states[198013] = {
            ready = true, remaining = 0, startTime = 0, duration = 0,
            name = "Eye Beam", texture = 12345,
        }
        EH:Fire("ROTAASSIST_CD_UPDATED")

        assert.equals(1, #created)
        assert.is_true(_G.RotaAssist_CooldownPanel:IsShown())
        assert.is_true(created[1].frame:IsShown())
    end)

    it("unsubscribes and hides its widgets on disable", function()
        states[198013] = {
            ready = true, remaining = 0, startTime = 0, duration = 0,
            name = "Eye Beam", texture = 12345,
        }
        EH:Fire("ROTAASSIST_CD_UPDATED")
        panel:OnDisable()

        states[258860] = {
            ready = true, remaining = 0, startTime = 0, duration = 0,
            name = "Essence Break", texture = 12346,
        }
        EH:Fire("ROTAASSIST_CD_UPDATED")

        assert.equals(1, #created)
        assert.is_false(_G.RotaAssist_CooldownPanel:IsShown())
        assert.is_false(created[1].frame:IsShown())
    end)

    it("does not rebuild every refresh when tracked states exceed the icon cap", function()
        for spellID = 1001, 1013 do
            states[spellID] = {
                ready = true, remaining = 0, startTime = 0, duration = 0,
                name = "Spell" .. spellID, texture = spellID,
            }
        end
        EH:Fire("ROTAASSIST_CD_UPDATED")
        assert.equals(12, #created)

        EH:Fire("ROTAASSIST_CD_UPDATED")
        assert.equals(12, #created)
    end)
end)

describe("MainDisplay lifecycle teardown", function()
    local RA, ns, EH, display, queue, timers, createdIcons, iconCreate, removedFades

    setup(function()
        RA, ns = helpers.loadAddon()
        helpers.loadRegistry(ns)
        helpers.loadAddonFile("addon/Core/EventHandler.lua", "RotaAssist", ns)
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
        display = RA:GetModule("MainDisplay")
        iconCreate = RA.UI.IconWidget.Create
    end)

    before_each(function()
        timers = {}
        removedFades = {}
        _G.UIFrameFadeRemoveFrame = function(frame)
            removedFades[frame] = true
        end
        _G.C_Timer.NewTimer = function(_, callback)
            local timer = { callback = callback, cancelled = false }
            function timer:Cancel() self.cancelled = true end
            timers[#timers + 1] = timer
            return timer
        end

        createdIcons = {}
        RA.UI.IconWidget.Create = function(self, ...)
            local widget = iconCreate(self, ...)
            createdIcons[#createdIcons + 1] = widget
            return widget
        end

        RA.L = setmetatable({}, { __index = function(_, key) return key end })
        RA.db = { profile = {
            general = { enabled = true },
            display = {
                iconCount = 2, iconSpacing = 4, scale = 1, alpha = 1,
                locked = true, hideBackground = false,
                showOutOfCombat = true, fadeOutOfCombat = false,
                showKeybinds = true, showCooldownSwirl = true,
                showResourceBar = true, showPrePullPanel = true,
            },
            coach = { enabled = true }, accuracy = { enabled = true },
            defensive = { soundAlert = false }, interrupt = { soundAlert = false },
        } }
        queue = {
            main = { spellID = 198013, source = "BLIZZARD" },
            next = { { spellID = 258860, confidence = 0.8 } },
            defensive = { spellID = 196718, name = "Darkness" },
        }
        RA.modules["SmartQueueManager"] = {
            GetFinalQueue = function() return queue end,
        }

        EH:OnEnable()
        display:OnInitialize()
        display:OnEnable()
    end)

    after_each(function()
        display:OnDisable()
    end)

    it("cancels delayed visuals, unsubscribes, and hides every top-level frame", function()
        EH:Fire("ROTAASSIST_QUEUE_UPDATED")
        EH:Fire("ROTAASSIST_INTERRUPT_ALERT", true,
            { spellID = 183752, urgency = 1.0 })

        display:OnDisable()
        assert.is_false(_G.RotaAssistMainFrame:IsShown())
        assert.is_false(_G.RA_DefensiveAlertContainer:IsShown())
        assert.is_false(_G.RA_InterruptAlertContainer:IsShown())
        assert.is_true(removedFades[createdIcons[1].frame])
        assert.is_true(removedFades[_G.RA_DefensiveAlertContainer])

        -- Simulate the timer service reaching every queued callback. Cancelled
        -- callbacks must not revive a frame after teardown.
        for _, timer in ipairs(timers) do
            if not timer.cancelled then timer.callback() end
        end
        assert.is_false(_G.RotaAssistMainFrame:IsShown())
        assert.is_false(_G.RA_DefensiveAlertContainer:IsShown())

        queue.main = { spellID = 258860, source = "BLIZZARD" }
        EH:Fire("ROTAASSIST_QUEUE_UPDATED")
        assert.is_false(_G.RotaAssistMainFrame:IsShown())
    end)

    it("preserves repeated lookahead steps without merging or reordering them", function()
        queue.defensive = nil
        RA.db.profile.display.iconCount = 4
        queue.next = {
            { spellID = 198013, confidence = 0.8 },
            { spellID = 198013, confidence = 0.7 },
            { spellID = 162794, confidence = 0.6 },
            { spellID = 162794, confidence = 0.5 },
        }
        EH:Fire("ROTAASSIST_QUEUE_UPDATED")

        -- Icon 1 is main; icons 2-5 are the four prediction slots.
        assert.equals(198013, createdIcons[2].currentSpellID)
        assert.equals(198013, createdIcons[3].currentSpellID)
        assert.equals(162794, createdIcons[4].currentSpellID)
        assert.equals(162794, createdIcons[5].currentSpellID)
    end)
end)
