local h=require("tests.helpers")
local M={}
function M.create()
    local RA,ns=h.loadAddon(); h.loadRegistry(ns)
    local f={RA=RA,ns=ns,now=101.2,window="400",flag=true,start=100,duration=1.5,
        gcdStart=100,gcdDuration=1.5,enabled=true,secret={},charge=nil}
    GetTime=function() return f.now end
    GetCVar=function() return f.window end
    issecretvalue=function(v) return rawequal(v,f.secret) end
    IsPlayerSpell=function() return true end
    C_Spell.IsSpellUsable=function() return true end
    C_Spell.GetSpellCharges=function() return f.charge end
    C_Spell.GetSpellCooldown=function(id)
        if id==61304 then return {startTime=f.gcdStart,duration=f.gcdDuration,isEnabled=true} end
        return {startTime=f.start,duration=f.duration,isEnabled=f.enabled,isOnGCD=f.flag}
    end
    RA.IndependentPolicy={schema="rotaassist.independent-policy.v1",specID=577,heroProfile="fel_scarred",
        rules={{spellID=258920,action="immolation_aura",conditions={}}}}
    RA:RegisterModule("SpecDetector",{GetCurrentSpec=function() return {specID=577} end})
    RA:RegisterModule("APLEngine",{GetProfileName=function() return "fel_scarred" end})
    for _,file in ipairs({"Core/EventHandler","Engine/ActionTiming","Engine/IndependentDecision","Engine/IndependentObserver"}) do
        assert(h.loadAddonFile("addon/"..file..".lua","RotaAssist",ns))
    end
    f.events=RA:GetModule("EventHandler"); f.timing=RA:GetModule("ActionTiming")
    f.observer=RA:GetModule("IndependentObserver")
    f.timing:OnInitialize(); f.timing:OnEnable()
    f.state={targetValid=true,spellRange={[258920]=true},targetCount=3,targetCountKnown=false}
    function f:capture() self.events:Fire("SPELL_UPDATE_COOLDOWN") end
    return f
end
return M
