-- test: add-only regressions for event-proven next-action timing.
local fixture=require("tests.action_timing_fixture")
describe("public action timing",function()
    local f
    before_each(function() f=fixture.create() end)
    it("requires an actual cooldown event before allowing a queued GCD action",function()
        assert.is_nil(f.timing:GetDelay(258920))
        assert.equals("wait",f.observer:Observe(f.state).status)
        f:capture()
        local r=f.observer:Observe(f.state)
        assert.equals(258920,r.spellID); assert.is_true(math.abs(r.planningDelay-.3)<.0001)
        assert.equals("public_gcd_queue_window",r.timingSource)
    end)
    it("does not reinterpret an equally short real cooldown as GCD",function()
        f.flag=false; f:capture(); assert.is_nil(f.timing:GetDelay(258920))
        assert.equals("wait",f.observer:Observe(f.state).status)
    end)
    it("requires identical public spell and GCD clocks",function()
        f.start=99.9; f:capture(); assert.is_nil(f.timing:GetDelay(258920))
        f.start=100; f.duration=1.4; f:capture(); assert.is_nil(f.timing:GetDelay(258920))
        f.duration=f.secret; f:capture(); assert.is_nil(f.timing:GetDelay(258920))
        f.duration=1.5; f.gcdStart=f.secret; f:capture(); assert.is_nil(f.timing:GetDelay(258920))
    end)
    it("honors the configured queue window, cap, and GCD expiry",function()
        f:capture(); f.window="100"; assert.is_nil(f.timing:GetDelay(258920))
        f.window="1000"; f.now=100.9; assert.is_nil(f.timing:GetDelay(258920))
        f.now=101.2; assert.is_true(f.timing:GetDelay(258920)>0)
        f.now=101.5; assert.is_nil(f.timing:GetDelay(258920))
        f.now=101.2; f.window=f.secret; assert.is_nil(f.timing:GetDelay(258920))
    end)
    it("rejects missing or restricted flags and on-hold cooldowns",function()
        f.flag=nil; f:capture(); assert.is_nil(f.timing:GetDelay(258920))
        f.flag=f.secret; f:capture(); assert.is_nil(f.timing:GetDelay(258920))
        f.flag=true; f.enabled=false; f:capture(); assert.is_nil(f.timing:GetDelay(258920))
    end)
    it("requires a public available charge for charge spells",function()
        f.charge={maxCharges=2,currentCharges=0,cooldownStartTime=90,cooldownDuration=20}
        f:capture(); assert.is_nil(f.timing:GetDelay(258920))
        f.charge.currentCharges=f.secret; f:capture(); assert.is_nil(f.timing:GetDelay(258920))
        f.charge.currentCharges=1; f:capture(); assert.is_true(f.timing:GetDelay(258920)>0)
        f.charge.currentCharges=0; assert.is_nil(f.timing:GetDelay(258920))
    end)
    it("does not hide unknown charges behind a publicly readable GCD clock",function()
        -- The legacy safe timer can fall back to GCD when recharge fields are
        -- restricted. A timer is not proof of a spendable charge.
        f.charge={maxCharges=2,currentCharges=f.secret,cooldownStartTime=f.secret,cooldownDuration=f.secret}
        f:capture(); assert.is_nil(f.timing:GetDelay(258920))
        f.charge={maxCharges=1,currentCharges=0}; f:capture()
        assert.is_nil(f.timing:GetDelay(258920))
    end)
    it("invalidates on player casts, charges, build, world and disable",function()
        for _,event in ipairs({"ROTAASSIST_SPELLCAST_SUCCEEDED","UNIT_SPELLCAST_START",
            "SPELL_UPDATE_CHARGES","ROTAASSIST_CHARACTER_CHANGED","PLAYER_ENTERING_WORLD"}) do
            f:capture(); assert.is_true(f.timing:GetDelay(258920)>0)
            f.events:Fire(event,"player","cast-1",258920)
            assert.is_nil(f.timing:GetDelay(258920))
        end
        f:capture(); f.timing:OnDisable(); assert.is_nil(f.timing:GetDelay(258920))
    end)
    it("revalidates changed clocks and replaces prior true evidence with false",function()
        f:capture(); f.start=100.1; assert.is_nil(f.timing:GetDelay(258920))
        f.start=100; f:capture(); f.flag=false; f:capture(); assert.is_nil(f.timing:GetDelay(258920))
    end)
    it("projects expiring auras and never extends an unbounded positive aura",function()
        f.RA.IndependentPolicy.rules[1].conditions={{"buff.metamorphosis.up",">",0}}
        f.state.inMetaKnown=true; f.state.inMeta=true
        f:capture(); assert.equals("ambiguous",f.observer:Observe(f.state).status)
        f.state.metaRemains=.1; assert.equals("wait",f.observer:Observe(f.state).status)
        f.state.metaRemains=2; assert.equals(258920,f.observer:Observe(f.state).spellID)
    end)
    it("does not let projected timing override current range or resource failures",function()
        f:capture(); f.state.spellRange[258920]=false
        assert.equals("wait",f.observer:Observe(f.state).status)
        f.state.spellRange[258920]=true; C_Spell.IsSpellUsable=function() return false end
        assert.equals("wait",f.observer:Observe(f.state).status)
    end)
    it("does not use another spell's targeted update as fresh GCD evidence",function()
        f.events:Fire("SPELL_UPDATE_COOLDOWN",162794)
        assert.is_nil(f.timing:GetDelay(258920))
        f.events:Fire("SPELL_UPDATE_COOLDOWN",258920)
        assert.is_true(f.timing:GetDelay(258920)>0)
        f.events:Fire("SPELL_UPDATE_COOLDOWN",f.secret)
        assert.is_nil(f.timing:GetDelay(258920))
    end)
    it("reevaluates changing enemy populations within the same GCD",function()
        f.RA.IndependentPolicy.rules={{spellID=258920,conditions={{"active_enemies",">=",3}}},
            {spellID=162794,conditions={}}}
        f.state.spellRange[162794]=true; f:capture()
        assert.equals(258920,f.observer:Observe(f.state).spellID)
        f.state.targetCount=1; assert.equals("ambiguous",f.observer:Observe(f.state).status)
        f.state.targetCountKnown=true; assert.equals(162794,f.observer:Observe(f.state).spellID)
        f.state.targetValid=false; assert.is_nil(f.observer:Observe(f.state).spellID)
    end)
    it("carries the queued decision through the actual main slot without native input",function()
        local h=require("tests.helpers")
        local RA=f.RA
        local apl=RA:GetModule("APLEngine")
        apl.HasAPL=function() return true end; apl.IsMetaActive=function() return false end
        apl.GetCurrentAPL=function() return nil end; apl.PredictNext=function() return {} end
        RA:RegisterModule("AssistedCombatBridge",{GetCurrentRecommendation=function() return nil end,
            GetRotationSpells=function() return {258920} end})
        RA:RegisterModule("TargetContext",{IsActive=function() return true end,GetSnapshot=function()
            return {supported=true,targetValid=f.state.targetValid,nearbyEnemies=3,countComplete=false,spellRange=f.state.spellRange,
                windows={},windowUnknown={essence_break=true},windowRemains={}}
            end,GetActionRange=function() return true end})
        RA.db={profile={display={showOutOfCombat=true},smartQueue={independentExperimental=true,
            blizzardWeight=1,aplWeight=.6,aiWeight=.4,cdWeight=.5,defWeight=.8}}}
        RA.SpecEnhancements={[577]={resource={powerType=17}}}
        UnitChannelInfo=function() return nil end
        assert(h.loadAddonFile("addon/Engine/SmartQueueManager.lua","RotaAssist",f.ns))
        local q=RA:GetModule("SmartQueueManager"); q:OnInitialize(); q:OnEnable()
        f:capture(); q._AssembleQueue()
        assert.equals(258920,q:GetFinalQueue().main.spellID)
        assert.equals("INDEPENDENT",q:GetFinalQueue().main.source)
        f.state.targetValid=false; f.events:Fire("ROTAASSIST_TARGET_CONTEXT_CHANGED"); q._AssembleQueue()
        assert.is_nil(q:GetFinalQueue().main); q:OnDisable()
    end)
    it("checks modeled surge expiry without erasing knowledge still valid now",function()
        local h=require("tests.helpers")
        f.RA:RegisterModule("CharacterState",{GetSnapshot=function()
            return {talentsComplete=true,specID=577,generation=1,talentKey="fel"} end,
            GetTalentRank=function() return 1 end})
        local remains=10
        f.RA:RegisterModule("PublicAuraFacts",{ReadPlayer=function() return true,remains end})
        assert(h.loadAddonFile("addon/Engine/HavocSurgeTracker.lua","RotaAssist",f.ns))
        local t=f.RA:GetModule("HavocSurgeTracker"); t:OnEnable()
        t:OnCast("player","meta-1",191427); f.now=f.now+19.9
        local facts={}; local key="action.annihilation.demonsurge_available"
        t:Populate(facts,.3); assert.is_nil(facts[key])
        t:Populate(facts); assert.equals(1,facts[key])
        t:OnCast("player","meta-2",191427); remains=.1
        t:Populate(facts,.3); assert.is_nil(facts[key])
        remains=10; t:Populate(facts,.3); assert.equals(1,facts[key])
        t:Populate(facts,f.secret); assert.is_nil(facts[key]); t:OnDisable()
    end)
end)
