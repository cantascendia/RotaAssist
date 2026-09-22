-- test: new integration coverage, preserving all earlier UI assertions.
local helpers = require("tests.helpers")
describe("combat UX readiness", function()
    local RA, ns, md, events, icons, labels, queue, originalCreate, binding
    before_each(function()
        RA, ns = helpers.loadAddon(); helpers.loadRegistry(ns)
        RA.L = setmetatable({}, { __index = function(_, key) return key end })
        for _, path in ipairs({"Core/SavedVars", "Core/EventHandler", "UI/Theme", "UI/KeybindResolver",
            "UI/Widgets/GlowWidget", "UI/Widgets/IconWidget", "UI/Widgets/PhaseIndicator",
            "UI/Widgets/ResourceBar", "UI/Widgets/AccuracyMeter", "UI/Widgets/PrePullPanel",
            "UI/Widgets/DefensiveAlert", "UI/Widgets/InterruptAlert", "UI/ConfigPanel", "UI/MainDisplay"}) do
            helpers.loadAddonFile("addon/" .. path .. ".lua", "RotaAssist", ns)
        end
        RA.db = RA:GetModule("SavedVars"):GetDefaults()
        icons, labels = {}, {}
        local createIcon = RA.UI.IconWidget.Create
        RA.UI.IconWidget.Create = function(self, ...)
            local result = createIcon(self, ...); icons[#icons + 1] = result; return result
        end
        originalCreate = CreateFrame
        CreateFrame = function(kind, name, ...)
            local frame = originalCreate(kind, name, ...)
            if name == "RotaAssistMainFrame" then
                local createText = frame.CreateFontString
                frame.CreateFontString = function(self, ...)
                    local fs = createText(self, ...); labels[#labels + 1] = fs; return fs
                end
            end
            return frame
        end
        issecretvalue = function() return false end
        UnitExists = function() return true end
        binding = "1"
        ActionButton1 = { action = 1, bindingAction = "ACTIONBUTTON1" }
        GetActionInfo = function(slot) if slot == 1 then return "spell", 162794 end end
        GetBindingKey = function(command) if command == "ACTIONBUTTON1" then return binding end end
        GetBindingText = nil
        OverrideActionBar = nil
        C_SpellActivationOverlay = { IsSpellOverlayed = function() return true end }
        queue = { main = { spellID = 162794, source = "APL" }, next = {{spellID = 188499}} }
        RA.modules.SmartQueueManager = { GetFinalQueue = function() return queue end }
        events = RA:GetModule("EventHandler"); events:OnEnable()
        md = RA:GetModule("MainDisplay"); md:OnInitialize(); md:OnEnable()
    end)
    after_each(function() md:OnDisable(); CreateFrame = originalCreate end)
    it("clears stale icons when the queue disappears and labels target selection", function()
        events:Fire("ROTAASSIST_QUEUE_UPDATED")
        assert.equals(162794, icons[1].currentSpellID)
        queue = nil; UnitExists = function() return false end
        events:Fire("ROTAASSIST_QUEUE_UPDATED")
        assert.is_nil(icons[1].currentSpellID); assert.is_false(icons[2].frame:IsShown())
        assert.equals("STATUS_SELECT_TARGET", labels[1]:GetText()); assert.is_true(labels[1]:IsShown())
        UnitExists = function() error("unavailable") end
        events:Fire("ROTAASSIST_QUEUE_UPDATED"); assert.equals("STATUS_WAITING", labels[1]:GetText())
    end)
    it("does not manufacture confidence or ignore the glow setting", function()
        RA.db.profile.display.showProcGlow = false
        events:Fire("ROTAASSIST_QUEUE_UPDATED")
        assert.equals("", icons[2].confidence:GetText()); assert.is_false(icons[1].glowEnabled)
        assert.is_nil(icons[1].fadeTimer); assert.is_false(labels[1]:IsShown())
    end)
    it("refreshes cached bindings after page, build and key changes", function()
        events:Fire("ROTAASSIST_QUEUE_UPDATED"); assert.equals("1", icons[1].keybind:GetText())
        for i, event in ipairs({"ACTIONBAR_PAGE_CHANGED", "UPDATE_BINDINGS", "ROTAASSIST_CHARACTER_CHANGED"}) do
            binding = "F" .. i; events:Fire(event); events:Fire("ROTAASSIST_QUEUE_UPDATED")
            assert.equals(binding, icons[1].keybind:GetText())
        end
    end)
    it("keeps text inside each icon without wrapping", function()
        for _, widget in ipairs(icons) do
            assert.is_true(widget.keybind:GetWidth() < widget.frame:GetWidth())
            assert.is_false(widget.keybind._wordWrap); assert.is_false(widget.confidence._wordWrap)
        end
    end)
    it("view presets keep position and recommendation settings", function()
        local config = RA:GetModule("ConfigPanel"); local p = RA.db.profile
        p.display.point = {"CENTER", "CENTER", 123, -234}; p.smartQueue.independentExperimental = true
        p.interrupt.enabled = true; p.defensive.enabled = true
        assert.is_true(config:ApplyViewPreset("focus"))
        assert.is_false(p.coach.enabled); assert.is_false(p.accuracy.enabled); assert.is_false(p.cooldowns.showPanel)
        assert.is_true(p.display.showResourceBar); assert.is_true(p.smartQueue.independentExperimental)
        assert.equals(123, p.display.point[3]); assert.is_true(p.interrupt.enabled); assert.is_true(p.defensive.enabled)
        assert.is_true(config:ApplyViewPreset("learning")); assert.is_true(p.coach.enabled)
        assert.is_true(p.accuracy.enabled); assert.is_true(p.cooldowns.showPanel)
        assert.is_false(config:ApplyViewPreset("unknown"))
    end)
end)
