-- test: additive target-context contract and guarded observation scenarios.
local helpers = require("tests.helpers")

describe("public target combat context", function()
    local RA, ns, context, events, units, now, aura, saved
    local secret = setmetatable({}, { __lt = function() error("secret comparison") end,
        __le = function() error("secret comparison") end, __tostring = function() error("secret formatting") end })
    local function unit(guid, inRange, combat)
        return { guid = guid, range = inRange, combat = combat, dead = false, attack = true }
    end
    before_each(function()
        RA, ns = helpers.loadAddon()
        helpers.loadRegistry(ns)
        saved = {}
        for _, name in ipairs({ "GetTime", "GetCVar", "UnitExists", "UnitCanAttack", "UnitIsDead",
            "UnitAffectingCombat", "UnitGUID", "UnitIsUnit", "IsPlayerSpell", "issecretvalue",
            "C_Spell", "C_UnitAuras", "C_AssistedCombat" }) do saved[name] = { _G[name] } end
        now, aura = 20, {}
        units = { target = unit("A", true, false) }
        _G.GetTime = function() return now end
        _G.GetCVar = function() return "0.1" end
        _G.UnitExists = function(u) return units[u] ~= nil end
        _G.UnitCanAttack = function(_, u) return units[u].attack end
        _G.UnitIsDead = function(u) return units[u].dead end
        _G.UnitAffectingCombat = function(u) return units[u].combat end
        _G.UnitGUID = function(u) return units[u] and units[u].guid end
        _G.UnitIsUnit = function(a, b)
            if units[a].guid == secret or (units[b] and units[b].guid == secret) then return secret end
            return units[a].guid == (units[b] and units[b].guid)
        end
        _G.IsPlayerSpell = function() return true end
        _G.issecretvalue = function(v) return rawequal(v, secret) end
        local spell = {}
        for k, v in pairs(saved.C_Spell[1]) do spell[k] = v end
        spell.IsSpellInRange = function(_, u) return units[u].range end
        _G.C_Spell = spell
        _G.C_UnitAuras = { GetUnitAuraBySpellID = function(u, id) return aura[u .. id] end }
        RA:RegisterModule("SpecDetector", { GetCurrentSpec = function() return { specID = 577 } end })
        RA.APLData = { [577] = { profiles = { default = { singleTarget = { { spellID = 162794 } } } } } }
        assert(helpers.loadAddonFile("addon/Core/EventHandler.lua", "RotaAssist", ns))
        events = RA:GetModule("EventHandler")
        assert(helpers.loadAddonFile("addon/Engine/TargetContext.lua", "RotaAssist", ns))
        context = RA:GetModule("TargetContext")
        context:OnInitialize()
        context:OnEnable()
    end)
    after_each(function()
        context:OnDisable()
        for name, value in pairs(saved) do _G[name] = value[1] end
    end)

    it("counts target once and only engaged living hostile in-range extras", function()
        units.nameplate1 = unit("A", true, true)
        units.nameplate2 = unit("B", true, true)
        units.nameplate3 = unit("C", false, true)
        units.nameplate4 = unit("D", true, false)
        units.nameplate5 = unit("E", true, true); units.nameplate5.dead = true
        units.nameplate6 = unit("F", true, true); units.nameplate6.attack = false
        local s = context:GetSnapshot()
        assert.equals(2, s.nearbyEnemies)
        assert.is_false(s.countComplete)
        assert.equals("public_melee_range_lower_bound", s.countSource)
    end)

    it("does not count duplicate GUIDs or identity-restricted target aliases", function()
        units.nameplate1 = unit("B", true, true)
        units.nameplate2 = unit("B", true, true)
        units.nameplate3 = unit(secret, true, true)
        local s = context:GetSnapshot()
        assert.equals(2, s.nearbyEnemies)
        assert.equals(1, s.unknownEnemies)
    end)

    it("keeps secret range, hostility and aura fields unknown without comparisons", function()
        units.target.range = secret
        units.nameplate1 = unit("B", true, true); units.nameplate1.attack = secret
        aura.target320338 = { spellId = 320338, expirationTime = secret, sourceUnit = "player" }
        local s = context:GetSnapshot()
        assert.equals(0, s.nearbyEnemies)
        assert.equals(2, s.unknownEnemies)
        assert.is_nil(s.spellRange[162794])
        assert.is_true(s.windowUnknown.essence_break)
    end)

    it("nil aura does not prove absence; readable target aura has seconds", function()
        assert.is_true(context:GetSnapshot().windowUnknown.essence_break)
        aura.target320338 = { spellId = 320338, expirationTime = now + 2, sourceUnit = "player" }
        aura.player162264 = { spellId = 162264, expirationTime = now + 5 }
        context:Invalidate(false)
        local s = context:GetSnapshot()
        assert.equals(2, s.windowRemains.essence_break)
        assert.is_true(s.windows.essence_break)
        assert.is_true(s.inMeta)
        assert.equals(5, s.metaRemains)
    end)

    it("target swap immediately clears old target observation and increments generation", function()
        aura.target320338 = { spellId = 320338, expirationTime = now + 3, sourceUnit = "player" }
        local old = context:GetSnapshot().generation
        units.target = unit("Z", true, false)
        aura.target320338 = nil
        events:Fire("PLAYER_TARGET_CHANGED")
        local s = context:GetSnapshot()
        assert.equals(old + 1, s.generation)
        assert.is_nil(s.windows.essence_break)
        assert.is_true(s.windowUnknown.essence_break)
    end)

    it("updates range after cadence and does not retain vanished enemies", function()
        units.nameplate1 = unit("B", true, true)
        assert.equals(2, context:GetSnapshot().nearbyEnemies)
        units.nameplate1.range = false
        now = now + 0.16
        assert.equals(1, context:GetSnapshot().nearbyEnemies)
        units.target.dead = true
        now = now + 0.16
        assert.is_false(context:GetSnapshot().targetValid)
    end)

    it("does not attribute another player's or secret-source debuff to this player", function()
        units.party1 = unit("another-player", true, true)
        units.player = unit("me", true, true)
        for _, source in ipairs({ "party1", secret }) do
            aura.target320338 = { spellId = 320338, expirationTime = now + 3, sourceUnit = source }
            context:Invalidate(false)
            assert.is_true(context:GetSnapshot().windowUnknown.essence_break)
            assert.is_nil(context:GetSnapshot().windows.essence_break)
        end
    end)

    it("API failure cannot become a range-confirmed enemy", function()
        _G.C_Spell.IsSpellInRange = function() error("restricted") end
        local s = context:GetSnapshot()
        assert.equals(0, s.nearbyEnemies)
        assert.equals(1, s.unknownEnemies)
    end)

    it("unlearned probe does not manufacture a melee count", function()
        _G.IsPlayerSpell = function() return false end
        assert.equals(0, context:GetSnapshot().nearbyEnemies)
        assert.is_nil(context:GetSnapshot().probeSpellID)
    end)

    it("talent refresh resolves the learned override and samples its target range", function()
        RA.ResolveSpellOverride = function(_, id) if id == 162794 then return 201427 end; return id end
        _G.IsPlayerSpell = function(id) return id == 201427 end
        events:Fire("TRAIT_CONFIG_UPDATED")
        local s = context:GetSnapshot()
        assert.equals(201427, s.probeSpellID)
        assert.equals(1, s.nearbyEnemies)
        assert.is_true(s.spellRange[201427])
    end)

    it("disabled module removes its events and re-enable subscribes once", function()
        local generation = context:GetSnapshot().generation
        context:OnDisable()
        events:Fire("PLAYER_TARGET_CHANGED")
        assert.equals(generation, context:GetSnapshot().generation)
        context:OnEnable()
        generation = context:GetSnapshot().generation
        events:Fire("PLAYER_TARGET_CHANGED")
        assert.equals(generation + 1, context:GetSnapshot().generation)
    end)

    it("range count is invariant to distant and idle extras", function()
        -- Bounded property grid: only engaged, in-range extras change the lower bound.
        for n = 0, 15 do
            for i = 1, 39 do units["nameplate" .. i] = nil end
            for i = 1, n do units["nameplate" .. i] = unit("B" .. i, true, true) end
            units.nameplate39 = unit("far", false, true)
            units.nameplate40 = unit("idle", true, false)
            context:Invalidate(false)
            assert.equals(n + 1, context:GetSnapshot().nearbyEnemies)
        end
    end)

    it("queue and bridge cannot reuse the previous target recommendation", function()
        local spell = 162794
        _G.C_AssistedCombat = {
            IsAvailable = function() return true end,
            GetNextCastSpell = function() return spell end,
            GetRotationSpells = function() return { 162794, 232893 } end,
        }
        RA.db = { profile = { display = { showOutOfCombat = true } } }
        RA.WhitelistSpells = { [162794] = {}, [232893] = {} }
        RA.SpecEnhancements = {}
        local captured
        RA:RegisterModule("APLEngine", {
            HasAPL = function() return true end,
            PredictNext = function(_, _, s) captured = s; return {} end,
            IsMetaActive = function() return false end,
            GetCurrentAPL = function() return { rules = {} } end,
        })
        assert(helpers.loadAddonFile("addon/Engine/AssistedCombatBridge.lua", "RotaAssist", ns))
        local bridge = RA:GetModule("AssistedCombatBridge")
        bridge:OnInitialize(); bridge:OnEnable()
        assert(helpers.loadAddonFile("addon/Engine/SmartQueueManager.lua", "RotaAssist", ns))
        local queue = RA:GetModule("SmartQueueManager")
        queue:OnInitialize(); queue:OnEnable()
        units.nameplate1 = unit("far", false, true)
        queue._AssembleQueue()
        assert.equals(162794, queue:GetFinalQueue().main.spellID)
        assert.equals(1, captured.targetCount)
        assert.is_false(captured.targetCountKnown)
        assert.is_true(captured.windowUnknown.essence_break)
        -- Unknown validity preserves the official head but cannot run local APL.
        captured = nil
        units.target.attack = secret
        context:Invalidate(false)
        queue._AssembleQueue()
        assert.equals(162794, queue:GetFinalQueue().main.spellID)
        assert.is_nil(captured)
        units.target.attack = true
        spell = nil
        events:Fire("PLAYER_TARGET_CHANGED")
        assert.is_nil(queue:GetFinalQueue().main)
        queue._AssembleQueue()
        assert.is_nil(queue:GetFinalQueue().main)
        spell = 232893
        queue._AssembleQueue()
        assert.equals(232893, queue:GetFinalQueue().main.spellID)
        units.target.dead = true
        context:Invalidate(false)
        queue._AssembleQueue()
        assert.is_nil(queue:GetFinalQueue().main)
        queue:OnDisable(); bridge:OnDisable()
    end)

    it("actual APL switches lists only when enough observed enemies are in range", function()
        assert(helpers.loadAddonFile("addon/Engine/APLEngine.lua", "RotaAssist", ns))
        local apl = RA:GetModule("APLEngine")
        RA.APLData[577] = { profiles = { default = {
            singleTarget = { { spellID = 162794, condition = "always" } },
            aoe = { { spellID = 232893, condition = "always" } },
        } } }
        RA.WhitelistSpells = {}
        RA.SpecEnhancements = {}
        apl:SetAPL(577, RA.APLData[577], 12)
        units.nameplate1 = unit("B", true, true)
        units.nameplate2 = unit("C", false, true)
        events:Fire("TRAIT_CONFIG_UPDATED")
        local function predict()
            context:Invalidate(false)
            local s = context:GetSnapshot()
            return apl:PredictNext(nil, { targetCount = s.nearbyEnemies,
                targetCountKnown = s.countComplete, spellRange = s.spellRange,
                targetValid = s.targetValid, combatDuration = 12 }, 1)[1].spellID
        end
        assert.equals(162794, predict())
        units.nameplate2.range = true
        assert.equals(232893, predict())
        units.nameplate2.range = false
        assert.equals(162794, predict())
    end)
end)
