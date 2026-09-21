-- test: additive generic target context and real queue filtering without APLs.
local h=require("tests.helpers")
describe("automatic runtime target context",function()
    local RA,ns,C,events,units,now,spells,rec,Q,secret,rangeCalls
    local function unit(id,near,far,combat)
        return {id=id,near=near,far=far,combat=combat,attack=true,dead=false}
    end
    before_each(function()
        RA,ns=h.loadAddon(); h.loadRegistry(ns)
        now=1; rangeCalls=0; rec=501; spells={[501]={},[502]={}}
        units={target=unit("A",false,true,false),nameplate1=unit("A",false,true,true),
            nameplate2=unit("B",true,true,true),nameplate3=unit("C",false,true,false)}
        secret={}; issecretvalue=function(v) return rawequal(v,secret) end
        GetTime=function() return now end
        UnitExists=function(u) return units[u]~=nil end
        UnitCanAttack=function(_,u) return units[u].attack end
        UnitIsDead=function(u) return units[u].dead end
        UnitAffectingCombat=function(u) return units[u].combat end
        UnitGUID=function(u) return units[u] and units[u].id end
        UnitIsUnit=function(a,b)
            local x,y=units[a],units[b]
            if x and x.id==secret then return secret end
            return x and y and x.id==y.id or false
        end
        IsPlayerSpell=function() return true end
        C_Spell.IsSpellInRange=function(id,u)
            rangeCalls=rangeCalls+1
            if id==501 then return units[u].near end
            return units[u].far
        end
        C_Spell.IsSpellHarmful=function() return true end
        C_Spell.IsSpellUsable=function() return true,false end
        RA.GetSpellCooldownSafe=function() return 0,true,0,0 end
        RA:RegisterModule("SpecDetector",{GetCurrentSpec=function() return {specID=63} end})
        RA:RegisterModule("SpellCatalog",{GetSnapshot=function() return {spells=spells,complete=true} end})
        RA:RegisterModule("AssistedCombatBridge",{GetRotationSpells=function() return {501,502} end,
            GetCurrentRecommendation=function() return rec and {spellID=rec} end})
        assert(h.loadAddonFile("addon/Core/EventHandler.lua","RotaAssist",ns))
        assert(h.loadAddonFile("addon/Engine/TargetContext.lua","RotaAssist",ns))
        events=RA:GetModule("EventHandler"); C=RA:GetModule("TargetContext")
        C:OnInitialize(); C:OnEnable()
    end)
    after_each(function() if Q then Q:OnDisable(); Q=nil end; C:OnDisable() end)
    it("samples ranges without Havoc configuration or a shipped APL",function()
        local s=C:GetSnapshot()
        assert.is_false(s.supported); assert.is_true(s.genericSupported)
        assert.is_false(s.spellRange[501]); assert.is_true(s.spellRange[502])
        assert.is_false(s.countComplete)
    end)
    it("keeps distinct spell ranges and counts only unique engaged living enemies",function()
        units.nameplate4=unit("B",true,true,true)
        units.nameplate5=unit("E",true,true,true); units.nameplate5.dead=true
        assert.equals(1,C:GetSpellTargets(501).min)
        assert.equals(2,C:GetSpellTargets(502).min)
        assert.is_false(C:GetSpellTargets(502).complete)
        assert.equals("spell_targetable_lower_bound",C:GetSpellTargets(502).source)
    end)
    it("caches within a sample and refreshes moving units and target switches",function()
        assert.equals(2,C:GetSpellTargets(502).min)
        local calls=rangeCalls; C:GetSpellTargets(502); assert.equals(calls,rangeCalls)
        units.nameplate2.far=false; now=now+0.16
        assert.equals(1,C:GetSpellTargets(502).min)
        units.target=unit("Z",false,false,false); events:Fire("PLAYER_TARGET_CHANGED")
        assert.equals(1,C:GetSpellTargets(502).min) -- previous target is still an engaged visible enemy
        assert.is_false(C:GetSpellRange(502))
    end)
    it("does not treat protected identities or ranges as extra confirmed enemies",function()
        units.nameplate2.id=secret
        units.target.far=secret
        assert.equals(0,C:GetSpellTargets(502).min)
        assert.is_true(C:GetSpellTargets(502).unknown>0)
        assert.is_nil(C:GetSpellTargets(secret))
        assert.is_nil(C:GetSpellRange(secret))
    end)
    it("samples an unlisted proc override on demand",function()
        assert.is_true(C:GetSpellRange(999)); assert.is_true(C:GetSnapshot().spellRange[999])
        units.target.far=false; events:Fire("ROTAASSIST_CHARACTER_CHANGED")
        assert.is_false(C:GetSpellRange(999))
    end)
    it("filters the real primary queue for an unsupported spec without personal setup",function()
        RA.L=setmetatable({},{__index=function(_,k) return k end})
        RA.db={profile={display={showOutOfCombat=true},smartQueue={blizzardWeight=1}}}
        assert(h.loadAddonFile("addon/Engine/SmartQueueManager.lua","RotaAssist",ns))
        Q=RA:GetModule("SmartQueueManager"); Q:OnInitialize(); Q:OnEnable()
        Q._AssembleQueue(); assert.is_nil(Q:GetFinalQueue().main)
        rec=502; Q._AssembleQueue(); assert.equals(502,Q:GetFinalQueue().main.spellID)
        assert.equals(2,Q:GetFinalQueue().main.targetableEnemiesMin)
        rec=999; Q._AssembleQueue(); assert.equals(999,Q:GetFinalQueue().main.spellID)
        units.target.far=false; events:Fire("PLAYER_TARGET_CHANGED")
        Q._AssembleQueue(); assert.is_nil(Q:GetFinalQueue().main)
    end)
    it("supports arbitrary spec identifiers instead of a per-player preset",function()
        for _,id in ipairs({63,71,253,259,577,581,1480}) do
            RA:GetModule("SpecDetector").GetCurrentSpec=function() return {specID=id} end
            events:Fire("ROTAASSIST_SPEC_CHANGED")
            assert.is_true(C:GetSpellRange(502))
        end
    end)
    it("caps on-demand tracked spell buffers",function()
        for id=1000,1400 do C:GetSpellTargets(id) end
        assert.is_nil(C:GetSpellTargets(1401))
        now=now+0.16; assert.is_true(C:GetSnapshot().trackedSpells<=256)
    end)
end)
