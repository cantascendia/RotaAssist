-- Public player aura facts, with explicit proof required for absence.
-- 公开玩家光环观测；只有确认接口不受限时，nil 才能证明不存在。
local _, NS = ...
local RA = NS.RA
local Auras = {}
RA:RegisterModule("PublicAuraFacts", Auras)
local function public(v) return not (issecretvalue and issecretvalue(v)) end
local function number(v)
    if public(v) and type(v)=="number" and v==v and math.abs(v)<math.huge then return v end
end
local function boolean(fn,...)
    if type(fn)~="function" then return nil end
    local ok,value=pcall(fn,...)
    if ok and public(value) and type(value)=="boolean" then return value end
end
function Auras:ReadPlayer(spellID, now)
    if not C_UnitAuras or type(C_UnitAuras.GetPlayerAuraBySpellID)~="function" then return nil end
    local ok,aura=pcall(C_UnitAuras.GetPlayerAuraBySpellID,spellID)
    if not ok or not public(aura) then return nil end
    if aura==nil then
        if C_Secrets and boolean(C_Secrets.ShouldAurasBeSecret)==false
           and boolean(C_Secrets.ShouldSpellAuraBeSecret,spellID)==false
           and boolean(UnitExists,"player")==true and boolean(UnitIsVisible,"player")==true then
            return false,0
        end
        return nil
    end
    if type(aura)~="table" or number(aura.spellId)~=spellID then return nil end
    local expiration=number(aura.expirationTime)
    if expiration==nil or expiration<0 then return nil end
    if expiration==0 then return true,nil end -- Public permanent aura / 公开永久光环。
    return expiration>now,math.max(0,expiration-now)
end
function Auras:OnInitialize() end
function Auras:OnEnable() end
function Auras:OnDisable() end
