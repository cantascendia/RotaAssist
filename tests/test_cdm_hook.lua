-- tests/test_cdm_hook.lua
-- Unit tests for the CDMHook module (Phase 2 v1.1).
-- Covers: lifecycle, public API surface, opt-in default-disabled behaviour,
-- alert dispatch, hook attachment to a mocked EssentialCooldownViewer.
local helpers = require("tests.helpers")

describe("CDMHook", function()
    local RA, ns, EH, CDM, CO

    setup(function()
        RA, ns = helpers.loadAddon()
        helpers.loadRegistry(ns)
        helpers.loadAddonFile("addon/Core/EventHandler.lua", "RotaAssist", ns)
        helpers.loadAddonFile("addon/Engine/CooldownOverlay.lua", "RotaAssist", ns)
        helpers.loadAddonFile("addon/Engine/CDMHook.lua", "RotaAssist", ns)
        EH  = RA:GetModule("EventHandler")
        CDM = RA:GetModule("CDMHook")
        CO  = RA:GetModule("CooldownOverlay")
        assert(EH,  "EventHandler failed to load")
        assert(CDM, "CDMHook failed to load")
        assert(CO,  "CooldownOverlay failed to load")
        CO:OnInitialize()
        CDM:OnInitialize()
        -- Ensure RA.db.profile.cdm is reachable for the helper-config path.
        RA.db = RA.db or { profile = {} }
        RA.db.profile = RA.db.profile or {}
    end)

    before_each(function()
        -- Tests opt into enabled by overriding cdm; default is no key (nil).
        if RA.db and RA.db.profile then RA.db.profile.cdm = nil end
    end)

    after_each(function()
        -- Clean up any subscriptions / CDV state between tests.
        pcall(function() EH:UnsubscribeAll("CDMHook") end)
        pcall(function() EH:UnsubscribeAll("test_observer") end)
        if _G.RotaAssistTest_UninstallCDV then
            _G.RotaAssistTest_UninstallCDV()
        end
        -- Reset module to a clean state by calling OnDisable.
        if CDM.OnDisable then CDM:OnDisable() end
    end)

    describe("module loading", function()
        it("registers correctly", function()
            assert.is_not_nil(CDM)
        end)

        it("creates the public RA.CDM namespace at OnInitialize", function()
            assert.is_table(RA.CDM)
            assert.is_function(RA.CDM.IsAvailable)
            assert.is_function(RA.CDM.IsActive)
            assert.is_function(RA.CDM.GetTrackedCooldowns)
            assert.is_function(RA.CDM.GetState)
            assert.is_function(RA.CDM.GetOverlayCooldowns)
        end)
    end)

    describe("public API", function()
        it("GetTrackedCooldowns returns a table even when disabled", function()
            assert.is_table(RA.CDM.GetTrackedCooldowns())
        end)

        it("IsActive returns false when module has not been enabled", function()
            assert.is_false(RA.CDM.IsActive())
        end)

        it("IsAvailable reflects EssentialCooldownViewer global presence", function()
            -- No CDV installed → not available
            assert.is_false(RA.CDM.IsAvailable())
            _G.RotaAssistTest_InstallCDV({ 12345 })
            assert.is_true(RA.CDM.IsAvailable())
            _G.RotaAssistTest_UninstallCDV()
            assert.is_false(RA.CDM.IsAvailable())
        end)

        it("GetState returns nil for an unknown spell", function()
            assert.is_nil(RA.CDM.GetState(99999))
        end)

        it("GetOverlayCooldowns returns a table sourced from CooldownOverlay", function()
            -- Seed CooldownOverlay with one entry via its public refresh path.
            CO:RefreshSpellCooldown(188499)  -- Blade Dance (mock returns ready)
            local overlay = RA.CDM.GetOverlayCooldowns()
            assert.is_table(overlay)
            assert.is_not_nil(overlay[188499])
            assert.is_boolean(overlay[188499].ready)
        end)
    end)

    describe("default-disabled lifecycle", function()
        it("does not activate when db.profile.cdm.enabled is missing/false", function()
            -- RA.db.profile is the busted mock { profile = { general = {} } } —
            -- which means cdm.enabled is nil (treated as false). OnEnable should be a no-op.
            CDM:OnEnable()
            assert.is_false(RA.CDM.IsActive())
            assert.is_false(CDM:IsHookedForTests())
        end)

        it("does not error when CDV is absent", function()
            RA.db.profile.cdm = { enabled = true }
            assert.has_no.errors(function() CDM:OnEnable() end)
            assert.is_false(CDM:IsHookedForTests())
        end)
    end)

    describe("hook attachment when enabled", function()
        before_each(function()
            RA.db.profile.cdm = { enabled = true,
                                  trackInterrupt = true,
                                  trackMajorCD = true }
        end)

        it("hooks Blizzard CDV children when present at OnEnable", function()
            _G.RotaAssistTest_InstallCDV({ 188499, 188501 })  -- two arbitrary IDs
            CDM:OnEnable()
            assert.is_true(CDM:IsHookedForTests())
            assert.is_true(RA.CDM.IsActive())
        end)

        it("fires ROTAASSIST_CDM_ALERT when a child's TriggerAlertEvent is invoked", function()
            _G.RotaAssistTest_InstallCDV({ 188499 })
            CDM:OnEnable()

            local received = {}
            EH:Subscribe("ROTAASSIST_CDM_ALERT", "test_observer",
                function(_, sid, evName)
                    received[#received + 1] = { spellID = sid, evName = evName }
                end)

            -- Now invoke the (now-hooked) TriggerAlertEvent on the mock child
            local child = _G.EssentialCooldownViewer._children[1]
            child:TriggerAlertEvent(Enum.CooldownViewerAlertEventType.OnCooldown)
            child:TriggerAlertEvent(Enum.CooldownViewerAlertEventType.Available)

            assert.equals(2, #received)
            assert.equals(188499, received[1].spellID)
            assert.equals("OnCooldown", received[1].evName)
            assert.equals("Available",  received[2].evName)
        end)

        it("normalises numeric event values when Enum.CooldownViewerAlertEventType is missing", function()
            -- Use the public test simulator so we don't need a real CDV frame for this.
            _G.RotaAssistTest_InstallCDV({})
            CDM:OnEnable()

            local saved = _G.Enum.CooldownViewerAlertEventType
            _G.Enum.CooldownViewerAlertEventType = nil

            local received = {}
            EH:Subscribe("ROTAASSIST_CDM_ALERT", "test_observer",
                function(_, sid, evName) received[#received + 1] = evName end)

            CDM:_TestSimulateAlert(11111, 0)  -- Available
            CDM:_TestSimulateAlert(11111, 1)  -- OnCooldown
            CDM:_TestSimulateAlert(11111, 99) -- Unknown fallback

            _G.Enum.CooldownViewerAlertEventType = saved

            assert.equals(3, #received)
            assert.equals("Available",  received[1])
            assert.equals("OnCooldown", received[2])
            assert.equals("Unknown",    received[3])
        end)

        it("updates GetState/GetTrackedCooldowns after alert fires", function()
            _G.RotaAssistTest_InstallCDV({ 188499 })
            CDM:OnEnable()

            local child = _G.EssentialCooldownViewer._children[1]
            child:TriggerAlertEvent(Enum.CooldownViewerAlertEventType.OnCooldown)

            local st = RA.CDM.GetState(188499)
            assert.is_table(st)
            assert.equals(188499, st.spellID)
            assert.is_false(st.ready)
            assert.equals("OnCooldown", st.lastEvent)

            local tracked = RA.CDM.GetTrackedCooldowns()
            assert.is_not_nil(tracked[188499])
            -- Mutating the returned copy must not affect internal state.
            tracked[188499].ready = true
            assert.is_false(RA.CDM.GetState(188499).ready)
        end)

        it("does not fire ROTAASSIST_CDM_ALERT spuriously on bare OnEnable", function()
            _G.RotaAssistTest_InstallCDV({ 188499, 188501 })
            local fires = 0
            EH:Subscribe("ROTAASSIST_CDM_ALERT", "test_observer",
                function() fires = fires + 1 end)
            CDM:OnEnable()
            -- Only ROTAASSIST_CDM_HOOKED is fired during enable; ALERT must
            -- only fire when a real Blizzard hook callback runs.
            assert.equals(0, fires)
        end)
    end)

    describe("OnDisable cleanup", function()
        it("clears active state and tracked cooldowns", function()
            RA.db.profile.cdm = { enabled = true }
            _G.RotaAssistTest_InstallCDV({ 188499 })
            CDM:OnEnable()
            CDM:_TestSimulateAlert(188499, Enum.CooldownViewerAlertEventType.OnCooldown)
            assert.is_not_nil(RA.CDM.GetState(188499))

            CDM:OnDisable()

            assert.is_false(RA.CDM.IsActive())
            local tracked = RA.CDM.GetTrackedCooldowns()
            local count = 0
            for _ in pairs(tracked) do count = count + 1 end
            assert.equals(0, count)
        end)
    end)

    describe("regression: D-002 single-source-of-truth", function()
        it("does not duplicate cooldown lists; reads from CooldownOverlay only", function()
            -- The bridge accessor must source data from the CooldownOverlay
            -- module rather than maintaining its own SpecEnhancements copy.
            -- Verify by mutating CooldownOverlay state and seeing it reflected.
            CO:RefreshSpellCooldown(210152)  -- Death Sweep
            local snap = RA.CDM.GetOverlayCooldowns()
            assert.is_not_nil(snap[210152])
            assert.equals(true, snap[210152].ready)
        end)
    end)
end)
