-- Replay independent SimC pre-action snapshots through the loaded APLEngine.
-- 以实际加载的 APLEngine 重放独立 SimC 轨迹；一致率不是 DPS 或实战正确率。
-- Usage: lua scripts/replay_havoc.lua trace.json [report.json] [--addon-root PATH]
package.path = "./?.lua;./?/init.lua;" .. package.path

local tracePath, reportPath, addonRoot = nil, nil, "addon"
local argument = 1
while arg and argument <= #arg do
    if arg[argument] == "--addon-root" then
        addonRoot = assert(arg[argument + 1], "--addon-root needs a path")
        argument = argument + 2
    elseif not tracePath then
        tracePath = arg[argument]
        argument = argument + 1
    elseif not reportPath then
        reportPath = arg[argument]
        argument = argument + 1
    else
        error("too many positional arguments")
    end
end
assert(tracePath, "usage: lua scripts/replay_havoc.lua trace.json [report.json] [--addon-root PATH]")
local JSON_NULL = {}

local function readFile(path)
    local file = assert(io.open(path, "rb"))
    local contents = assert(file:read("*a"))
    file:close()
    return contents
end

-- Small, dependency-free JSON reader for SimC's report; never execute report text.
-- 只解析 JSON，不执行轨迹内容。
local function decodeJSON(text)
    local position, length = 1, #text
    local function skipSpace()
        while position <= length and text:sub(position, position):match("%s") do
            position = position + 1
        end
    end
    local function utf8(codepoint)
        if codepoint < 0x80 then return string.char(codepoint) end
        if codepoint < 0x800 then
            return string.char(0xC0 + math.floor(codepoint / 64), 0x80 + codepoint % 64)
        end
        if codepoint < 0x10000 then
            return string.char(0xE0 + math.floor(codepoint / 4096),
                0x80 + math.floor(codepoint / 64) % 64, 0x80 + codepoint % 64)
        end
        return string.char(0xF0 + math.floor(codepoint / 262144),
            0x80 + math.floor(codepoint / 4096) % 64,
            0x80 + math.floor(codepoint / 64) % 64, 0x80 + codepoint % 64)
    end
    local function parseString()
        assert(text:sub(position, position) == '"', "expected JSON string")
        position = position + 1
        local result = {}
        while position <= length do
            local character = text:sub(position, position)
            position = position + 1
            if character == '"' then return table.concat(result) end
            if character == "\\" then
                local escape = text:sub(position, position)
                position = position + 1
                local substitutions = { ['"'] = '"', ['\\'] = '\\', ['/'] = '/',
                    b = '\b', f = '\f', n = '\n', r = '\r', t = '\t' }
                if escape == "u" then
                    local digits = text:sub(position, position + 3)
                    assert(digits:match("^%x%x%x%x$"), "invalid JSON unicode escape")
                    local codepoint = tonumber(digits, 16)
                    position = position + 4
                    if codepoint >= 0xD800 and codepoint <= 0xDBFF
                       and text:sub(position, position + 1) == "\\u" then
                        local low = tonumber(text:sub(position + 2, position + 5), 16)
                        if low and low >= 0xDC00 and low <= 0xDFFF then
                            codepoint = 0x10000 + (codepoint - 0xD800) * 1024 + low - 0xDC00
                            position = position + 6
                        end
                    end
                    result[#result + 1] = utf8(codepoint)
                else
                    assert(substitutions[escape], "invalid JSON string escape")
                    result[#result + 1] = substitutions[escape]
                end
            else
                assert(string.byte(character) >= 32, "unescaped JSON control character")
                result[#result + 1] = character
            end
        end
        error("unterminated JSON string")
    end
    local parseValue
    parseValue = function()
        skipSpace()
        local character = text:sub(position, position)
        if character == '"' then return parseString() end
        if character == "{" then
            position = position + 1
            local object = {}
            skipSpace()
            if text:sub(position, position) == "}" then position = position + 1; return object end
            while true do
                skipSpace()
                local key = parseString()
                skipSpace()
                assert(text:sub(position, position) == ":", "expected JSON colon")
                position = position + 1
                object[key] = parseValue()
                skipSpace()
                local separator = text:sub(position, position)
                position = position + 1
                if separator == "}" then return object end
                assert(separator == ",", "expected JSON object separator")
            end
        end
        if character == "[" then
            position = position + 1
            local array = {}
            skipSpace()
            if text:sub(position, position) == "]" then position = position + 1; return array end
            while true do
                array[#array + 1] = parseValue()
                skipSpace()
                local separator = text:sub(position, position)
                position = position + 1
                if separator == "]" then return array end
                assert(separator == ",", "expected JSON array separator")
            end
        end
        for literal, value in pairs({ ["true"] = true, ["false"] = false,
                                      ["null"] = JSON_NULL }) do
            if text:sub(position, position + #literal - 1) == literal then
                position = position + #literal
                return value
            end
        end
        local numeric = text:sub(position):match("^-?%d+%.?%d*[eE][+-]?%d+")
            or text:sub(position):match("^-?%d+%.?%d*")
        assert(numeric, "invalid JSON value at byte " .. position)
        position = position + #numeric
        return assert(tonumber(numeric), "invalid JSON number")
    end
    local decoded = parseValue()
    skipSpace()
    assert(position > length, "trailing JSON content")
    return decoded
end

local function encodeString(value)
    local escaped = value:gsub('[%z\1-\31\\"]', function(character)
        local byte = string.byte(character)
        if character == '"' then return '\\"' end
        if character == '\\' then return '\\\\' end
        if character == '\n' then return '\\n' end
        if character == '\r' then return '\\r' end
        if character == '\t' then return '\\t' end
        return string.format('\\u%04x', byte)
    end)
    return '"' .. escaped .. '"'
end
local function encodeJSON(value)
    if value == JSON_NULL or value == nil then return "null" end
    local kind = type(value)
    if kind == "string" then return encodeString(value) end
    if kind == "boolean" then return value and "true" or "false" end
    if kind == "number" then
        assert(value == value and value ~= math.huge and value ~= -math.huge)
        return string.format("%.17g", value)
    end
    assert(kind == "table", "unsupported report type " .. kind)
    local count, maximum, array = 0, 0, true
    for key in pairs(value) do
        count = count + 1
        if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then array = false
        elseif key > maximum then maximum = key end
    end
    if count == 0 then return "[]" end
    array = array and count > 0 and count == maximum
    local parts = {}
    if array then
        for index = 1, maximum do parts[#parts + 1] = encodeJSON(value[index]) end
        return "[" .. table.concat(parts, ",") .. "]"
    end
    local keys = {}
    for key in pairs(value) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for _, key in ipairs(keys) do
        parts[#parts + 1] = encodeString(tostring(key)) .. ":" .. encodeJSON(value[key])
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

local trace = decodeJSON(readFile(tracePath))
local sim = trace.sim or trace
local player = sim.players and sim.players[1]
local collected = player and player.collected_data
local rows = trace.action_sequence or sim.action_sequence
    or (collected and collected.action_sequence)
assert(type(rows) == "table", "trace has no action_sequence")

local helpers = require("tests.helpers")
local function loadAddonFile(relative, ns)
    local path = addonRoot .. "/" .. relative
    local chunk, err = loadfile(path)
    assert(chunk, path .. ": " .. tostring(err))
    local ok, runtimeError = pcall(chunk, "RotaAssist", ns)
    assert(ok, path .. ": " .. tostring(runtimeError))
end
helpers.ensureMockLoaded()
local ns = {}
loadAddonFile("Core/Init.lua", ns)
local RA = assert(ns.RA)
loadAddonFile("Data/Registry.lua", ns)
for _, path in ipairs({
    "Data/WhitelistSpells.lua",
    "Data/SpecEnhancements/DemonHunter.lua",
    "Data/APL/DemonHunter_Havoc.lua",
    "Engine/APLEngine.lua",
}) do
    loadAddonFile(path, ns)
end
local engine = assert(RA:GetModule("APLEngine"))
engine:SetAPL(577, assert(RA.APLData[577]), 12)
local apl = assert(engine:GetCurrentAPL())
local profiles = { "default", "fel_scarred" }
local wanted = {}
local cooldownBearing = {}
for _, profileName in ipairs(profiles) do
    local profile = assert(apl.profiles[profileName])
    for _, listName in ipairs({ "singleTarget", "aoe", "opener" }) do
        local rules = profile[listName] or {}
        for _, rule in ipairs(rules) do
            local id = rule.spellID
            if type(id) == "number" then
                wanted[id] = true
                local white = RA.WhitelistSpells and RA.WhitelistSpells[id]
                if (type(rule.cdSeconds) == "number" and rule.cdSeconds > 0)
                   or (white and type(white.cdSeconds) == "number" and white.cdSeconds > 0) then
                    cooldownBearing[id] = true
                end
            end
        end
    end
end
-- Snapshot the keys: inserting into a table during pairs() can skip existing
-- entries after rehashing. / 遍历时插入会漏掉旧键；先固定原始键集合。
local wantedIDs = {}
for id in pairs(wanted) do wantedIDs[#wantedIDs + 1] = id end
for _, id in ipairs(wantedIDs) do
    local pair = RA.KNOWN_OVERRIDE_PAIRS and RA.KNOWN_OVERRIDE_PAIRS[id]
    if pair then wanted[pair] = true end
end

local targets = sim.options and sim.options.desired_targets
if type(targets) ~= "number" or targets < 1 then targets = nil end
local enhancement = RA.SpecEnhancements and RA.SpecEnhancements[577]
local costs = enhancement and enhancement.resource and enhancement.resource.spellCosts or {}
local function equivalent(a, b)
    return a == b or (RA.KNOWN_OVERRIDE_PAIRS and RA.KNOWN_OVERRIDE_PAIRS[a] == b)
end
-- A name alias is accepted only when this very trace uniquely ties that token
-- to one addon-known action (or its registered override pair). This is trace
-- evidence, not a hard-coded claim that two SimC spell IDs are universally equal.
-- 同一轨迹中的唯一动作名称才能作为临时映射；不把 ID 差异硬编码成通用事实。
local actionByName = {}
local observedActionIDs = {}
for _, row in ipairs(rows) do
    if type(row.name) == "string" and type(row.id) == "number" and wanted[row.id] then
        observedActionIDs[row.id] = true
        local previous = actionByName[row.name]
        if previous == nil then
            actionByName[row.name] = row.id
        elseif previous ~= false and not equivalent(previous, row.id) then
            actionByName[row.name] = false
        end
    end
end
local aliasEvidence = {}
local function costFor(id)
    local pair = RA.KNOWN_OVERRIDE_PAIRS and RA.KNOWN_OVERRIDE_PAIRS[id]
    local data = costs[id] or (pair and costs[pair])
    return data and data.cost
end
local function snapshot(row)
    local state = {
        cooldowns = {}, cooldownUnknown = {}, charges = {},
        resource = row.resources and row.resources.fury,
        resourceKnown = type(row.resources) == "table"
            and type(row.resources.fury) == "number",
        resourceMax = row.resources_max and row.resources_max.fury,
        targetCount = targets, combatDuration = row.time,
        windows = {},
    }
    local contextEvidence = {
        metamorphosisAura = false,
        essenceBreakOnActionTarget = false,
    }
    for _, buff in ipairs(type(row.buffs) == "table" and row.buffs or {}) do
        if buff.id == 162264 and type(buff.remains) == "number" and buff.remains > 0 then
            -- SimC class data: Metamorphosis aura 162264, triggered by 191427.
            -- 此 ID 只证明当前变身，不证明 4 步 Demonic 预测窗口仍在。
            state.inMeta = true
            contextEvidence.metamorphosisAura = true
        end
    end
    for _, target in ipairs(type(row.targets) == "table" and row.targets or {}) do
        if type(row.target) == "string" and target.name == row.target then
            for _, debuff in ipairs(type(target.debuffs) == "table" and target.debuffs or {}) do
                if debuff.id == 320338 and type(debuff.remains) == "number"
                   and debuff.remains > 0 then
                    -- SimC class data: Essence Break target debuff 320338.
                    -- 只读取当前动作目标，其他目标的同名减益不适用。
                    state.windows.essence_break = true
                    contextEvidence.essenceBreakOnActionTarget = true
                    break
                end
            end
            break
        end
    end
    local active = {}
    for _, cooldown in ipairs(type(row.cooldowns) == "table" and row.cooldowns or {}) do
        local id, remains = cooldown.id, cooldown.remains
        if type(id) == "number" and id > 0 and type(remains) == "number"
           and remains >= 0 and remains < 100000 then
            active[id] = math.max(active[id] or 0, remains)
            local pair = RA.KNOWN_OVERRIDE_PAIRS and RA.KNOWN_OVERRIDE_PAIRS[id]
            if pair then active[pair] = math.max(active[pair] or 0, remains) end
            local matched = type(cooldown.name) == "string" and actionByName[cooldown.name]
            if type(matched) == "number" and matched ~= id then
                active[matched] = math.max(active[matched] or 0, remains)
                local matchedPair = RA.KNOWN_OVERRIDE_PAIRS and RA.KNOWN_OVERRIDE_PAIRS[matched]
                if matchedPair then active[matchedPair] = math.max(active[matchedPair] or 0, remains) end
                local key = tostring(id) .. ":" .. tostring(matched)
                aliasEvidence[key] = { cooldownID = id, actionID = matched,
                    name = cooldown.name, basis = "unique action name within this trace" }
            end
        end
    end
    local unobserved = 0
    for id in pairs(cooldownBearing) do
        if active[id] then
            state.cooldowns[id] = active[id]
        else
            local pair = RA.KNOWN_OVERRIDE_PAIRS and RA.KNOWN_OVERRIDE_PAIRS[id]
            if observedActionIDs[id] or (pair and observedActionIDs[pair]) then
                -- For an action observed elsewhere in this trace, SimC's full
                -- state constructor omits its cooldown exactly when not down.
                -- 已在本轨迹出现的动作，其冷却缺席按 SimC 构造器可判为非 CD。
                state.cooldowns[id] = 0
            else
                state.cooldownUnknown[id] = true
                unobserved = unobserved + 1
            end
        end
    end
    return state, active, unobserved, contextEvidence
end

local report = {
    schema = "rotaassist.havoc.replay.v1",
    addonRoot = addonRoot,
    tracePath = tracePath,
    traceVersion = trace.version or trace.simcVersion or JSON_NULL,
    traceProvenance = trace.provenance or JSON_NULL,
    comparison = "same-row SimC pre-action snapshot versus APLEngine:PredictNext(nil, state, 1)",
    interpretation = "exploratory action agreement, not DPS, optimality, Blizzard agreement, or live-client validation",
    cooldownPolicy = "listed active cooldown remains is known; omitted is ready only for actions independently observed in this trace; other omissions are unknown; stacks is not current charges",
    contextMapping = {
        metamorphosis = "active SimC buff 162264 -> inMeta=true (generated spell data; 191427 trigger)",
        essenceBreak = "active SimC target debuff 320338 on row.target -> windows.essence_break=true (class module)",
        demonic = "unmapped: addon synthetic four-step window is not the full Metamorphosis aura",
    },
    cooldownAliases = {},
    addonFuryMaxBase = enhancement and enhancement.resource and enhancement.resource.maxBase or JSON_NULL,
    traceFuryMaxValues = {},
    profileResults = {},
    unresolvedFields = {
        charges = "SimC cooldown.stacks is configured charges, not current available charges",
        demonicWindow = "Four simulated post-trigger steps are not equivalent to the full Metamorphosis aura duration",
        metaState = "Active aura 162264 proves true; absence is not used as a live-client false assertion",
        essenceBreakWindow = "Active debuff 320338 on the action target proves true; absence may reflect snapshot filtering",
        gcdDuration = "Not needed for nil-head depth-1 same-row choice; missing for forward lookahead",
        cooldownOmission = "Only active cooldowns are listed; omitted unobserved action IDs remain unknown",
        learnedSpells = "Offline IsPlayerSpell mock returns true for all IDs; trace action coverage is not a full talent or learned-spell catalog",
        profileSelection = "Both addon profiles are replayed independently; SimC talent equivalence is not assumed",
        clientHead = "No C_AssistedCombat recommendation in SimC trace; nil head tests the APL decision path only",
        timing = "Ordinary selected actions are before execute, but SimC may start a line cooldown before snapshot; special actions differ",
    },
}

for _, profileName in ipairs(profiles) do
    engine:SetProfile(profileName)
    local result = {
        profile = profileName, totalTraceRows = #rows, mappedActionRows = 0,
        predictedRows = 0, exactAgreement = 0, overrideEquivalentAgreement = 0,
        mismatches = 0, noPrediction = 0, skipped = { nonAction = 0, unmapped = 0, queueFailed = 0 },
        impossibleActionEvidence = {}, comparisons = {},
    }
    for index, row in ipairs(rows) do
        local id = row.id
        if row.queue_failed == true then
            result.skipped.queueFailed = result.skipped.queueFailed + 1
        elseif type(id) ~= "number" or id <= 0 then
            result.skipped.nonAction = result.skipped.nonAction + 1
        elseif not wanted[id] then
            result.skipped.unmapped = result.skipped.unmapped + 1
        else
            result.mappedActionRows = result.mappedActionRows + 1
            local state, active, unknownCDs, context = snapshot(row)
            local predictions = engine:PredictNext(nil, state, 1)
            local predicted = predictions[1] and predictions[1].spellID
            local comparison = {
                index = index, time = row.time, observedSpellID = id,
                observedAction = row.name, predictedSpellID = predicted or JSON_NULL,
                fury = state.resource or JSON_NULL,
                furyMax = state.resourceMax or JSON_NULL,
                unknownCooldownCount = unknownCDs,
                resourceKnown = state.resourceKnown,
                contextEvidence = context,
                missing = { "currentCharges", "demonicWindow" },
            }
            if not context.metamorphosisAura then
                comparison.missing[#comparison.missing + 1] = "metaState"
            end
            if not context.essenceBreakOnActionTarget then
                comparison.missing[#comparison.missing + 1] = "essenceBreakWindow"
            end
            if unknownCDs > 0 then
                comparison.missing[#comparison.missing + 1] = "cooldownReadinessForOmittedSpells"
            end
            if not state.resourceKnown then
                comparison.missing[#comparison.missing + 1] = "fury"
            end
            if not targets then
                comparison.missing[#comparison.missing + 1] = "targetCount"
            end
            if predicted then
                result.predictedRows = result.predictedRows + 1
                if predicted == id then
                    result.exactAgreement = result.exactAgreement + 1
                    comparison.outcome = "exact"
                elseif equivalent(predicted, id) then
                    result.overrideEquivalentAgreement = result.overrideEquivalentAgreement + 1
                    comparison.outcome = "override_equivalent"
                else
                    result.mismatches = result.mismatches + 1
                    comparison.outcome = "different"
                end
                local cost = costFor(predicted)
                if type(cost) == "number" and cost > 0 and state.resourceKnown
                   and state.resource < cost then
                    result.impossibleActionEvidence[#result.impossibleActionEvidence + 1] = {
                        index = index, time = row.time, spellID = predicted,
                        reason = "declared_cost_exceeds_pre_action_fury",
                        cost = cost, fury = state.resource,
                    }
                end
                if active[predicted] and active[predicted] > 0 then
                    result.impossibleActionEvidence[#result.impossibleActionEvidence + 1] = {
                        index = index, time = row.time, spellID = predicted,
                        reason = "active_cooldown_in_pre_action_snapshot",
                        remaining = active[predicted],
                    }
                end
            else
                result.noPrediction = result.noPrediction + 1
                comparison.outcome = "no_prediction"
            end
            result.comparisons[#result.comparisons + 1] = comparison
        end
    end
    result.exploratoryAgreementRate = result.predictedRows > 0
        and (result.exactAgreement + result.overrideEquivalentAgreement) / result.predictedRows
        or JSON_NULL
    result.predictionCoverage = result.mappedActionRows > 0
        and result.predictedRows / result.mappedActionRows or JSON_NULL
    result.mappedActionAgreementRate = result.mappedActionRows > 0
        and (result.exactAgreement + result.overrideEquivalentAgreement) / result.mappedActionRows
        or JSON_NULL
    report.profileResults[#report.profileResults + 1] = result
end

local aliasKeys = {}
for key in pairs(aliasEvidence) do aliasKeys[#aliasKeys + 1] = key end
table.sort(aliasKeys)
for _, key in ipairs(aliasKeys) do
    report.cooldownAliases[#report.cooldownAliases + 1] = aliasEvidence[key]
end
local furyMaxSet = {}
for _, row in ipairs(rows) do
    local maximum = row.resources_max and row.resources_max.fury
    if type(maximum) == "number" then furyMaxSet[maximum] = true end
end
for maximum in pairs(furyMaxSet) do
    report.traceFuryMaxValues[#report.traceFuryMaxValues + 1] = maximum
end
table.sort(report.traceFuryMaxValues)
if type(report.addonFuryMaxBase) == "number" then
    for _, maximum in ipairs(report.traceFuryMaxValues) do
        if maximum ~= report.addonFuryMaxBase then
            report.unresolvedFields.resourceMaxMismatch =
                "Trace Fury maximum differs from static maxBase; same-row replay passes resourceMax, but does not exercise future generation or establish live API readability"
            break
        end
    end
end

local json = encodeJSON(report) .. "\n"
if reportPath then
    local output = assert(io.open(reportPath, "wb"))
    assert(output:write(json))
    assert(output:close())
    io.stderr:write("Wrote Havoc replay report to " .. reportPath .. "\n")
else
    io.write(json)
end
