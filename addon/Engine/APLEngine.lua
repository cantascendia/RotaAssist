------------------------------------------------------------------------
-- RotaAssist - APL Engine (Refactored)
-- Role: APL state-machine SIMULATOR / prediction engine.
-- No longer the "real-time combat decider" — Blizzard's C_AssistedCombat
-- provides slot 1. This engine predicts steps 2-3 using existing APL
-- data as "pre-baked knowledge".
-- 役割変更: リアルタイム判定→APLベース予測シミュレーター
------------------------------------------------------------------------

local _, NS = ...
local RA = NS.RA
local APLEngine = {}
RA:RegisterModule("APLEngine", APLEngine)

-- 已知的被动/不可施放技能黑名单（API 查询的快速路径备份）
-- Known passive/non-castable spell blacklist (fast-path backup for API queries)
local PASSIVE_BLACKLIST = RA.Registry.PASSIVE_BLACKLIST

------------------------------------------------------------------------
-- Internal State
------------------------------------------------------------------------

---@type table|nil  Currently loaded APL definition
local currentAPL = nil

---@type number|nil
local currentSpecID = nil

---@type number|nil  Class ID (disambiguates Devourer specID 1480)
local currentClassID = nil

---@type string  Active profile name
local currentProfileName = "default"

---@type boolean  Metamorphosis / Void Meta state estimate
local metaActive = false
local metaExpireTime = 0

local META_SPELL_IDS
local WINDOW_TRIGGER_SPELLS
local WINDOW_STEP_DURATIONS

------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------

local function splitStr(str, sep)
    local result = {}
    local pattern = "([^" .. sep:gsub(".", "%%%1") .. "]+)"
    for part in str:gmatch(pattern) do
        result[#result + 1] = part
    end
    return result
end

local function trim(s)
    return s:match("^%s*(.-)%s*$")
end

---Split a condition string on its conjunction separator.
---Accepts ` AND ` and ` and ` (case-insensitive). Lua patterns have no
---case-insensitive flag, so the character sets are spelled out explicitly.
---`OR` is deliberately NOT handled here — see isSupportedToken() below.
---按合取分隔符切分条件字符串。
---支持 ` AND ` 与 ` and `（大小写不敏感）。Lua 模式没有忽略大小写的标志位，
---因此显式写出字符集。`OR` 有意不在此处理 —— 见下方 isSupportedToken()。
local function splitConditions(condition)
    local clauses = {}
    local normalized = condition:gsub("%s+[Aa][Nn][Dd]%s+", "\1")
    for clause in normalized:gmatch("[^\1]+") do
        clauses[#clauses + 1] = trim(clause)
    end
    return clauses
end

local function compareNumber(lhs, op, rhs)
    if op == ">=" then
        return lhs >= rhs
    elseif op == "<=" then
        return lhs <= rhs
    elseif op == ">" then
        return lhs > rhs
    elseif op == "<" then
        return lhs < rhs
    elseif op == "==" then
        return lhs == rhs
    end
    return false
end

local function parseNumericCondition(cond, prefix)
    local suffix = trim(cond:gsub("^" .. prefix, "", 1))
    local operators = { ">=", "<=", "==", ">", "<" }

    for _, op in ipairs(operators) do
        if suffix:sub(1, #op) == op then
            local rawValue = trim(suffix:sub(#op + 1))
            local numericValue = tonumber(rawValue)
            if numericValue ~= nil then
                return op, numericValue
            end
            return nil, nil
        end
    end

    return nil, nil
end

local function getDefinitionSpellName(definitionInfo)
    if not definitionInfo then
        return nil
    end
    local overrideName = definitionInfo.overrideName
    if not issecretvalue(overrideName) and type(overrideName) == "string"
       and overrideName ~= "" then
        return overrideName
    end
    local spellID = definitionInfo.spellID
    if not issecretvalue(spellID) and type(spellID) == "number"
       and C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
        if ok and type(info) == "table" then
            local name = info.name
            if not issecretvalue(name) and type(name) == "string" then
                return name
            end
        end
    end
    return nil
end

local function setWindowState(simState, windowKey, active)
    simState.windows = simState.windows or {}
    simState.windowSteps = simState.windowSteps or {}
    simState.windows[windowKey] = active == true
    if simState.windowUnknown then simState.windowUnknown[windowKey] = nil end
    if simState.windowRemains then simState.windowRemains[windowKey] = nil end
    if active then
        simState.windowSteps[windowKey] = WINDOW_STEP_DURATIONS[windowKey] or 1
    else
        simState.windowSteps[windowKey] = 0
    end
end

local function tickWindowState(simState)
    if not simState.windowSteps then
        return
    end

    simState.windows = simState.windows or {}
    for windowKey, remainingSteps in pairs(simState.windowSteps) do
        if simState.windowRemains and simState.windowRemains[windowKey] ~= nil then
            -- Public remaining seconds use elapsed time, not a fixed step count.
            -- 公开剩余秒数按经过时间衰减，不按固定步数提前结束。
        elseif remainingSteps and remainingSteps > 0 then
            remainingSteps = remainingSteps - 1
            simState.windowSteps[windowKey] = remainingSteps
            if remainingSteps <= 0 then
                simState.windows[windowKey] = false
            end
        else
            simState.windows[windowKey] = false
        end
    end
end

-- Collect selected trait IDs before resolving any localized display name.
-- 先收集已选天赋的稳定 ID；名字仅为旧配置的兼容路径。
local function getActiveTalentSpellNames()
    local character = RA:GetModule("CharacterState")
    if character then
        local observed = character:GetSnapshot()
        if observed.talentsComplete then return observed end
        return nil
    end
    if not C_ClassTalents or not C_ClassTalents.GetActiveConfigID then
        return nil
    end
    if not C_Traits or not C_Traits.GetConfigInfo or not C_Traits.GetTreeNodes
       or not C_Traits.GetNodeInfo or not C_Traits.GetEntryInfo or not C_Traits.GetDefinitionInfo then
        return nil
    end

    local okActive, configID = pcall(C_ClassTalents.GetActiveConfigID)
    if not okActive or issecretvalue(configID) or type(configID) ~= "number" then
        return nil
    end

    local okConfig, configInfo = pcall(C_Traits.GetConfigInfo, configID)
    if not okConfig or not configInfo or type(configInfo.treeIDs) ~= "table" then
        return nil
    end

    local talents = { names = {}, definitionIDs = {}, spellIDs = {} }
    for _, treeID in ipairs(configInfo.treeIDs) do
        local okNodes, nodeIDs = pcall(C_Traits.GetTreeNodes, treeID)
        if not okNodes or type(nodeIDs) ~= "table" then return nil end
        for _, nodeID in ipairs(nodeIDs) do
                local okNode, nodeInfo = pcall(C_Traits.GetNodeInfo, configID, nodeID)
                if not okNode or type(nodeInfo) ~= "table" then return nil end
                local rank = nodeInfo.activeRank
                if issecretvalue(rank) then return nil end
                if type(rank) == "number" and rank > 0 then
                    local activeEntryID = nodeInfo.activeEntry and nodeInfo.activeEntry.entryID
                    -- entryIDs includes unselected choices; only committed ranks count.
                    -- entryIDs 含未选分支，只读取已激活/已提交的条目。
                    local entryIDs = activeEntryID and { activeEntryID } or nodeInfo.entryIDsWithCommittedRanks
                    if type(entryIDs) == "table" then
                        for _, entryID in ipairs(entryIDs) do
                            local okEntry, entryInfo = pcall(C_Traits.GetEntryInfo, configID, entryID)
                            if not okEntry or type(entryInfo) ~= "table" then return nil end
                            local definitionID = entryInfo.definitionID
                            if issecretvalue(definitionID) then return nil end
                            if type(definitionID) == "number" then
                                talents.definitionIDs[definitionID] = true
                                local okDef, definitionInfo = pcall(C_Traits.GetDefinitionInfo, definitionID)
                                if okDef and type(definitionInfo) == "table" then
                                    local spellID = definitionInfo.spellID
                                    if issecretvalue(spellID) then return nil end
                                    if type(spellID) == "number" then
                                        talents.spellIDs[spellID] = true
                                    end
                                    local spellName = getDefinitionSpellName(definitionInfo)
                                    if spellName then
                                        talents.names[spellName] = true
                                    end
                                end
                            end
                        end
                    end
                end
        end
    end

    return talents
end

local function resolveProfileFromTalents(aplData)
    if not aplData or not aplData.profiles then
        return "default"
    end

    local activeTalents = getActiveTalentSpellNames()
    if not activeTalents then return "default" end
    local matchName
    local matchedProfile
    for profileName, profile in pairs(aplData.profiles) do
        if type(profile) == "table" then
            local signatures = profile.signatureTalentDefinitionIDs
            local selected = activeTalents.definitionIDs
            if type(signatures) ~= "table" then
                signatures = profile.signatureTalentSpellIDs
                selected = activeTalents.spellIDs
            end
            if type(signatures) ~= "table" then
                signatures = profile.signatureTalentNames
                selected = activeTalents.names
            end
            if type(signatures) == "table" then
                for _, signature in ipairs(signatures) do
                    if selected[signature] then
                        -- Aliases of the default table are one profile, not a tie.
                        -- 默认配置的别名不计为冲突。
                        matchName = profile == aplData.profiles.default and "default" or profileName
                        if matchedProfile and matchedProfile ~= matchName then
                            return "default"
                        end
                        matchedProfile = matchName
                        break
                    end
                end
            end
        end
    end

    return matchedProfile or "default"
end

------------------------------------------------------------------------
-- Condition Vocabulary Validation (LOAD TIME ONLY — never on the hot path)
-- 条件词汇校验（仅加载期 —— 绝不在热路径调用）
--
-- EvaluateCondition() ends in `else pass = false end`, so any token it does not
-- recognise silently disables its rule forever. Rather than let that rot in
-- place, SetAPL() validates every condition string once per spec and records the
-- offenders here. Inspect with `/ra aplcheck`.
--
-- EvaluateCondition() 最后是 `else pass = false end`，任何它不认识的 token 都会让
-- 对应规则永久静默失效。与其让问题烂在原地，SetAPL() 在每个专精加载时逐条校验
-- condition 字符串，并把问题规则记录到这里。用 `/ra aplcheck` 查看。
--
-- NOTE: tokens such as buff:/debuff:/cp/target_hp are intentionally NOT
-- implemented. They depend on secret combat values that the simulator can only
-- guess at, and a guessed answer produces plausible-but-wrong advice.
-- 注意：buff:/debuff:/cp/target_hp 等 token 是有意不实现的。它们依赖 secret 战斗
-- 数据，模拟器只能靠猜，而猜出来的结果会给出"看似合理实则错误"的建议。
------------------------------------------------------------------------

---@type table[]  Diagnostics: { specID, list, spellID, condition, token }
APLEngine.invalidRules = {}

---@type table<number, boolean>  specIDs already validated (validation is deterministic)
local validatedSpecs = {}

---Argument-less tokens handled by EvaluateCondition.
---EvaluateCondition 支持的无参数 token。
local SIMPLE_TOKENS = {
    ["always"]      = true,
    ["cd_ready"]    = true,
    ["ready"]       = true,
    ["in_meta"]     = true,
    ["not_in_meta"] = true,
}

---Tokens of the form `<prefix><op><number>`, mirroring the
---parseNumericCondition() branches inside EvaluateCondition.
---形如 `<前缀><运算符><数字>` 的 token，与 EvaluateCondition 内的
---parseNumericCondition() 分支一一对应。
local NUMERIC_PREFIXES = {
    "estimated_resource",
    "target_count",
    "combat_time",
    "charges",
}

---Is this single clause something EvaluateCondition can actually evaluate?
---这个子句 EvaluateCondition 真的能求值吗？
---@param token string  A trimmed single clause
---@return boolean supported
local function isSupportedToken(token)
    if SIMPLE_TOKENS[token] then
        return true
    end

    if token:match("^cd_soon:%d+%.?%d*$") then return true end
    if token:match("^after:%d+$")         then return true end
    if token:match("^not_after:%d+$")     then return true end

    -- window:<key> / not_window:<key> — the key must be one the simulator can ever
    -- set (WINDOW_STEP_DURATIONS), otherwise the clause is permanently false.
    -- window key 必须是模拟器可能置位的键（WINDOW_STEP_DURATIONS），否则该子句恒为 false。
    local windowKey = token:match("^window:(.+)$") or token:match("^not_window:(.+)$")
    if windowKey then
        return WINDOW_STEP_DURATIONS[windowKey] ~= nil
    end

    -- Numeric comparisons. A bare prefix match is NOT enough: without a valid
    -- operator+number, EvaluateCondition silently yields `pass = true`, which is just
    -- as wrong as a silent false (e.g. "charges:mind_blast>=2" names a spell, not a
    -- number, and would let the rule fire unconditionally).
    -- 数值比较。仅前缀匹配不够：没有合法的运算符+数字时，EvaluateCondition 会静默返回
    -- pass = true，与静默 false 同样有害（例如 "charges:mind_blast>=2" 跟的是技能名而非
    -- 数字，会让规则无条件触发）。
    for i = 1, #NUMERIC_PREFIXES do
        local prefix = NUMERIC_PREFIXES[i]
        if token:sub(1, #prefix) == prefix then
            local op = parseNumericCondition(token, prefix)
            return op ~= nil
        end
    end

    return false
end

---Record one offending rule, de-duplicated within the spec being validated.
---记录一条问题规则，在当前校验的专精内去重。
---@param seen table<string, boolean>
---@param specID number|nil
---@param listName string
---@param rule table
---@param condition string
---@param token string
local function recordInvalidRule(seen, specID, listName, rule, condition, token)
    local key = tostring(rule.spellID) .. "|" .. condition .. "|" .. token
    if seen[key] then return end
    seen[key] = true

    local entries = APLEngine.invalidRules
    entries[#entries + 1] = {
        specID    = specID,
        list      = listName,
        spellID   = rule.spellID,
        condition = condition,
        token     = token,
    }
end

---@param seen table<string, boolean>
---@param specID number|nil
---@param rule table
---@param listName string
local function validateRuleCondition(seen, specID, rule, listName)
    local condition = type(rule) == "table" and rule.condition or nil
    if type(condition) ~= "string" or condition == "" then
        return
    end

    -- `OR` is deliberately unimplemented: splitConditions() only splits conjunctions,
    -- so a disjunction collapses into one unmatchable token and kills the rule. Report
    -- it as unsupported instead of half-implementing disjunction over guessed data.
    -- `OR` 有意未实现：splitConditions() 只切合取，析取会被压成一个无法匹配的 token
    -- 从而让规则失效。这里如实上报为 unsupported，而不是基于猜测数据半吊子实现析取。
    if condition:match("%s+[Oo][Rr]%s+") then
        recordInvalidRule(seen, specID, listName, rule, condition, "OR (unsupported operator)")
        return
    end

    local clauses = splitConditions(condition)
    for i = 1, #clauses do
        if not isSupportedToken(clauses[i]) then
            recordInvalidRule(seen, specID, listName, rule, condition, clauses[i])
        end
    end
end

---@param seen table<string, boolean>
---@param specID number|nil
---@param actionList table|nil
---@param listName string
local function validateActionList(seen, specID, actionList, listName)
    if type(actionList) ~= "table" then return end
    for i = 1, #actionList do
        validateRuleCondition(seen, specID, actionList[i], listName)
    end
end

---Walk every action list in an APL definition and validate its conditions.
---遍历 APL 定义中的所有 action list 并校验其条件。
---@param specID number|nil
---@param aplData table
local function validateAPLConditions(specID, aplData)
    local seen = {}

    if type(aplData.profiles) == "table" then
        for profileName, profile in pairs(aplData.profiles) do
            if type(profile) == "table" then
                validateActionList(seen, specID, profile.singleTarget, profileName .. "/singleTarget")
                validateActionList(seen, specID, profile.aoe, profileName .. "/aoe")
                if type(profile.voidMeta) == "table" then
                    -- voidMeta is either a plain action list or a { singleTarget = {...} }
                    -- wrapper; the inert call is a no-op for whichever shape it is not.
                    -- voidMeta 可能是纯规则列表，也可能是 { singleTarget = {...} } 包装；
                    -- 不匹配的那次调用会自然空转。
                    validateActionList(seen, specID, profile.voidMeta.singleTarget, profileName .. "/voidMeta")
                    validateActionList(seen, specID, profile.voidMeta, profileName .. "/voidMeta")
                end
            end
        end
    end

    -- Phase 1 backward-compat flat rule list
    validateActionList(seen, specID, aplData.rules, "rules")
end

------------------------------------------------------------------------
-- Unknown-spellID Defense (LOAD TIME — see D-015)
-- 未知 spellID 防御（加载期 —— 见 D-015）
--
-- Data/APL/DemonHunter_Devourer.lua was authored from 12.0 datamining and still
-- carries unverified spellIDs. An ID that does not exist on the running client
-- would otherwise be recommended as garbage: an empty icon with no name that the
-- player cannot cast. SetAPL() therefore resolves every rule's spellID once per
-- spec and DELETES the unresolvable rules from the live action lists.
--
-- Why prune at load instead of filtering in PredictNext(): PredictNext runs on
-- the UI update path and walks the action list every step of every frame, while
-- spell existence is a fixed property of the client build. Checking it once per
-- spec costs nothing at runtime; checking it per frame costs a pcall per rule.
--
-- Data/APL/DemonHunter_Devourer.lua 的 spellID 源自 12.0 数据挖掘，尚未真机验证。
-- 客户端里不存在的 ID 会被当作垃圾推荐显示出来：一个没有名字、玩家也放不出来的空图标。
-- 因此 SetAPL() 对每个专精把所有规则的 spellID 解析一次，并把解析不出来的规则
-- 直接从生效的 action list 中删除。
--
-- 为何在加载期剔除而不是在 PredictNext() 里过滤：PredictNext 挂在 UI 刷新路径上，
-- 每帧每步都要遍历 action list，而"技能是否存在"是客户端版本的固定属性。每个专精查
-- 一次的代价是零；每帧查一次的代价是每条规则一个 pcall。
------------------------------------------------------------------------

---@type table[]  Diagnostics: { specID, spellID, note, list, pruned, count }
APLEngine.unknownSpells = {}

---@type table<number, boolean>  spellIDs this client could not resolve
local unknownSpellIDs = {}

---@type table<string, table>  "specID|spellID" -> diagnostic entry (de-duplication)
local unknownSpellSeen = {}

---Does this spellID resolve against the running client's spell database?
---Undecidable cases (API absent, pcall error) return true: never disable a rule on
---the strength of a check that did not actually run.
---该 spellID 在当前客户端的技能库里能解析出来吗？
---无法判定时（API 不存在 / pcall 失败）返回 true：不因一次没真正跑成的检查而禁用规则。
---@param spellID any
---@return boolean exists
local function spellExists(spellID)
    if type(spellID) ~= "number" then
        return false
    end
    if not (C_Spell and C_Spell.GetSpellInfo) then
        return true
    end
    local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
    if not ok then
        return true
    end
    -- type() rather than a truthiness test: the return value is never inspected
    -- beyond "is it a table", so nothing here can trip over a secret value.
    -- 用 type() 而不是真值判断：这里只关心"是不是一张表"，不会踩到 secret value。
    return type(info) == "table"
end

---Record one unresolvable spellID, de-duplicated across every list it appears in.
---记录一个无法解析的 spellID，跨所有出现的 list 去重。
---@param specID number|nil
---@param listName string
---@param rule table
---@param pruned boolean  true = rule deleted, false = flagged and skipped at runtime
local function recordUnknownSpell(specID, listName, rule, pruned)
    unknownSpellIDs[rule.spellID] = true

    local key = tostring(specID) .. "|" .. tostring(rule.spellID)
    local entry = unknownSpellSeen[key]
    if entry then
        entry.count = entry.count + 1
        return
    end

    entry = {
        specID  = specID,
        spellID = rule.spellID,
        list    = listName,
        note    = rule.note or listName,
        pruned  = pruned,
        count   = 1,
    }
    unknownSpellSeen[key] = entry

    local entries = APLEngine.unknownSpells
    entries[#entries + 1] = entry
end

---Delete every rule with an unresolvable spellID from one action list.
---从一个 action list 中删除所有 spellID 无法解析的规则。
---@param specID number|nil
---@param visited table<table, boolean>  guards aliased profiles (annihilator == default)
---@param actionList table|nil
---@param listName string
---@return number removed
local function pruneActionList(specID, visited, actionList, listName)
    if type(actionList) ~= "table" or visited[actionList] then
        return 0
    end
    visited[actionList] = true

    local removed = 0
    for i = #actionList, 1, -1 do
        local rule = actionList[i]
        if type(rule) == "table" and rule.spellID and not spellExists(rule.spellID) then
            recordUnknownSpell(specID, listName, rule, true)
            table.remove(actionList, i)
            removed = removed + 1
        end
    end
    return removed
end

---Flag (but do not delete) unresolvable spellIDs in an index-sensitive list.
---The opener is walked by array index while its entries carry an explicit `step`
---field; deleting an entry would desynchronise the two. PredictNext() consults
---unknownSpellIDs to skip these at runtime instead.
---标记（但不删除）位置敏感列表中无法解析的 spellID。
---opener 按数组下标遍历，条目里又带着显式的 `step` 字段，删除会让两者错位。
---改由 PredictNext() 在运行时查 unknownSpellIDs 跳过。
---@param specID number|nil
---@param visited table<table, boolean>
---@param actionList table|nil
---@param listName string
---@return number flagged
local function flagActionList(specID, visited, actionList, listName)
    if type(actionList) ~= "table" or visited[actionList] then
        return 0
    end
    visited[actionList] = true

    local flagged = 0
    for i = 1, #actionList do
        local entry = actionList[i]
        if type(entry) == "table" and entry.spellID and not spellExists(entry.spellID) then
            recordUnknownSpell(specID, listName, entry, false)
            flagged = flagged + 1
        end
    end
    return flagged
end

---Walk an APL definition and remove/flag every rule whose spellID this client
---cannot resolve. Returns how many diagnostics this call added.
---遍历 APL 定义，剔除/标记所有本客户端无法解析 spellID 的规则，返回新增诊断条数。
---@param specID number|nil
---@param aplData table
---@return number added
local function pruneUnknownSpells(specID, aplData)
    local before = #APLEngine.unknownSpells
    local visited = {}

    local function pruneProfile(profileName, profile)
        if type(profile) ~= "table" then return end
        pruneActionList(specID, visited, profile.singleTarget, profileName .. "/singleTarget")
        pruneActionList(specID, visited, profile.aoe, profileName .. "/aoe")
        if type(profile.voidMeta) == "table" then
            -- voidMeta is either a plain action list or a { singleTarget = {...} }
            -- wrapper; the inert call is a no-op for whichever shape it is not.
            -- voidMeta 可能是纯规则列表，也可能是 { singleTarget = {...} } 包装；
            -- 不匹配的那次调用会自然空转。
            pruneActionList(specID, visited, profile.voidMeta.singleTarget, profileName .. "/voidMeta")
            pruneActionList(specID, visited, profile.voidMeta, profileName .. "/voidMeta")
        end
        flagActionList(specID, visited, profile.opener, profileName .. "/opener")
        flagActionList(specID, visited, profile.majorCooldowns, profileName .. "/majorCooldowns")
    end

    if type(aplData.profiles) == "table" then
        -- "default" first, so an alias (Devourer's profiles.annihilator IS
        -- profiles.default) never gets to claim the list name in the report.
        -- pairs() order is undefined; this keeps `/ra aplcheck` output stable.
        -- 先走 "default"：别名（吞噬者的 profiles.annihilator 就是 profiles.default）
        -- 不会抢走报告里的 list 名。pairs() 顺序未定义，这样能让输出稳定。
        pruneProfile("default", aplData.profiles["default"])
        for profileName, profile in pairs(aplData.profiles) do
            if profileName ~= "default" then
                pruneProfile(profileName, profile)
            end
        end
    end

    -- Phase 1 backward-compat flat rule list
    pruneActionList(specID, visited, aplData.rules, "rules")

    return #APLEngine.unknownSpells - before
end

------------------------------------------------------------------------
-- Condition Evaluator (retained from Phase 2)
-- シミュレーション状態に対して条件を評価する
------------------------------------------------------------------------

---Evaluate a single condition string against a simulation state.
---@param condition string   e.g. "cd_ready AND not_in_meta"
---@param spellID  number
---@param simState table     Simulated state: { cooldowns, resource, inMeta, lastCast }
---@return boolean passes
function APLEngine:EvaluateCondition(condition, spellID, simState)
    if not condition or condition == "always" then
        return true
    end

    local tokens = splitConditions(condition)

    for _, cond in ipairs(tokens) do
        cond = trim(cond)
        local pass = false

        if cond == "cd_ready" or cond == "ready" then
            local cd = simState.cooldowns[spellID]
            local charges = simState.charges and simState.charges[spellID]
            -- A remaining charge is castable while another charge recharges.
            -- 有剩余充能时，即使另一层正在恢复，也仍可施放。
            if charges ~= nil then
                pass = charges > 0
            elseif simState.cooldownUnknown and simState.cooldownUnknown[spellID] then
                pass = false
            else
                pass = not cd or cd <= 0
            end

        elseif cond == "always" then
            pass = true

        elseif cond:match("^cd_soon:(%d+%.?%d*)$") then
            local t = tonumber(cond:match("^cd_soon:(%d+%.?%d*)$")) or 0
            local cd = simState.cooldowns[spellID] or 0
            pass = cd <= t

        elseif cond:match("^after:(%d+)$") then
            local afterID = tonumber(cond:match("^after:(%d+)$"))
            pass = (simState.lastCast == afterID)

        elseif cond:match("^not_after:(%d+)$") then
            local afterID = tonumber(cond:match("^not_after:(%d+)$"))
            pass = simState.lastCast ~= afterID

        elseif cond:match("^estimated_resource") then
            local op, value = parseNumericCondition(cond, "estimated_resource")
            if op and value and type(simState.resource) == "number" then
                pass = compareNumber(simState.resource, op, value)
            end

        elseif cond:match("^target_count") then
            local op, value = parseNumericCondition(cond, "target_count")
            if op and value then
                if simState.targetCountKnown ~= false or op == ">=" or op == ">" then
                    pass = compareNumber(simState.targetCount or 1, op, value)
                end
            else
                pass = true
            end

        elseif cond:match("^combat_time") then
            local op, value = parseNumericCondition(cond, "combat_time")
            if op and value then
                pass = compareNumber(simState.combatDuration or 0, op, value)
            else
                pass = true
            end

        elseif cond:match("^charges") then
            local op, value = parseNumericCondition(cond, "charges")
            local charges = simState.charges and simState.charges[spellID]
            if op and value and charges ~= nil then
                -- The predictor copies only public numeric counts before evaluation.
                -- 预测器在评估前只复制可读取的数值充能。
                pass = compareNumber(charges, op, value)
            end

        elseif cond:match("^window:") then
            local windowKey = cond:match("^window:(.+)$")
            pass = not (simState.windowUnknown and simState.windowUnknown[windowKey])
                and simState.windows and simState.windows[windowKey] == true

        elseif cond:match("^not_window:") then
            local windowKey = cond:match("^not_window:(.+)$")
            pass = not (simState.windowUnknown and simState.windowUnknown[windowKey])
                and not (simState.windows and simState.windows[windowKey] == true)

        elseif cond == "not_in_meta" then
            pass = simState.inMetaKnown ~= false and not simState.inMeta

        elseif cond == "in_meta" then
            pass = simState.inMetaKnown ~= false and simState.inMeta == true

        else
            pass = false
        end

        if not pass then
            return false
        end
    end
    return true
end

------------------------------------------------------------------------
-- Simulation Engine
-- シミュレーションエンジン: 1回のキャスト結果を模擬する
------------------------------------------------------------------------

---Simulate casting a spell: update cooldowns, deduct/gain resource.
---@param simState table  Mutable simulation state
---@param spellID  number The spell being cast
---@return table simState  The updated state (same table, mutated)
function APLEngine:SimulateSpellCast(simState, spellID)
    tickWindowState(simState)

    if simState.charges and simState.charges[spellID] ~= nil then
        simState.charges[spellID] = math.max(0, simState.charges[spellID] - 1)
        local recharge = simState.chargeRecharges and simState.chargeRecharges[spellID]
        if recharge and recharge.remaining <= 0 and recharge.duration > 0
           and simState.charges[spellID] < recharge.max then
            recharge.remaining = recharge.duration
        end
    end

    -- FIX (OverridePair): 降低 CD 阈值从 ≥8s 到 ≥3s，以正确模拟 Blade Dance/Death Sweep 等短 CD
    -- FIX (OverridePair): Lower threshold from ≥8s to ≥3s for proper short-CD simulation.
    -- Also set simulated CD on the paired override ID.
    -- 同时对覆盖对技能设置模拟 CD。
    local pairedID = RA.KNOWN_OVERRIDE_PAIRS and RA.KNOWN_OVERRIDE_PAIRS[spellID]
    local wsData = RA.WhitelistSpells and (RA.WhitelistSpells[spellID]
        or (pairedID and RA.WhitelistSpells[pairedID]))
    if wsData and wsData.cdSeconds and wsData.cdSeconds >= 3 then
        simState.cooldowns[spellID] = wsData.cdSeconds
        if simState.cooldownUnknown then simState.cooldownUnknown[spellID] = nil end
        -- FIX (OverridePair): mirror sim CD to paired spell
        if pairedID then
            simState.cooldowns[pairedID] = wsData.cdSeconds
            if simState.cooldownUnknown then simState.cooldownUnknown[pairedID] = nil end
        end
    end

    -- Apply resource cost/gen from SpecEnhancements
    local enhData = currentSpecID and RA.SpecEnhancements and RA.SpecEnhancements[currentSpecID]
    if enhData and enhData.resource and enhData.resource.spellCosts then
        local costData = enhData.resource.spellCosts[spellID]
            or (pairedID and enhData.resource.spellCosts[pairedID])
        if costData and not issecretvalue(simState.resource)
           and type(simState.resource) == "number" then
            local observedResource = simState.resource
            if costData.cost then
                simState.resource = (simState.resource or 0) - costData.cost
                if simState.resource < 0 then simState.resource = 0 end
            end
            if costData.gen then
                simState.resource = (simState.resource or 0) + costData.gen
                local maxRes = simState.resourceMax
                if issecretvalue(maxRes) or type(maxRes) ~= "number"
                   or maxRes ~= maxRes or maxRes <= 0 or maxRes >= math.huge
                   or maxRes < observedResource then
                    -- Static base is only an approximation when the public cap
                    -- is unavailable. Never lower an already observed resource.
                    -- 无公开上限时静态基础值仅是近似；不降低已观测资源。
                    maxRes = math.max(enhData.resource.maxBase or 100, observedResource)
                end
                if simState.resource > maxRes then simState.resource = maxRes end
            end
        end
    end

    local transitions = RA:GetModule("TalentTransitions")
    local handled = transitions and transitions:Apply(simState, currentSpecID, spellID)
    if not handled and META_SPELL_IDS[spellID] then
        simState.inMeta = true
        simState.inMetaKnown = true
        simState.metaRemains = META_SPELL_IDS[spellID]
    end

    local triggeredWindow = WINDOW_TRIGGER_SPELLS[spellID]
    if triggeredWindow and not handled then
        setWindowState(simState, triggeredWindow, true)
    end

    simState.lastCast = spellID
    return simState
end

---Advance the simulated horizon after a cast. A public GCD duration is used
---when supplied; 1.5 s is an approximation otherwise. Known base cast time
---may lengthen the horizon, but does not establish haste-adjusted cast time.
---施法后推进模拟时间。优先使用可读取的 GCD；否则以 1.5 秒近似。
local function advancePredictionTime(simState, spellID)
    local elapsed = simState.gcdDuration
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
        if ok and type(info) == "table" then
            local castTime = info.castTime
            if not issecretvalue(castTime) and type(castTime) == "number"
               and castTime > elapsed * 1000 then
                elapsed = castTime / 1000
            end
        end
    end

    for id, remaining in pairs(simState.cooldowns) do
        if type(remaining) == "number" then
            simState.cooldowns[id] = math.max(0, remaining - elapsed)
        end
    end
    for id, recharge in pairs(simState.chargeRecharges) do
        local count = simState.charges[id]
        if count and count < recharge.max and recharge.duration > 0 and recharge.remaining > 0 then
            recharge.remaining = recharge.remaining - elapsed
            while recharge.remaining <= 0 and count < recharge.max do
                count = count + 1
                recharge.remaining = recharge.remaining + recharge.duration
            end
            simState.charges[id] = count
            if count >= recharge.max then recharge.remaining = 0 end
        end
    end
    for key, remaining in pairs(simState.windowRemains or {}) do
        simState.windowRemains[key] = math.max(0, remaining - elapsed)
        if simState.windowRemains[key] <= 0 then
            if key == "demonic" and simState.metaExpiryUncertain then
                simState.windows[key] = nil
                simState.windowUnknown[key] = true
            else simState.windows[key] = false end
        end
    end
    if simState.metaRemains then
        simState.metaRemains = math.max(0, simState.metaRemains - elapsed)
        if simState.metaRemains <= 0 then
            if simState.metaExpiryUncertain then simState.inMetaKnown = false
            else simState.inMeta = false end
        end
    end
    simState.combatDuration = (simState.combatDuration or 0) + elapsed
end

---Reject a future action only when observable or simulated state proves it
---unavailable. Unknown resource/CD facts are not invented.
---仅在可观测或已模拟的状态证明技能不可用时拒绝；不编造未知资源与冷却事实。
local function canCastAtHorizon(simState, spellID)
    if simState.spellRange and simState.spellRange[spellID] == false then return false end
    local charges = simState.charges[spellID]
    if charges ~= nil then
        if charges <= 0 then return false end
    elseif simState.cooldownUnknown[spellID] then
        return false
    else
        local cooldown = simState.cooldowns[spellID]
        if cooldown and cooldown > 0 then return false end
    end

    local enhancement = currentSpecID and RA.SpecEnhancements and RA.SpecEnhancements[currentSpecID]
    local costs = enhancement and enhancement.resource and enhancement.resource.spellCosts
    local pairedID = RA.KNOWN_OVERRIDE_PAIRS and RA.KNOWN_OVERRIDE_PAIRS[spellID]
    local costData = costs and (costs[spellID] or (pairedID and costs[pairedID]))
    local cost = costData and costData.cost
    if type(cost) == "number" and cost > 0 then
        -- A declared spender cannot be validated from a secret/unknown resource.
        -- 已声明的消耗技能在资源 secret/未知时不能通过预测验证。
        if type(simState.resource) ~= "number" or simState.resource < cost then
            return false
        end
    end
    return true
end

------------------------------------------------------------------------
-- Prediction: PredictNext()
-- 予測: Blizzardの推薦スペルから次の2ステップを予測する
------------------------------------------------------------------------

---Get the action list for the current profile and context.
---@param simState table
---@return table|nil actionList
local function getActionList(simState)
    if not currentAPL then return nil end

    if currentAPL.profiles then
        local profile = currentAPL.profiles[currentProfileName]
                     or currentAPL.profiles["default"]
        if profile then
            -- Devourer dual-phase
            if currentClassID == 12 and currentSpecID == 1480
                    and profile.voidMeta and simState.inMeta then
                return profile.voidMeta.singleTarget or profile.voidMeta
            end
            if simState.targetCount and simState.targetCount >= 3 and profile.aoe then
                return profile.aoe
            end
            return profile.singleTarget
        end
    end
    -- Phase 1 fallback
    return currentAPL.rules
end

---Predict the next N steps from a given starting spell.
---Slot 1 is always the Blizzard recommendation (not produced here).
---This returns steps 2..depth+1 for the UI.
---@param currentSpellID number|nil  The spell Blizzard is recommending NOW
---@param limitedState   table|nil   Observable state: { resource, cooldowns, inMeta, targetCount }
---@param depth          number      How many steps ahead to predict (default 2)
---@return table[] predictions  Array of { spellID, confidence, source, note }
function APLEngine:PredictNext(currentSpellID, limitedState, depth)
    depth = depth or 2

    -- limitedState is still required for simulation; return early only if missing.
    -- currentSpellID may be nil (no Blizzard recommendation) — prediction continues from APL top.
    -- limitedState は必須。currentSpellID が nil の場合は APL 先頭から予測する。
    if not limitedState then return {} end
    if limitedState.targetValid == false then return {} end

    if not currentAPL then return {} end

    -- Build an isolated simulation state. PredictNext is read-only with respect to
    -- its caller, including nested cooldown, charge and window tables.
    -- 构造独立模拟状态；PredictNext 不修改调用方及其嵌套冷却/充能/窗口表。
    local resource = limitedState.resource
    if limitedState.resourceKnown == false or issecretvalue(resource)
       or type(resource) ~= "number" then
        resource = nil
    end
    local resourceMax = limitedState.resourceMax
    if issecretvalue(resourceMax) or type(resourceMax) ~= "number"
       or resourceMax ~= resourceMax or resourceMax <= 0 or resourceMax >= math.huge
       or (resource and resourceMax < resource) then
        resourceMax = nil
    end
    local gcdDuration = limitedState.gcdDuration
    if issecretvalue(gcdDuration) or type(gcdDuration) ~= "number"
       or gcdDuration < 0.75 or gcdDuration > 1.5 then
        gcdDuration = 1.5
    end
    local inMeta = metaActive
    if not issecretvalue(limitedState.inMeta)
       and type(limitedState.inMeta) == "boolean" then
        inMeta = limitedState.inMeta
    end
    local targetCount = limitedState.targetCount
    if issecretvalue(targetCount) or type(targetCount) ~= "number" then targetCount = 1 end
    local combatDuration = limitedState.combatDuration
    if issecretvalue(combatDuration) or type(combatDuration) ~= "number" then
        combatDuration = 0
    end
    local simState = {
        cooldowns   = {},
        cooldownUnknown = {},
        resource    = resource,
        resourceMax = resourceMax,
        gcdDuration = gcdDuration,
        inMeta      = inMeta,
        inMetaKnown = limitedState.inMetaKnown ~= false,
        lastCast    = nil,
        targetCount = targetCount,
        targetCountKnown = limitedState.targetCountKnown ~= false,
        combatDuration = combatDuration,
        charges = {},
        chargeRecharges = {},
        windows = {},
        windowSteps = {},
        windowUnknown = {},
        windowRemains = {},
        spellRange = {},
    }
    for id, value in pairs(limitedState.spellRange or {}) do
        if not issecretvalue(value) and type(value) == "boolean" then
            simState.spellRange[id] = value
            local pair = RA.KNOWN_OVERRIDE_PAIRS and RA.KNOWN_OVERRIDE_PAIRS[id]
            if pair and value == false then simState.spellRange[pair] = false end
        end
    end
    -- A form pair's explicit out-of-range value must win independent of key order.
    -- 变身技能的明确超距结果不受遍历顺序影响。
    for id, value in pairs(limitedState.spellRange or {}) do
        if not issecretvalue(value) and value == false then
            simState.spellRange[id] = false
            local pair = RA.KNOWN_OVERRIDE_PAIRS and RA.KNOWN_OVERRIDE_PAIRS[id]
            if pair then simState.spellRange[pair] = false end
        end
    end
    for key, unknown in pairs(limitedState.windowUnknown or {}) do
        if not issecretvalue(unknown) and unknown == true then simState.windowUnknown[key] = true end
    end
    for key, remaining in pairs(limitedState.windowRemains or {}) do
        if not issecretvalue(remaining) and type(remaining) == "number"
           and remaining >= 0 and remaining < math.huge then
            simState.windowRemains[key] = remaining
        end
    end
    local metaRemains = limitedState.metaRemains
    if not issecretvalue(metaRemains) and type(metaRemains) == "number"
       and metaRemains >= 0 and metaRemains < math.huge then
        simState.metaRemains = metaRemains
    end
    -- Copy cooldown data into simState
    if limitedState.cooldowns then
        for spellID, val in pairs(limitedState.cooldowns) do
            if not issecretvalue(val) and type(val) == "table" then
                val = val.remaining
            end
            if not issecretvalue(val) and type(val) == "number" then
                simState.cooldowns[spellID] = val
            end
        end
    end

    if limitedState.charges then
        for spellID, count in pairs(limitedState.charges) do
            if not issecretvalue(count) and type(count) == "number" then
                simState.charges[spellID] = count
            end
        end
    end

    if limitedState.cooldownUnknown then
        for spellID, unknown in pairs(limitedState.cooldownUnknown) do
            if not issecretvalue(unknown) and unknown == true then
                simState.cooldownUnknown[spellID] = true
            end
        end
    end
    if limitedState.chargeRecharges then
        for spellID, recharge in pairs(limitedState.chargeRecharges) do
            if type(recharge) == "table" and simState.charges[spellID] ~= nil then
                local maximum, remaining, duration = recharge.max, recharge.remaining, recharge.duration
                if not issecretvalue(maximum) and not issecretvalue(remaining)
                   and not issecretvalue(duration) and type(maximum) == "number"
                   and type(remaining) == "number" and type(duration) == "number"
                   and maximum >= simState.charges[spellID] and maximum > 0
                   and remaining >= 0 and duration > 0 then
                    simState.chargeRecharges[spellID] = {
                        max = maximum, remaining = remaining, duration = duration,
                    }
                end
            end
        end
    end

    if limitedState.windows then
        for windowKey, active in pairs(limitedState.windows) do
            if active == true then
                simState.windows[windowKey] = true
                simState.windowSteps[windowKey] = WINDOW_STEP_DURATIONS[windowKey] or 1
            end
        end
    end

    -- Simulate casting the current Blizzard recommendation first
    if currentSpellID then
        self:SimulateSpellCast(simState, currentSpellID)
        advancePredictionTime(simState, currentSpellID)
    end

    -- Now walk the APL to find the next `depth` spells
    local predictions = {}

    -- Opener mode: 战斗开始前6秒内使用预定义的起手序列
    -- opener 序列优先级高于常规 APL 规则
    -- Opener mode: use the predefined pull sequence within the first 6 s of combat.
    -- This takes priority over the regular APL rule walk.
    if not issecretvalue(limitedState.combatDuration)
       and type(limitedState.combatDuration) == "number"
       and limitedState.combatDuration < 6 then
        local openerSeq = nil
        if currentAPL and currentAPL.profiles then
            local profile = currentAPL.profiles[currentProfileName]
                         or currentAPL.profiles["default"]
            if profile and profile.opener then
                openerSeq = profile.opener
            end
        end

        if openerSeq then
            -- 根据当前 Blizzard 推荐（slot 1）判断我们在 opener 的哪一步
            -- Determine which opener step we have reached based on Blizzard's slot-1 spell.
            local startStep = 1
            if currentSpellID then
                for _, entry in ipairs(openerSeq) do
                    if entry.spellID == currentSpellID then
                        startStep = entry.step + 1
                        break
                    end
                end
            end

            -- 从 startStep 开始填充预测（最多 depth 步）
            -- Fill predictions starting from startStep, up to depth entries.
            for i = startStep, #openerSeq do
                if #predictions >= depth then break end
                local entry = openerSeq[i]
                -- Skip spells the player hasn't learned (e.g. untalented Essence Break),
                -- and spellIDs this client could not resolve at all. Opener entries are
                -- step-indexed, so pruneUnknownSpells() only flags them (see D-015) —
                -- this is where they are actually skipped.
                -- 跳过未学习的技能（如未天赋的精华爆裂），以及本客户端根本解析不出来的 spellID。
                -- opener 按 step 索引，pruneUnknownSpells() 只做标记（见 D-015），实际跳过在这里。
                local known = false
                if entry and type(entry.spellID) == "number" and not unknownSpellIDs[entry.spellID] then
                    if not IsPlayerSpell then
                        known = true
                    else
                        local okKnown, isKnown = pcall(IsPlayerSpell, entry.spellID)
                        known = okKnown and isKnown == true
                    end
                end
                -- An unknown/unlearned opener entry can be skipped, preserving the
                -- existing load-time pruning behaviour. A known action that is on CD
                -- or unaffordable breaks the scripted chain; the normal APL then
                -- chooses from the current simulated state.
                -- 未知/未学习的起手项可跳过；已知项若冷却或资源不足则中断预设链，
                -- 由常规 APL 基于当前模拟状态重新选择。
                if known and not canCastAtHorizon(simState, entry.spellID) then
                    break
                end
                local passive = known and (PASSIVE_BLACKLIST[entry.spellID]
                    or (RA.IsSpellPassive and RA:IsSpellPassive(entry.spellID)))
                if known and not passive then
                    predictions[#predictions + 1] = {
                        spellID    = entry.spellID,
                        confidence = math.max(0.7, 0.95 - (i - startStep) * 0.1),
                        source     = "apl_opener",
                        note       = entry.note or ("Opener step " .. i),
                    }
                    self:SimulateSpellCast(simState, entry.spellID)
                    advancePredictionTime(simState, entry.spellID)
                end
            end

        end
    end

    -- If the scripted opener ends early, continue from its simulated result.
    -- 起手序列提前结束时，从已模拟的状态继续常规 APL。
    if #predictions < depth then
        for step = #predictions + 1, depth do
            local actionList = getActionList(simState)
            if not actionList then break end
            -- FIX (Perf): build the step-note string ONCE per outer loop iteration,
            -- not once per rule in the inner loop, to avoid repeated string allocation.
            local stepNote = "APL prediction step " .. step

            local found = false
            for _, rule in ipairs(actionList) do
                -- 跳过未学习的天赋技能 / Skip unlearned talent spells
                local notKnown = false
                if IsPlayerSpell then
                    local okKnown, known = pcall(IsPlayerSpell, rule.spellID)
                    notKnown = not okKnown or known ~= true
                end
                -- Step 1 only: soft-block guard — suppress recently-cast spells until
                -- SPELL_UPDATE_COOLDOWN confirms the real CD has started.
                -- 仅第一步：软屏蔽守卫，抑制刚施放的技能直到 SPELL_UPDATE_COOLDOWN 确认真实 CD
                local isSoftBlocked = false
                if step == 1 and limitedState.softBlocked then
                    local blockExpiry = limitedState.softBlocked[rule.spellID]
                    if blockExpiry and GetTime() < blockExpiry then
                        isSoftBlocked = true
                    end
                end

                -- Skip passive spells (e.g. Demon Blades 203555)
                -- 跳过被动技能（如恶魔之刃 203555）
                local isPassive = PASSIVE_BLACKLIST[rule.spellID] or (RA.IsSpellPassive and RA:IsSpellPassive(rule.spellID))

                -- 【新增】覆盖型被动检测：防止天赋覆盖变成被动（如 丝缕交织）
                local isOverriddenPassive = false
                if not isPassive and RA.ResolveSpellOverride then
                    local resolved, wasOvr = RA:ResolveSpellOverride(rule.spellID)
                    if wasOvr and RA:IsSpellPassive(resolved) then
                        isOverriddenPassive = true
                    end
                end

                if not notKnown and not isPassive and not isOverriddenPassive and not isSoftBlocked
                   and canCastAtHorizon(simState, rule.spellID)
                   and self:EvaluateCondition(rule.condition, rule.spellID, simState) then
                    -- Confidence degrades with depth
                    local conf = math.max(0.5, 0.9 - (step - 1) * 0.2)

                    predictions[#predictions + 1] = {
                        spellID    = rule.spellID,
                        confidence = rule.confidence and math.min(rule.confidence, conf) or conf,
                        source     = "apl_predict",
                        note       = rule.note or stepNote,
                    }

                    -- Advance the simulation state
                    self:SimulateSpellCast(simState, rule.spellID)
                    advancePredictionTime(simState, rule.spellID)
                    found = true
                    break
                end
            end
            if not found then break end  -- no more valid spells
        end
    end

    return predictions
end

------------------------------------------------------------------------
-- Module Lifecycle
------------------------------------------------------------------------

function APLEngine:OnInitialize() end
function APLEngine:OnEnable()
    local events = RA:GetModule("EventHandler")
    if events then events:Subscribe("ROTAASSIST_CHARACTER_CHANGED", "APLEngine", function()
        metaActive, metaExpireTime = false, 0
        self:RefreshProfileFromTalents()
    end) end
end
function APLEngine:OnDisable()
    local events = RA:GetModule("EventHandler")
    if events then events:UnsubscribeAll("APLEngine") end
end

------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------

---Called by SpecDetector when a new spec loads or changes.
---@param specID  number
---@param aplData table  From RA.APLData[specID]
---@param classID number|nil
function APLEngine:SetAPL(specID, aplData, classID)
    currentSpecID      = specID
    currentClassID     = classID
    currentAPL         = aplData
    metaActive         = false
    currentProfileName = resolveProfileFromTalents(aplData)

    -- 预排序所有 action lists
    if aplData and aplData.profiles then
        for _, profile in pairs(aplData.profiles) do
            if profile.singleTarget then
                table.sort(profile.singleTarget, function(a,b) return (a.priority or 999) < (b.priority or 999) end)
            end
            if profile.aoe then
                table.sort(profile.aoe, function(a,b) return (a.priority or 999) < (b.priority or 999) end)
            end
        end
    end
    if aplData and aplData.rules then
        table.sort(aplData.rules, function(a,b) return (a.priority or 999) < (b.priority or 999) end)
    end

    -- Validate the condition vocabulary once per spec. Load-time only: this walks
    -- every rule and allocates, so it must never be reached from the OnUpdate path.
    -- 每个专精只在加载期校验一次条件词汇。仅加载期：它会遍历所有规则并分配内存，
    -- 绝不允许从 OnUpdate 路径进入。
    if aplData and specID and not validatedSpecs[specID] then
        validatedSpecs[specID] = true

        -- Prune first: a rule whose spell does not exist is gone, so there is no
        -- point reporting its condition tokens as well. (D-015)
        -- 先剔除：技能都不存在的规则已经被删掉，没必要再报它的条件 token。（D-015）
        local unknownAdded = pruneUnknownSpells(specID, aplData)
        if unknownAdded > 0 then
            RA:PrintWarning(string.format(
                "APLEngine: specID %d references %d spellID(s) unknown to this client — those rules are disabled. /ra aplcheck",
                specID, unknownAdded))
        end

        local before = #APLEngine.invalidRules
        validateAPLConditions(specID, aplData)
        local added = #APLEngine.invalidRules - before
        if added > 0 then
            RA:PrintWarning(string.format(
                "APLEngine: specID %d has %d rule(s) with unsupported conditions — /ra aplcheck",
                specID, added))
        end
    end

    RA:PrintDebug(string.format("APLEngine: Loaded APL for specID %d classID %s",
        specID, tostring(classID)))
end

local LIST_CAP = 40

---Print the unknown-spellID section of `/ra aplcheck` (D-015).
---打印 `/ra aplcheck` 的未知 spellID 一节（D-015）。
local function printUnknownSpellReport()
    local entries = APLEngine.unknownSpells
    local total = #entries

    if total == 0 then
        RA:Print("APL spellID check: every loaded rule resolves against this client.")
        RA:Print("APL spellID 校验：已加载规则的技能 ID 在本客户端全部可解析。")
        return
    end

    RA:PrintWarning(string.format(
        "APL spellID check: %d spellID(s) do not exist on this client.", total))
    RA:PrintWarning(string.format(
        "APL spellID 校验：%d 个 spellID 在本客户端不存在。", total))

    local shown = math.min(total, LIST_CAP)
    for i = 1, shown do
        local e = entries[i]
        RA:Print(string.format("  [spec %s] spell %s  %s  x%d rule(s)  list=%s  note=\"%s\"",
            tostring(e.specID), tostring(e.spellID),
            e.pruned and "removed" or "skipped",
            tonumber(e.count) or 1, tostring(e.list), tostring(e.note)))
    end
    if total > shown then
        RA:Print(string.format("  ... %d more entr(ies) not shown / ... 另有 %d 条未显示",
            total - shown, total - shown))
    end

    RA:Print("Devourer spellIDs are datamined placeholders (D-015) — unresolvable rules never fire.")
    RA:Print("吞噬者的 spellID 是数据挖掘占位值（D-015）—— 解析不出来的规则永远不会触发。")
end

---Print the load-time condition-validation report. Backs `/ra aplcheck`.
---打印加载期条件校验报告。为 `/ra aplcheck` 提供数据。
function APLEngine:PrintConditionReport()
    printUnknownSpellReport()

    local entries = self.invalidRules
    local total = #entries

    if total == 0 then
        RA:Print("APL condition check: all loaded rules use supported tokens.")
        RA:Print("APL 条件校验：已加载规则的 token 全部受支持。")
        return
    end

    RA:PrintWarning(string.format(
        "APL condition check: %d rule(s) use unsupported tokens and can never fire.", total))
    RA:PrintWarning(string.format(
        "APL 条件校验：%d 条规则使用了不支持的 token，永远不会触发。", total))

    local shown = math.min(total, LIST_CAP)
    for i = 1, shown do
        local e = entries[i]
        RA:Print(string.format("  [spec %s] %s  spell %s  token=%s  cond=\"%s\"",
            tostring(e.specID), tostring(e.list), tostring(e.spellID),
            tostring(e.token), tostring(e.condition)))
    end
    if total > shown then
        RA:Print(string.format("  ... %d more entr(ies) not shown / ... 另有 %d 条未显示", total - shown, total - shown))
    end

    RA:Print("Unsupported tokens are intentional: buff:/debuff:/cp/target_hp need secret combat data.")
    RA:Print("不支持的 token 是有意为之：buff:/debuff:/cp/target_hp 依赖 secret 战斗数据，模拟器只能猜。")
end

---Re-evaluate the active profile based on the player's current talents.
---@return string profileName
function APLEngine:RefreshProfileFromTalents()
    if not currentAPL then
        currentProfileName = "default"
        return currentProfileName
    end
    currentProfileName = resolveProfileFromTalents(currentAPL)
    return currentProfileName
end

---Notify the engine of Metamorphosis state.
---@param active boolean
function APLEngine:SetMetaState(active)
    metaActive = active == true
end

---@return boolean
function APLEngine:IsMetaActive()
    return metaActive
end

-- Havoc Metamorphosis (191427) and Devourer Void Eruption (198013) active durations
META_SPELL_IDS = {
    [191427] = 24,
    [198013] = 8,
    [187827] = 15,  -- Vengeance Metamorphosis
    [442508] = 20,  -- Devourer Void Metamorphosis
}

WINDOW_TRIGGER_SPELLS = {
    [198013] = "demonic",
    [191427] = "demonic",
    [258860] = "essence_break",
}

WINDOW_STEP_DURATIONS = {
    demonic = 4,
    essence_break = 2,
}

---Auto-activate meta state when the player casts a meta-trigger spell,
---then deactivate after the spell duration elapses.
---@param spellID number
function APLEngine:SetMetaStateFromCast(spellID)
    local duration = META_SPELL_IDS[spellID]
    local transitions = RA:GetModule("TalentTransitions")
    if transitions then
        local handled, observedDuration = transitions:GetDuration(currentSpecID, spellID)
        if handled then duration = observedDuration end
    end
    if duration == 0 then return end
    if not duration then return end
    metaActive = true
    local newExpiry = GetTime() + duration
    -- Only update if this extends the current meta window
    if newExpiry > metaExpireTime then
        metaExpireTime = newExpiry
    end
    C_Timer.After(duration, function()
        -- Only deactivate if no newer meta has extended the window
        if GetTime() >= metaExpireTime then
            metaActive = false
        end
    end)
end

---Set the active profile.
---@param profileName string
function APLEngine:SetProfile(profileName)
    currentProfileName = profileName or "default"
end

---@return string
function APLEngine:GetProfileName()
    return currentProfileName or "default"
end

---@return table|nil
function APLEngine:GetCurrentAPL()
    return currentAPL
end

---@return boolean
function APLEngine:HasAPL()
    return currentAPL ~= nil
end

function APLEngine:ClearAPL()
    currentAPL    = nil
    currentSpecID = nil
end
