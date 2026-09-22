-- Public target/range/aura observations. Unknown is never a fabricated fact.
-- 当前目标、距离、光环的公开观测；未知数据不伪装为事实。
local _, NS = ...
local RA = NS.RA
local Context = {}
RA:RegisterModule("TargetContext", Context)

local tokens, seen, spells = {}, {}, {}
local rangeCounts, rangeSampled = {}, {}
local trackedSpells, sampleSerial = 0, 0
for i = 1, 40 do tokens[i] = "nameplate" .. i end
local state = { generation = 0, spellRange = {}, windows = {}, windowUnknown = {}, windowRemains = {} }
local refreshedAt = -math.huge
local dirty = true
local enabled = false

local function public(value)
    return not (issecretvalue and issecretvalue(value))
end

local function readBool(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if ok and public(value) and type(value) == "boolean" then return value end
end

local function readGUID(unit)
    if not UnitGUID then return nil end
    local ok, value = pcall(UnitGUID, unit)
    if ok and public(value) and type(value) == "string" then return value end
end

local function hostile(unit)
    local exists = readBool(UnitExists, unit)
    if exists ~= true then return exists end
    local attack = readBool(UnitCanAttack, "player", unit)
    local dead = readBool(UnitIsDead, unit)
    if attack == false or dead == true then return false end
    if attack == true and dead == false then return true end
end

local function range(spellID, unit)
    return readBool(C_Spell and C_Spell.IsSpellInRange, spellID, unit)
end

-- A nil restricted aura query cannot distinguish absent from inaccessible.
-- nil 不证明光环不存在；只接受公开的 ID 和到期时间。
local function auraRemaining(unit, spellID, now, ownOnly)
    if not C_UnitAuras or not C_UnitAuras.GetUnitAuraBySpellID then return nil end
    local ok, aura = pcall(C_UnitAuras.GetUnitAuraBySpellID, unit, spellID)
    if not ok or not public(aura) or type(aura) ~= "table" then return nil end
    if ownOnly then
        local source = aura.sourceUnit
        if not public(source) or type(source) ~= "string" then return nil end
        if source ~= "player" and readBool(UnitIsUnit, source, "player") ~= true then return nil end
    end
    local id, expiration = aura.spellId, aura.expirationTime
    if not public(id) or type(id) ~= "number" or id ~= spellID
       or not public(expiration) or type(expiration) ~= "number"
       or expiration ~= expiration or expiration <= 0 or expiration >= math.huge then return nil end
    return math.max(0, expiration - now)
end

local function getConfig()
    local detector = RA:GetModule("SpecDetector")
    local spec = detector and detector:GetCurrentSpec()
    local config = RA.Registry and RA.Registry.HAVOC_CONTEXT
    if config and spec and spec.specID == config.specID then return config end
end

local function rebuildSpells()
    wipe(spells)
    wipe(rangeCounts)
    trackedSpells = 0
    local function add(id)
        if not public(id) or type(id) ~= "number" or id <= 0 or id >= math.huge
           or id % 1 ~= 0 or spells[id] or trackedSpells >= 256 then return end
        spells[id] = true
        trackedSpells = trackedSpells + 1
    end
    local catalog = RA:GetModule("SpellCatalog")
    if catalog then for id in pairs(catalog:GetSnapshot().spells) do add(id) end end
    local bridge = RA:GetModule("AssistedCombatBridge")
    if bridge and bridge.GetRotationSpells then
        local ok, ids = pcall(bridge.GetRotationSpells, bridge)
        if ok and public(ids) and type(ids) == "table" then
            for _, id in ipairs(ids) do add(id) end
        end
    end
    local detector = RA:GetModule("SpecDetector")
    local spec = detector and detector:GetCurrentSpec()
    local apl = spec and RA.APLData and RA.APLData[spec.specID]
    if not apl then return end
    for _, rule in ipairs(apl.rules or {}) do add(rule.spellID) end
    for _, profile in pairs(apl.profiles or {}) do
        for _, name in ipairs({ "singleTarget", "aoe", "opener" }) do
            for _, rule in ipairs(profile[name] or {}) do
                if type(rule.spellID) == "number" then
                    add(rule.spellID)
                    local pair = RA.KNOWN_OVERRIDE_PAIRS and RA.KNOWN_OVERRIDE_PAIRS[rule.spellID]
                    if pair then add(pair) end
                end
            end
        end
    end
end

local function clearSnapshot()
    state.targetValid = nil
    state.nearbyEnemies = 0
    state.unknownEnemies = 0
    state.visibleEnemies = 0
    state.countComplete = false
    state.probeSpellID = nil
    state.inMeta = nil
    state.metaRemains = nil
    wipe(state.spellRange)
    wipe(rangeSampled)
    wipe(state.windows)
    wipe(state.windowUnknown)
    wipe(state.windowRemains)
    state.windowUnknown.essence_break = true
end

function Context:Invalidate(targetChanged)
    dirty = true
    refreshedAt = -math.huge
    if targetChanged then
        state.generation = state.generation + 1
        clearSnapshot()
    end
end

function Context:GetSnapshot()
    local now = GetTime()
    if not dirty and now - refreshedAt < 0.15 then return state end
    dirty = false
    refreshedAt = now
    clearSnapshot()
    state.sampledAt = now
    sampleSerial = sampleSerial + 1
    state.sampleSerial = sampleSerial
    state.trackedSpells = trackedSpells
    state.targetValid = hostile("target")
    local config = getConfig()
    state.supported = config ~= nil
    state.genericSupported = trackedSpells > 0

    local probe = config and config.meleeProbe
    if probe and RA.ResolveSpellOverride then probe = RA:ResolveSpellOverride(probe) end
    if not public(probe) or type(probe) ~= "number"
       or readBool(RA.IsPlayerSpellKnownSafe, RA, probe) ~= true then probe = nil end
    state.probeSpellID = probe
    wipe(seen)
    local targetGUID = readGUID("target")
    local targetInRange = state.targetValid == true and probe and range(probe, "target")
    -- Count the explicit target once, even before the initial pull.
    -- 当前目标可在开怪前计入，但不能与其姓名板重复计数。
    if targetInRange == true then
        state.nearbyEnemies = 1
        if targetGUID then seen[targetGUID] = true end
    elseif state.targetValid == true and targetInRange == nil then
        state.unknownEnemies = 1
    end
    for _, unit in ipairs(tokens) do
        local eligible = hostile(unit)
        if eligible == true then
            state.visibleEnemies = state.visibleEnemies + 1
            local guid = readGUID(unit)
            local same = readBool(UnitIsUnit, unit, "target")
            if guid and targetGUID then same = guid == targetGUID end
            if same ~= true and not (guid and seen[guid]) then
                local engaged = readBool(UnitAffectingCombat, unit)
                if engaged == true then
                    -- With an in-range target and unknown identity, this unit
                    -- might be that target: do not count a duplicate as certain.
                    -- 身份未知可能是当前目标，不把重复单位算作确定的额外敌人。
                    local distinct = same == false or state.targetValid == false
                    local inRange = probe and range(probe, unit)
                    if distinct and inRange == true and guid then
                        seen[guid] = true
                        state.nearbyEnemies = state.nearbyEnemies + 1
                    elseif inRange ~= false then
                        state.unknownEnemies = state.unknownEnemies + 1
                    end
                elseif engaged == nil then
                    state.unknownEnemies = state.unknownEnemies + 1
                end
            end
        elseif eligible == nil then
            state.unknownEnemies = state.unknownEnemies + 1
        end
    end
    -- Even all visible units known does not prove off-screen/hidden coverage.
    -- 全部可见单位已知，也不能证明屏外或隐藏敌人的覆盖完整。
    state.countComplete = false
    state.countSource = "public_melee_range_lower_bound"
    if state.targetValid == true then
        for id in pairs(spells) do
            state.spellRange[id] = range(id, "target")
            rangeSampled[id] = true
        end
        local remains = config and auraRemaining("target", config.essenceBreakAura, now, true)
        if remains then
            state.windows.essence_break = remains > 0
            state.windowRemains.essence_break = remains
            state.windowUnknown.essence_break = nil
        end
    end
    local meta = config and auraRemaining("player", config.metaAura, now)
    if meta then state.inMeta = meta > 0; state.metaRemains = meta end
    return state
end

-- Current recommendations may change before a spellbook event (proc overrides).
-- 触发型替换可能先于法术书事件；当前候选按需查询，nil 仍保持未知。
function Context:GetSpellRange(spellID)
    if not public(spellID) or type(spellID) ~= "number" or spellID <= 0
       or spellID >= math.huge or spellID % 1 ~= 0 then return nil end
    self:GetSnapshot()
    if state.targetValid ~= true then return nil end
    if not rangeSampled[spellID] then
        local value = range(spellID, "target")
        if not spells[spellID] and trackedSpells < 256 then
            spells[spellID] = true; trackedSpells = trackedSpells + 1
        end
        if spells[spellID] then
            state.spellRange[spellID] = value; rangeSampled[spellID] = true
        end
        return value
    end
    return state.spellRange[spellID]
end

-- Separate action applicability from native target range and AoE hit counts.
-- 范围伤害的近战见证不写回原生射程，不伪装成精确命中数。
function Context:GetActionRange(spellID)
    if not enabled or not public(spellID) or type(spellID)~="number" or spellID<=0
       or spellID>=math.huge or spellID%1~=0 then return nil,"unknown" end
    local native=self:GetSpellRange(spellID)
    if native~=nil then return native,"native_spell_range" end
    local config=getConfig()
    local area=RA.Registry and RA.Registry.HAVOC_PLAYER_AREA_ACTIONS
    if not config or not area or area[spellID]~=true or state.targetValid~=true then return nil,"unknown" end
    if readBool(C_Spell and C_Spell.SpellHasRange,spellID)~=false then return nil,"unknown" end
    local probe=state.probeSpellID
    if probe and self:GetSpellRange(probe)==true then return true,"current_target_melee_witness" end
    return nil,"unknown"
end

-- Targetable units are not AoE hits: no cone, cleave or splash geometry implied.
-- 可作为该技能目标的单位下界，不代表锥形、顺劈或溅射命中数。
function Context:GetSpellTargets(spellID)
    if not public(spellID) or type(spellID) ~= "number" or spellID <= 0
       or spellID >= math.huge or spellID % 1 ~= 0 then return nil end
    self:GetSpellRange(spellID)
    if not spells[spellID] then return nil end
    local result = rangeCounts[spellID]
    if not result then result = {}; rangeCounts[spellID] = result end
    if result.sampleSerial == sampleSerial then return result end
    result.min, result.unknown, result.complete = 0, 0, false
    result.sampleSerial, result.generation = sampleSerial, state.generation
    result.source = "spell_targetable_lower_bound"
    if readBool(RA.IsPlayerSpellKnownSafe, RA, spellID) ~= true
       or readBool(C_Spell and C_Spell.IsSpellHarmful, spellID) ~= true then
        result.unknown = 1; return result
    end
    wipe(seen)
    local targetGUID = readGUID("target")
    local targetRange = state.spellRange[spellID]
    if state.targetValid == true and targetRange == true then
        result.min = 1
        if targetGUID then seen[targetGUID] = true end
    elseif state.targetValid == true and targetRange == nil then result.unknown = 1 end
    for _, unit in ipairs(tokens) do
        local eligible = hostile(unit)
        if eligible == true then
            local guid = readGUID(unit)
            local same = readBool(UnitIsUnit, unit, "target")
            if guid and targetGUID then same = guid == targetGUID end
            if same ~= true and not (guid and seen[guid]) then
                local engaged = readBool(UnitAffectingCombat, unit)
                if engaged == true then
                    local inRange = range(spellID, unit)
                    if inRange == true and guid and (same == false or state.targetValid == false) then
                        seen[guid] = true; result.min = result.min + 1
                    elseif inRange ~= false then result.unknown = result.unknown + 1 end
                elseif engaged == nil then result.unknown = result.unknown + 1 end
            end
        elseif eligible == nil then result.unknown = result.unknown + 1 end
    end
    return result
end

function Context:OnInitialize() clearSnapshot() end
function Context:OnEnable()
    enabled = true
    rebuildSpells()
    self:Invalidate(true)
    local eh = RA:GetModule("EventHandler")
    if not eh then return end
    eh:Subscribe("PLAYER_TARGET_CHANGED", "TargetContext", function()
        self:Invalidate(true)
        eh:Fire("ROTAASSIST_TARGET_CONTEXT_CHANGED", state.generation)
    end)
    for _, event in ipairs({ "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "UNIT_AURA" }) do
        eh:Subscribe(event, "TargetContext", function() self:Invalidate(false) end)
    end
    for _, event in ipairs({ "ROTAASSIST_SPEC_CHANGED", "TRAIT_CONFIG_UPDATED", "PLAYER_ENTERING_WORLD",
        "ROTAASSIST_SPELL_CATALOG_CHANGED", "ROTAASSIST_CHARACTER_CHANGED", "SPELLS_CHANGED" }) do
        eh:Subscribe(event, "TargetContext", function()
            rebuildSpells()
            self:Invalidate(true)
            eh:Fire("ROTAASSIST_TARGET_CONTEXT_CHANGED", state.generation)
        end)
    end
end
function Context:OnDisable()
    enabled = false
    local eh = RA:GetModule("EventHandler")
    if eh then eh:UnsubscribeAll("TargetContext") end
    clearSnapshot()
    wipe(rangeCounts)
    dirty = true
end
function Context:IsActive() return enabled end
