-- Replay semantic SimC trace events through the actual addon tracker.
local h=require("tests.helpers")
local RA,ns=h.loadAddon(); h.loadRegistry(ns)
local rows=assert(loadfile(assert(arg[1])))()
local now,meta=0,false
GetTime=function() return now end
RA:RegisterModule("CharacterState",{
    GetSnapshot=function() return {talentsComplete=true,specID=577,generation=1,talentKey="trace"} end,
    GetTalentRank=function() return 1 end})
RA:RegisterModule("PublicAuraFacts",{ReadPlayer=function() return meta end})
assert(h.loadAddonFile("addon/Engine/HavocSurgeTracker.lua","RotaAssist",ns))
local tracker=RA:GetModule("HavocSurgeTracker"); tracker:OnInitialize(); tracker:OnEnable()
local checked,unknown,modelChecked,byFlag=0,0,0,{0,0,0}
local facts={}
for index,row in ipairs(rows) do
    now=row.time; meta=row.meta
    for n,id in ipairs(row.casts) do tracker:OnCast("player",index..":"..n,id) end
    local _,source=tracker:Populate(facts)
    for i,key in ipairs(RA.Registry.HAVOC_SURGE.facts) do
        if facts[key]~=nil then
            assert(facts[key]==row.expected[i],string.format("time %.3f %s: tracker=%s reference=%s",now,key,tostring(facts[key]),tostring(row.expected[i])))
            checked=checked+1; byFlag[i]=byFlag[i]+1
            if source=="cast_model" then modelChecked=modelChecked+1 end
        else unknown=unknown+1 end
    end
end
assert(checked>0 and byFlag[1]>0 and byFlag[2]>0 and byFlag[3]>0,"empty replay evidence")
io.write(string.format("checked=%d unknown=%d samples=%d model=%d public=%d\n",checked,unknown,#rows,modelChecked,checked-modelChecked))
