-- test: additive burst-state behavior and real observer integration.
local h=require("tests.helpers")
describe("havoc surge tracking",function()
    local RA,ns,T,events,build,ranks,now,meta,remaining,secret
    local ann="action.annihilation.demonsurge_available"
    local sweep="action.death_sweep.demonsurge_available"
    local aura="action.immolation_aura.demonsurge_available"
    local function cast(id,guid,unit) events:Fire("ROTAASSIST_SPELLCAST_SUCCEEDED",unit or "player",guid or tostring(now)..":"..id,id) end
    local function facts() local result={}; T:Populate(result); return result end
    before_each(function()
        RA,ns=h.loadAddon(); h.loadRegistry(ns)
        now=10; meta=true; remaining=20; secret={}
        GetTime=function() return now end
        issecretvalue=function(v) return rawequal(v,secret) end
        ranks={[452402]=1,[213410]=1}
        build={talentsComplete=true,specID=577,generation=1,talentKey="fel"}
        RA:RegisterModule("CharacterState",{GetSnapshot=function() return build end,GetTalentRank=function(_,id) return ranks[id] end})
        RA:RegisterModule("PublicAuraFacts",{ReadPlayer=function() return meta,remaining end})
        assert(h.loadAddonFile("addon/Core/EventHandler.lua","RotaAssist",ns))
        assert(h.loadAddonFile("addon/Engine/HavocSurgeTracker.lua","RotaAssist",ns))
        events=RA:GetModule("EventHandler"); T=RA:GetModule("HavocSurgeTracker"); T:OnInitialize(); T:OnEnable()
    end)
    after_each(function() T:OnDisable() end)
    it("starts unknown despite an active form and arms all three on manual Meta",function()
        assert.is_nil(facts()[ann]); cast(191427)
        local f=facts(); assert.equals(1,f[ann]); assert.equals(1,f[sweep]); assert.equals(1,f[aura])
    end)
    it("consumes only the cast action and ignores duplicate rearm events",function()
        cast(191427,"meta"); cast(201427,"ann")
        cast(191427,"meta"); local f=facts()
        assert.equals(0,f[ann]); assert.equals(1,f[sweep]); assert.equals(1,f[aura])
        cast(210152); assert.equals(0,facts()[sweep]); cast(258920); assert.equals(0,facts()[aura])
    end)
    it("rearms spenders inside Meta with Eye Beam but not consumed Aura",function()
        cast(191427); cast(201427); cast(210152); cast(258920)
        now=12; cast(198013)
        local f=facts(); assert.equals(1,f[ann]); assert.equals(1,f[sweep]); assert.equals(0,f[aura])
        cast(162794); cast(188499)
        assert.equals(0,facts()[ann]); assert.equals(0,facts()[sweep])
    end)
    it("accepts Abyssal Gaze as the same spender-refresh trigger",function()
        cast(452497); assert.equals(1,facts()[ann]); assert.equals(1,facts()[sweep]); assert.is_nil(facts()[aura])
    end)
    it("uses conservative expiry and extends still-valid horizons",function()
        cast(191427); now=29; cast(198013); now=34.9
        assert.equals(1,facts()[aura]); now=35
        assert.is_nil(facts()[aura]); assert.is_nil(facts()[ann])
        cast(198013,"eye2"); now=40; assert.is_nil(facts()[sweep])
    end)
    it("does not resurrect an expired Aura flag with Eye Beam",function()
        cast(191427); now=31; cast(198013)
        assert.is_nil(facts()[aura]); assert.equals(1,facts()[ann])
    end)
    it("requires selected talents and a complete Havoc build",function()
        ranks[213410]=0; cast(198013); assert.is_nil(facts()[ann])
        ranks[213410]=nil; cast(198013,"eye_unknown"); assert.is_nil(facts()[ann])
        ranks[452402]=0; cast(191427); assert.equals(0,facts()[ann])
        ranks[452402]=nil; assert.is_nil(facts()[ann])
        ranks[452402]=1; build.talentsComplete=false; cast(191427,"bad"); assert.is_nil(facts()[ann])
        build.talentsComplete=true; build.specID=581; assert.is_nil(facts()[ann])
    end)
    it("unknown form never exposes tracked flags and proven absence clears them",function()
        cast(191427); meta=nil; assert.is_nil(facts()[ann])
        meta=true; assert.equals(1,facts()[ann])
        meta=false; assert.equals(0,facts()[ann]); meta=true; assert.is_nil(facts()[ann])
    end)
    it("ignores other units and clears restricted player events",function()
        cast(191427,"other","party1"); assert.is_nil(facts()[ann])
        cast(191427,"own"); cast(secret,"restricted"); assert.is_nil(facts()[ann])
        cast(191427,"next"); cast(201427,secret); assert.is_nil(facts()[ann])
        cast(191427,"again"); cast(201427,"badunit",secret); assert.is_nil(facts()[ann])
    end)
    it("invalidates on death build and world changes but keeps target changes",function()
        for _,event in ipairs({"PLAYER_DEAD","PLAYER_ENTERING_WORLD","ROTAASSIST_CHARACTER_CHANGED","ROTAASSIST_SPEC_CHANGED"}) do
            cast(191427,event); events:Fire(event); assert.is_nil(facts()[ann])
        end
        cast(191427,"target"); events:Fire("PLAYER_TARGET_CHANGED"); assert.equals(1,facts()[ann])
        build.generation=2; assert.is_nil(facts()[ann])
    end)
    it("clears history on time reversal and disable",function()
        cast(191427); now=9; assert.is_nil(facts()[ann])
        cast(191427,"again"); T:OnDisable(); cast(191427,"disabled"); assert.is_nil(facts()[ann])
    end)
    it("does not carry charges across a cancelled or unreadable aura transition",function()
        cast(191427,"first"); meta=false; events:Fire("UNIT_AURA","player")
        meta=true; cast(198013,"eye"); assert.is_nil(facts()[aura])
        cast(191427,"second"); meta=nil; events:Fire("UNIT_AURA","player")
        meta=true; assert.is_nil(facts()[ann])
        cast(191427,"third"); events:Fire("UNIT_AURA","target"); assert.equals(1,facts()[ann])
    end)
    it("supplies tracked evidence to the real independent observer",function()
        RA:RegisterModule("SpecDetector",{GetCurrentSpec=function() return {specID=577} end})
        RA:RegisterModule("APLEngine",{GetProfileName=function() return "fel_scarred" end})
        assert(h.loadAddonFile("addon/Engine/IndependentDecision.lua","RotaAssist",ns))
        assert(h.loadAddonFile("addon/Engine/IndependentObserver.lua","RotaAssist",ns))
        RA.IndependentPolicy={schema="rotaassist.independent-policy.v1",specID=577,heroProfile="fel_scarred",rules={
            {spellID=210152,conditions={{sweep,">",0}}},{spellID=201427,conditions={}}}}
        IsPlayerSpell=function() return true end; C_Spell.IsSpellUsable=function() return true end
        RA.GetSpellCooldownSafe=function() return 0 end
        local s={targetValid=true,spellRange={[210152]=true,[201427]=true}}
        local observer=RA:GetModule("IndependentObserver")
        assert.equals("ambiguous",observer:Observe(s).status)
        cast(191427); local r=observer:Observe(s)
        assert.equals(210152,r.spellID); assert.equals("cast_model",r.surgeSource); assert.equals(3,r.surgeTrackedFacts)
        cast(210152); assert.equals(201427,observer:Observe(s).spellID)
        assert.is_false(r.performanceQualified)
    end)
end)
