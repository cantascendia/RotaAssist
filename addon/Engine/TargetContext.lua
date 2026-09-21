-- Public target/range/aura observations. Unknown is never a fabricated fact.
-- 当前目标、距离、光环的公开观测；未知数据不伪装为事实。
local _, NS = ...
local RA = NS.RA
local Context = {}
RA:RegisterModule("TargetContext", Context)

local tokens, seen, spells = {}, {}, {}
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
    local config = getConfig()
    if not config then return end
    local apl = RA.APLData and RA.APLData[config.specID]
    if not apl or not apl.profiles then return end
    for _, profile in pairs(apl.profiles) do
        for _, name in ipairs({ "singleTarget", "aoe", "opener" }) do
            for _, rule in ipairs(profile[name] or {}) do
                if type(rule.spellID) == "number" then
                    spells[rule.spellID] = true
                    local pair = RA.KNOWN_OVERRIDE_PAIRS and RA.KNOWN_OVERRIDE_PAIRS[rule.spellID]
                    if pair then spells[pair] = true end
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
    state.targetValid = hostile("target")
    local config = getConfig()
    state.supported = config ~= nil
    if not config then return state end

    local probe = config.meleeProbe
    if RA.ResolveSpellOverride then probe = RA:ResolveSpellOverride(probe) end
    if not public(probe) or type(probe) ~= "number"
       or readBool(IsPlayerSpell, probe) ~= true then probe = nil end
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
        end
        local remains = auraRemaining("target", config.essenceBreakAura, now, true)
        if remains then
            state.windows.essence_break = remains > 0
            state.windowRemains.essence_break = remains
            state.windowUnknown.essence_break = nil
        end
    end
    local meta = auraRemaining("player", config.metaAura, now)
    if meta then state.inMeta = meta > 0; state.metaRemains = meta end
    return state
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
    for _, event in ipairs({ "ROTAASSIST_SPEC_CHANGED", "TRAIT_CONFIG_UPDATED", "PLAYER_ENTERING_WORLD" }) do
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
    dirty = true
end
function Context:IsActive() return enabled end
