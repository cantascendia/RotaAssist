------------------------------------------------------------------------
-- RotaAssist - Spec Detector
-- Detects the current player specialization and reloads APL data when
-- spec or talents change.
------------------------------------------------------------------------

local _, NS = ...
local RA = NS.RA
local SpecDetector = {}
RA:RegisterModule("SpecDetector", SpecDetector)

---@class SpecInfo
---@field classID number
---@field specID number
---@field className string
---@field specName string
---@field role string
---@field classFile string
---@field icon number

---@type SpecInfo|nil
local currentSpec = nil

---@return SpecInfo|nil
local function detectSpec()
    local specIndex = GetSpecialization()
    if not specIndex then
        RA:PrintDebug("SpecDetector: No specialization selected")
        return nil
    end

    local specID, specName, _, specIcon, role = GetSpecializationInfo(specIndex)
    if not specID then
        RA:PrintDebug("SpecDetector: GetSpecializationInfo returned nil")
        return nil
    end

    local _, className, classID = UnitClass("player")
    return {
        classID = classID,
        specID = specID,
        className = className,
        specName = specName,
        role = role,
        classFile = className,
        icon = specIcon,
    }
end

---@type table<number, boolean>  specIDs already announced as unsupported
---已提示过"不支持"的专精 ID，避免每次天赋变更都刷屏
local notifiedUnsupportedSpecs = {}

---Predictive data that is present in the package but is not safe to execute yet.
---Spell existence is insufficient validation: a placeholder ID can resolve to a real,
---unrelated spell. These specs stay in Blizzard-only mode until their spell identity
---and priority list have been checked in the live client.
---包内存在但尚不能安全执行的预测数据。ID 能解析不等于技能身份正确；占位 ID 可能恰好
---指向另一个真实技能。完成真机技能身份与优先级验证前，这些专精只使用暴雪建议。
local UNVERIFIED_PREDICTIVE_SPECS = {
    [1480] = true, -- Devourer Demon Hunter / 吞噬者恶魔猎手
}

---Fall back to pure Blizzard-recommendation mode for a spec we ship no APL for.
---v1.1.0 loads Demon Hunter data only (D-014), so this is the normal path for the
---other 17 specs — it must be silent-safe, produce no Lua error, and leave
---SmartQueueManager working off `C_AssistedCombat` alone.
---对未随版本发布 APL 的专精回退到纯暴雪推荐模式。
---v1.1.0 只加载恶魔猎手数据（D-014），其余 17 个专精走的就是这条路径 ——
---必须无 Lua 报错，且让 SmartQueueManager 仅凭 `C_AssistedCombat` 继续工作。
---@param specInfo SpecInfo
---@param reason string  Debug-only explanation (not user-facing)
local function degradeToBlizzardOnly(specInfo, reason)
    RA:PrintDebug("SpecDetector: " .. reason)

    -- Drop any APL left over from a previously loaded spec. Without this the engine
    -- would keep predicting the OLD spec's rotation after the player switches to an
    -- unsupported one — worse than showing nothing.
    -- 清除上一个专精残留的 APL。否则玩家切到不支持的专精后，引擎仍会用旧专精的循环
    -- 做预测 —— 那比什么都不显示更糟。
    local aplEngine = RA:GetModule("APLEngine")
    if aplEngine and aplEngine.ClearAPL then
        aplEngine:ClearAPL()
    end

    -- One notice per spec per session: refreshSpec() also fires on talent changes
    -- and on every PLAYER_ENTERING_WORLD.
    -- 每个专精每次会话只提示一次：refreshSpec() 在天赋变更与每次进入世界时都会触发。
    if specInfo.specID and notifiedUnsupportedSpecs[specInfo.specID] then
        return
    end
    if specInfo.specID then
        notifiedUnsupportedSpecs[specInfo.specID] = true
    end

    local fmt = (RA.L and RA.L["SPEC_NOT_SUPPORTED"])
        or "%s is not yet supported — showing Blizzard's suggestion only."
    RA:Print(string.format(fmt, tostring(specInfo.specName or specInfo.specID)))
end

---@param specInfo SpecInfo
local function loadAPLForSpec(specInfo)
    if UNVERIFIED_PREDICTIVE_SPECS[specInfo.specID] then
        degradeToBlizzardOnly(specInfo, string.format(
            "Predictive APL for specID %d is packaged but not live-verified", specInfo.specID))
        return
    end

    if not RA.APLData then
        degradeToBlizzardOnly(specInfo, "No APL data table found")
        return
    end

    local aplData = RA.APLData[specInfo.specID]
    if not aplData then
        degradeToBlizzardOnly(specInfo, string.format(
            "No APL found for specID %d", specInfo.specID))
        return
    end

    local validClass = aplData.class
    if validClass and validClass ~= specInfo.classFile then
        degradeToBlizzardOnly(specInfo, string.format(
            "APL class mismatch for specID %d (APL=%s, player=%s) - skipping",
            specInfo.specID, validClass, specInfo.classFile))
        return
    end

    RA:PrintDebug(string.format("SpecDetector: Loaded APL for %s %s (specID %d)",
        specInfo.className, specInfo.specName, specInfo.specID))

    local aplEngine = RA:GetModule("APLEngine")
    if aplEngine and aplEngine.SetAPL then
        aplEngine:SetAPL(specInfo.specID, aplData, specInfo.classID)
        if aplEngine.RefreshProfileFromTalents then
            local profileName = aplEngine:RefreshProfileFromTalents()
            RA:PrintDebug("SpecDetector: Active APL profile = " .. tostring(profileName))
        end
    end
end

---@param forceReload boolean|nil
local function refreshSpec(forceReload)
    local newSpec = detectSpec()
    if not newSpec then
        return
    end

    local changed = (not currentSpec) or (currentSpec.specID ~= newSpec.specID)
    currentSpec = newSpec

    if changed or forceReload then
        RA:PrintDebug(string.format("SpecDetector: Detected %s %s (%s)",
            currentSpec.className, currentSpec.specName, currentSpec.role))

        loadAPLForSpec(currentSpec)

        local eh = RA:GetModule("EventHandler")
        if eh and eh.Fire then
            eh:Fire("ROTAASSIST_SPEC_CHANGED", currentSpec)
        end
    end
end

function SpecDetector:OnInitialize()
end

function SpecDetector:OnEnable()
    local eh = RA:GetModule("EventHandler")
    if eh then
        eh:Subscribe("PLAYER_SPECIALIZATION_CHANGED", "SpecDetector", function()
            RA:PrintDebug("SpecDetector: Specialization changed event")
            refreshSpec()
        end)

        eh:Subscribe("TRAIT_CONFIG_UPDATED", "SpecDetector", function()
            RA:PrintDebug("SpecDetector: Talent configuration changed")
            refreshSpec(true)
        end)

        eh:Subscribe("PLAYER_ENTERING_WORLD", "SpecDetector", function()
            RA:PrintDebug("SpecDetector: PLAYER_ENTERING_WORLD - scheduling delayed refresh")
            C_Timer.After(0.5, function()
                refreshSpec()
            end)
        end)
    end

    refreshSpec()
end

function SpecDetector:OnPlayerEnteringWorld()
    refreshSpec()
end

---@return SpecInfo|nil
function SpecDetector:GetCurrentSpec()
    if not currentSpec then
        refreshSpec()
    end
    return currentSpec
end

---@param role string
---@return boolean
function SpecDetector:IsRole(role)
    return currentSpec and currentSpec.role == role
end

---@return number|nil
function SpecDetector:GetSpecID()
    return currentSpec and currentSpec.specID
end

---Whether local predictive/advisory data is approved for runtime use.
---Unloaded specs and explicitly unverified specs must stay in Blizzard-only mode.
---本地预测/建议数据是否获准在运行时使用。未加载或明确未验证的专精必须保持暴雪-only。
---@param specID number|nil
---@return boolean
function SpecDetector:IsPredictiveSpecSupported(specID)
    local id = specID or (currentSpec and currentSpec.specID)
    return id ~= nil
       and not UNVERIFIED_PREDICTIVE_SPECS[id]
       and RA.APLData ~= nil
       and RA.APLData[id] ~= nil
end

---@return number|nil
function SpecDetector:GetPrimaryPowerType()
    if not currentSpec or not RA.SpecEnhancements then
        return nil
    end
    local enhData = RA.SpecEnhancements[currentSpec.specID]
    if enhData and enhData.resource then
        return enhData.resource.type or enhData.resource.powerType
    end
    return nil
end
