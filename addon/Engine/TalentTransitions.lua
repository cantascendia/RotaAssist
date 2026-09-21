-- Selected talents change forward transitions, not only profile labels.
-- 已选天赋影响施法后的状态；无法读取的天赋不会被视为已选或未选。
local _, NS = ...
local RA = NS.RA
local Transitions = {}
RA:RegisterModule("TalentTransitions", Transitions)
local function number(value)
    if issecretvalue and issecretvalue(value) then return nil end
    if type(value)=="number" and value==value and math.abs(value)<math.huge then return value end
end
local function rank(character, specID, talentID)
    local build=character:GetSnapshot()
    if not build.talentsComplete or build.specID~=specID then return nil end
    return number(character:GetTalentRank(talentID))
end
function Transitions:GetDuration(specID, spellID)
    local data=RA.Registry.HAVOC_TRANSITIONS
    local character=RA:GetModule("CharacterState")
    if not data or specID~=data.specID or not character
       or (spellID~=data.eyeBeam and spellID~=data.metamorphosis) then return false end
    if spellID==data.metamorphosis then return true,data.metamorphosisDuration,false end
    local selected=rank(character,specID,data.demonicTalent)
    if selected==nil then return true,nil,true end
    return true,selected>0 and data.demonicMinimum or 0,true
end
function Transitions:Apply(state, specID, spellID)
    local handled,duration,uncertain=self:GetDuration(specID,spellID)
    if not handled then return false end
    local data=RA.Registry.HAVOC_TRANSITIONS
    if duration~=0 then
        local wasKnown=state.inMetaKnown==true
        local wasActive=wasKnown and state.inMeta==true
        local remaining=number(state.metaRemains)
        if remaining and remaining<0 then remaining=nil end
        state.windows=state.windows or {}
        state.windowUnknown=state.windowUnknown or {}
        state.windowRemains=state.windowRemains or {}
        state.windowSteps=state.windowSteps or {}
        state.windowSteps.demonic=nil
        if duration then
            state.metaExpiryUncertain=uncertain or state.metaExpiryUncertain==true
                or not wasKnown or (wasActive and remaining==nil)
            state.metaRemains=duration+(wasActive and remaining or 0)
            state.inMeta,state.inMetaKnown=true,true
            state.windows.demonic,state.windowUnknown.demonic=true,nil
            state.windowRemains.demonic=state.metaRemains
        else
            -- An uncertain extension cannot erase an already proven active form.
            -- 未知的延长效果不会抹掉当前已证实的变身，但到期之后不能断言结束。
            state.metaExpiryUncertain=true
            if not wasActive then
                state.inMetaKnown=false; state.metaRemains=nil
                state.windows.demonic=nil; state.windowUnknown.demonic=true
                state.windowRemains.demonic=nil
            else
                state.windows.demonic=true; state.windowUnknown.demonic=nil
                state.windowRemains.demonic=remaining
            end
        end
    end
    if spellID==data.metamorphosis then
        local selected=rank(RA:GetModule("CharacterState"),specID,data.chaoticTalent)
        state.cooldownUnknown=state.cooldownUnknown or {}
        for _,id in ipairs(data.resetCooldowns) do
            if selected and selected>0 then
                state.cooldowns[id]=0; state.cooldownUnknown[id]=nil
            elseif selected==nil then
                local cd=number(state.cooldowns[id])
                if cd~=0 or state.cooldownUnknown[id] then
                    state.cooldowns[id]=nil; state.cooldownUnknown[id]=true
                end
            end
        end
    end
    return true
end
function Transitions:OnInitialize() end
function Transitions:OnEnable() end
function Transitions:OnDisable() end
