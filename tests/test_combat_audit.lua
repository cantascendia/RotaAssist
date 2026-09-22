-- test: bounded opt-in public traces, no hidden-state or DPS claims.
local helpers = require("tests.helpers")
describe("combat acceptance capture", function()
    local RA, ns, audit, events, now, queue, status, build, target, secret
    before_each(function()
        RA, ns = helpers.loadAddon(); RA.db = { profile = {} }
        now = 100; GetTime = function() return now end
        secret = {}; issecretvalue = function(value) return rawequal(value, secret) end
        queue = { main = { spellID = 100, source = "INDEPENDENT" } }
        status = { status = "ambiguous", missing = { "fury", "ready:100" }, policyInvariant = false }
        build = { generation = 1, specID = 577, heroID = 35, talentsComplete = true,
            talentKey = "577:1:2", equipmentKey = "1:123", playerName = "DO_NOT_RECORD" }
        target = { targetValid = true, nearbyEnemies = 3, unknownEnemies = 1, countComplete = false, GUID = "DO_NOT_RECORD" }
        RA.modules.SmartQueueManager = { GetFinalQueue = function() return queue end, GetIndependentStatus = function() return status end }
        RA.modules.CharacterState = { GetSnapshot = function() return build end }
        RA.modules.TargetContext = { GetSnapshot = function() return target end }
        helpers.loadAddonFile("addon/Core/EventHandler.lua", "RotaAssist", ns)
        helpers.loadAddonFile("addon/Engine/CombatAudit.lua", "RotaAssist", ns)
        events = RA:GetModule("EventHandler"); events:OnEnable()
        audit = RA:GetModule("CombatAudit"); audit:OnInitialize(); audit:OnEnable()
    end)
    after_each(function() audit:OnDisable() end)
    it("is off by default and copies only public allowlisted fields", function()
        events:Fire("ROTAASSIST_QUEUE_UPDATED"); assert.is_nil(RA.db.profile.combatAudit)
        audit:SetRecording(true)
        local r = RA.db.profile.combatAudit; local first = r.events[1]
        assert.equals(100, first.queueSpellID); assert.equals("fury", first.missing1)
        assert.equals(3, first.nearbyEnemies); assert.is_false(first.countComplete)
        assert.is_false(r.maximumDPSProven); assert.is_nil(first.GUID); assert.is_nil(first.playerName)
        queue.main.spellID = 200; build.talentKey = "new"
        assert.equals(100, first.queueSpellID); assert.equals("577:1:2", r.builds[1].talentKey)
    end)
    it("samples queue cadence but retains player casts and combat boundaries", function()
        audit:SetRecording(true); events:Fire("ROTAASSIST_QUEUE_UPDATED")
        local r = RA.db.profile.combatAudit; assert.equals(2, r.count)
        now = 100.1; events:Fire("ROTAASSIST_QUEUE_UPDATED"); assert.equals(2, r.count)
        events:Fire("ROTAASSIST_SPELLCAST_SUCCEEDED", "player", "opaque", 123)
        assert.equals("cast", r.events[3].kind); assert.equals(123, r.events[3].castSpellID)
        events:Fire("ROTAASSIST_SPELLCAST_SUCCEEDED", "party1", "opaque", 456); assert.equals(3, r.count)
        now = 100.5; events:Fire("ROTAASSIST_QUEUE_UPDATED"); assert.equals(4, r.count)
        events:Fire("PLAYER_REGEN_ENABLED"); assert.equals("combat_end", r.events[5].kind)
    end)
    it("does not serialize secret, invalid, or aliased module data", function()
        queue.main.spellID, queue.main.source = secret, secret
        status.policyInvariant, status.missing = secret, secret
        build.specID, build.talentKey = secret, secret
        target.nearbyEnemies = 0/0
        audit:SetRecording(true); local row = RA.db.profile.combatAudit.events[1]
        assert.is_nil(row.queueSpellID); assert.is_nil(row.source); assert.is_nil(row.policyInvariant)
        assert.is_nil(row.specID); assert.is_nil(row.missing1); assert.is_nil(row.nearbyEnemies)
        now = secret; events:Fire("ROTAASSIST_QUEUE_UPDATED"); assert.equals(1, RA.db.profile.combatAudit.count)
    end)
    it("property: retains exactly the newest bounded events and reuses rows", function()
        audit:SetRecording(true); local r = RA.db.profile.combatAudit; local first = r.events[1]
        for i = 1, 2500 do now = 100 + i; audit:Capture("cast", i) end
        assert.equals(1200, #r.events); assert.equals(1200, r.count); assert.equals(1301, r.dropped)
        assert.equals(first, r.events[1]); assert.equals(1, #r.builds)
        for offset = 0, 1199 do
            local row = r.events[(r.nextIndex - 1 + offset) % 1200 + 1]
            assert.equals(1302 + offset, row.sequence)
        end
    end)
    it("stops on disable or settings changes and never resumes automatically", function()
        audit:SetRecording(true); local r = RA.db.profile.combatAudit
        events:Fire("ROTAASSIST_SETTINGS_RESET"); assert.is_false(audit:IsRecording())
        events:Fire("ROTAASSIST_QUEUE_UPDATED"); assert.equals(1, r.count)
        audit:SetRecording(true); local current = RA.db.profile.combatAudit
        assert.not_equals(r, current); audit:OnDisable(); audit:OnEnable()
        events:Fire("ROTAASSIST_QUEUE_UPDATED"); assert.equals(1, current.count)
        assert.is_false(audit:IsRecording())
    end)
    it("caps build records without assigning a mismatched build", function()
        audit:SetRecording(true); local r = RA.db.profile.combatAudit
        for i = 2, 20 do build.generation = i; now = now + 1; audit:Capture("build_change") end
        assert.equals(16, #r.builds); assert.is_nil(r.events[20].buildIndex)
        assert.equals(20, r.events[20].buildGeneration)
    end)
end)
