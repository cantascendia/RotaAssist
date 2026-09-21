-- Evaluate an independent priority policy over explicit public facts.
-- 独立规则决策：未知条件不等于失败，不能悄悄越过可能更优的前项。
local _, NS = ...
local RA = NS.RA
local Decision = {}
RA:RegisterModule("IndependentDecision", Decision)

local operators = {
    [">"] = function(a,b) return a > b end, [">="] = function(a,b) return a >= b end,
    ["<"] = function(a,b) return a < b end, ["<="] = function(a,b) return a <= b end,
    ["=="] = function(a,b) return a == b end,
}
local missingSet, candidateSet, ruleMissing, empty = {}, {}, {}, {}
local result = { status = "unavailable", candidates = {}, missing = {} }
local snapshotKeys = { "facts", "known", "ready", "charges", "bounds" }

local function public(v)
    return not (issecretvalue and issecretvalue(v))
end
local function number(v)
    if not public(v) then return nil end
    if type(v) == "boolean" then return v and 1 or 0 end
    if type(v) == "number" and v == v and math.abs(v) < math.huge then return v end
end
local function flag(v)
    if public(v) and type(v) == "boolean" then return v end
end
local function bounded(bound, op, value)
    if type(bound) ~= "table" then return nil end
    local lo, hi = number(bound.min), number(bound.max)
    if lo and hi and lo > hi then return nil end
    if op == ">=" then
        if lo and lo >= value then return true end
        if hi and hi < value then return false end
    elseif op == ">" then
        if lo and lo > value then return true end
        if hi and hi <= value then return false end
    elseif op == "<=" then
        if hi and hi <= value then return true end
        if lo and lo > value then return false end
    elseif op == "<" then
        if hi and hi < value then return true end
        if lo and lo >= value then return false end
    elseif op == "==" then
        if lo and hi and lo == hi and lo == value then return true end
        if (lo and lo > value) or (hi and hi < value) then return false end
    end
end
local function missing(key)
    if not missingSet[key] then
        missingSet[key] = true
        result.missing[#result.missing + 1] = key
    end
end
local function candidate(id)
    if not candidateSet[id] then
        candidateSet[id] = true
        result.candidates[#result.candidates + 1] = id
    end
end

function Decision:Validate(policy)
    if type(policy) ~= "table" or policy.schema ~= "rotaassist.independent-policy.v1"
       or type(policy.rules) ~= "table" or #policy.rules < 1 or #policy.rules > 64 then
        return false, "invalid_policy"
    end
    for _, rule in ipairs(policy.rules) do
        if type(rule) ~= "table" or type(rule.spellID) ~= "number" or not number(rule.spellID) or rule.spellID <= 0
           or rule.spellID % 1 ~= 0 or type(rule.conditions) ~= "table"
           or #rule.conditions > 16 then return false, "invalid_rule" end
        if rule.form ~= nil and rule.form ~= "meta" and rule.form ~= "normal" then
            return false, "invalid_form"
        end
        for _, condition in ipairs(rule.conditions) do
            if type(condition) ~= "table" or #condition ~= 3
               or type(condition[1]) ~= "string" or not condition[1]:match("^[a-z_][a-z0-9_%.]*$")
               or not operators[condition[2]] or type(condition[3]) ~= "number" or not number(condition[3]) then
                return false, "invalid_condition"
            end
        end
    end
    return true
end

-- Borrowed result: callers copy fields they retain beyond the next evaluation.
-- 复用返回缓冲区；调用方若需跨次保存，应复制相关字段。
function Decision:Evaluate(policy, snapshot)
    result.spellID, result.ruleIndex, result.status = nil, nil, "unavailable"
    wipe(result.candidates); wipe(result.missing); wipe(missingSet); wipe(candidateSet)
    -- Bounded validation also detects edits to a previously evaluated policy.
    -- 有界检查同时防止已验证规则表被修改后绕过验证。
    local ok, reason = self:Validate(policy)
    if not ok then result.status = reason; return result end
    if type(snapshot) ~= "table" then result.status = "invalid_snapshot"; return result end
    for _, key in ipairs(snapshotKeys) do
        if snapshot[key] ~= nil and type(snapshot[key]) ~= "table" then
            result.status = "invalid_snapshot"; return result
        end
    end
    local facts = snapshot.facts or empty
    for index, rule in ipairs(policy.rules) do
        local id = rule.spellID
        local known = flag(snapshot.known and snapshot.known[id])
        local ready = flag(snapshot.ready and snapshot.ready[id])
        if known ~= false and ready ~= false then
            wipe(ruleMissing)
            local conditionResult = true
            for _, condition in ipairs(rule.conditions) do
                local field, op, value = condition[1], condition[2], condition[3]
                local actual
                if field == "charges" then actual = number(snapshot.charges and snapshot.charges[id])
                else actual = number(facts[field]) end
                local matches
                if actual ~= nil then matches = operators[op](actual, value)
                elseif snapshot.bounds then matches = bounded(snapshot.bounds[field], op, value) end
                if matches == nil then
                    conditionResult = nil
                    ruleMissing[#ruleMissing + 1] = field == "charges" and ("charges:" .. id) or field
                elseif not matches then
                    conditionResult = false
                    break
                end
            end
            if conditionResult ~= false and rule.form then
                local form = number(facts["buff.metamorphosis.up"])
                if form == nil then
                    conditionResult = nil
                    ruleMissing[#ruleMissing + 1] = "buff.metamorphosis.up"
                elseif (form > 0) ~= (rule.form == "meta") then conditionResult = false end
            end
            if conditionResult ~= false then
                for _, key in ipairs(ruleMissing) do missing(key) end
                if known == nil then missing("known:" .. id) end
                if ready == nil then missing("ready:" .. id) end
                candidate(id)
                if known == true and ready == true and conditionResult == true then
                    if #result.candidates == 1 then
                        result.status = "decided"
                        result.spellID, result.ruleIndex = id, index
                    else
                        result.status = "ambiguous"
                    end
                    return result
                end
            end
        end
    end
    result.status = #result.candidates > 0 and "ambiguous" or "wait"
    return result
end

function Decision:OnInitialize() end
function Decision:OnEnable() end
function Decision:OnDisable()
    result.spellID, result.ruleIndex = nil, nil
    result.status = "unavailable"
    wipe(result.candidates); wipe(result.missing)
end
