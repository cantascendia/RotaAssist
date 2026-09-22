------------------------------------------------------------------------
-- Optional bounded public decision trace / 可选、限长的公开决策采样。
-- No hidden state, player identity, damage claims, timers or UI dependency.
-- 不保存隐状态或玩家身份，不推断伤害，不创建计时器或依赖界面。
------------------------------------------------------------------------
local _, NS = ...
local RA = NS.RA
local Audit = {}
RA:RegisterModule("CombatAudit", Audit)
local LIMIT, INTERVAL = 1200, 0.5
local active, record, lastSample = false, nil, nil
local function public(v) return not (issecretvalue and issecretvalue(v)) end
local function number(v)
    if public(v) and type(v) == "number" and v == v and math.abs(v) < math.huge then return v end
end
local function boolean(v) if public(v) and type(v) == "boolean" then return v end end
local function text(v)
    if public(v) and type(v) == "string" and #v <= 8192 then return v end
end
local function tableValue(v) if public(v) and type(v) == "table" then return v end end
local function call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if ok then return value end
end
local function time() return number(call(GetTime)) end
local function snapshot(moduleName, method)
    local module = RA:GetModule(moduleName)
    if module then return tableValue(call(module[method], module)) end
end
local function append(kind, now)
    local index = record.nextIndex
    local row = record.events[index]
    if not row then row = {}; record.events[index] = row else wipe(row) end
    record.totalEvents = record.totalEvents + 1
    row.sequence, row.kind, row.time = record.totalEvents, kind, now
    record.nextIndex = index % LIMIT + 1
    record.count = math.min(LIMIT, record.count + 1)
    record.dropped = math.max(0, record.totalEvents - LIMIT)
    return row
end

function Audit:SetRecording(enabled)
    active = enabled == true
    lastSample = nil
    if active then
        record = { schema = "rotaassist.combat-audit.v1", addonVersion = text(RA.version),
            startedAt = time(), events = {}, builds = {}, count = 0, nextIndex = 1, totalEvents = 0,
            dropped = 0, interval = INTERVAL, limit = LIMIT,
            maximumDPSProven = false, scope = "sampled_public_decisions" }
        RA.db.profile.combatAudit = record
        self:Capture("start")
    elseif record then
        record.stoppedAt = time()
    end
end

function Audit:IsRecording() return active end

function Audit:Capture(kind, spellID)
    if not active or not record then return end
    local now = time()
    if not now then return end
    if kind == "queue" then
        if lastSample and now >= lastSample and now - lastSample < INTERVAL then return end
        lastSample = now
    end
    local row = append(kind, now)
    row.castSpellID = number(spellID)
    local queue = snapshot("SmartQueueManager", "GetFinalQueue")
    local main = queue and tableValue(queue.main)
    if main then row.queueSpellID, row.source = number(main.spellID), text(main.source) end
    local status = snapshot("SmartQueueManager", "GetIndependentStatus")
    if status then
        row.policyStatus, row.policySha256 = text(status.status), text(status.policySha256)
        row.referenceSpellID, row.independentSpellID = number(status.referenceSpellID), number(status.spellID)
        row.planningDelay, row.consensusNodes = number(status.planningDelay), number(status.consensusNodes)
        row.exhaustive, row.policyInvariant = boolean(status.consensusExhaustive), boolean(status.policyInvariant)
        row.proofScope = text(status.proofScope)
        local missing = tableValue(status.missing)
        if missing then
            row.missing1, row.missing2, row.missing3, row.missing4 = text(missing[1]), text(missing[2]), text(missing[3]), text(missing[4])
        end
    end
    local target = snapshot("TargetContext", "GetSnapshot")
    if target then
        row.targetValid, row.countComplete = boolean(target.targetValid), boolean(target.countComplete)
        row.nearbyEnemies, row.unknownEnemies = number(target.nearbyEnemies), number(target.unknownEnemies)
    end
    local build = snapshot("CharacterState", "GetSnapshot")
    if build then
        row.buildGeneration, row.specID, row.heroID = number(build.generation), number(build.specID), number(build.heroID)
        row.talentsComplete, row.equipmentComplete = boolean(build.talentsComplete), boolean(build.equipmentComplete)
        -- Build keys contain numeric talent/gear descriptors, not character names.
        -- build 标识来自天赋/装备描述，不包含角色名。
        local talentKey, equipmentKey = text(build.talentKey), text(build.equipmentKey)
        for i = 1, #record.builds do
            local saved = record.builds[i]
            if saved.generation == row.buildGeneration and saved.talentKey == talentKey and saved.equipmentKey == equipmentKey then
                row.buildIndex = i; break
            end
        end
        if not row.buildIndex and #record.builds < 16 then
            local index = #record.builds + 1
            record.builds[index] = { generation = row.buildGeneration, talentKey = talentKey, equipmentKey = equipmentKey,
                specID = row.specID, heroID = row.heroID }
            row.buildIndex = index
        end
    end
end

function Audit:OnInitialize() active, record, lastSample = false, nil, nil end
function Audit:OnEnable()
    local events = RA:GetModule("EventHandler")
    if not events then return end
    events:Subscribe("ROTAASSIST_QUEUE_UPDATED", "CombatAudit", function() self:Capture("queue") end)
    events:Subscribe("ROTAASSIST_SPELLCAST_SUCCEEDED", "CombatAudit", function(_, unit, _, spellID)
        if public(unit) and unit == "player" then self:Capture("cast", spellID) end
    end)
    events:Subscribe("PLAYER_REGEN_DISABLED", "CombatAudit", function() self:Capture("combat_start") end)
    events:Subscribe("PLAYER_REGEN_ENABLED", "CombatAudit", function() self:Capture("combat_end") end)
    events:Subscribe("ROTAASSIST_CHARACTER_CHANGED", "CombatAudit", function() self:Capture("build_change") end)
    events:Subscribe("ROTAASSIST_SETTINGS_RESET", "CombatAudit", function() self:SetRecording(false) end)
end
function Audit:OnDisable()
    self:SetRecording(false)
    local events = RA:GetModule("EventHandler")
    if events then events:UnsubscribeAll("CombatAudit") end
end
