------------------------------------------------------------------------
-- RotaAssist - Smart Queue Manager
-- 譎ｺ閭ｽ髦溷・邂｡逅・勣 / Smart Queue Manager
-- The final fusion layer combining Blizzard, APL, AI Inference,
-- Cooldowns, and Defensives into a single prioritized display queue.
------------------------------------------------------------------------

local _, NS = ...
local RA = NS.RA
local SmartQueueManager = {}
RA:RegisterModule("SmartQueueManager", SmartQueueManager)

------------------------------------------------------------------------
-- Configuration & Throttling
------------------------------------------------------------------------

-- Queue rebuild cadence. The frame is never hidden: MainDisplay still needs a
-- live queue out of combat (fade-out, target-dummy practice), but polling at the
-- in-combat rate while idling in a city is wasted CPU, so the interval is widened.
-- 队列重建节奏。更新帧永不隐藏——脱战时 MainDisplay 仍需要数据（淡出显示、打木桩），
-- 但站城时按战斗频率轮询纯属浪费 CPU，因此脱战放宽间隔。
local THROTTLE_COMBAT = 0.15
local THROTTLE_IDLE   = 0.6

--- Active rebuild interval; swapped by PLAYER_REGEN_DISABLED/ENABLED.
--- 当前生效的重建间隔，由进出战斗事件切换。
local throttleInterval = THROTTLE_IDLE

local defaultWeights = {
    blizzardWeight = 1.0,
    aplWeight      = 0.6,
    aiWeight       = 0.4,
    cdWeight       = 0.5,
    defWeight      = 0.8
}

-- 蟾ｲ遏･逧・｢ｫ蜉ｨ/荳榊庄譁ｽ謾ｾ謚閭ｽ鮟大錐蜊包ｼ・PI 譟･隸｢逧・ｿｫ騾溯ｷｯ蠕・､・ｻｽ・・
-- Known passive/non-castable spell blacklist (fast-path backup for API queries)
local PASSIVE_BLACKLIST = RA.Registry.PASSIVE_BLACKLIST

-- Engine Module References (cached for speed)
local mBridge
local mAIInference
local mAPLEngine
local mCooldownOverlay
local mDefensiveAdvisor

--- Check if a spell is currently on significant cooldown (> 1.0s remaining).
--- 譽譟･謚閭ｽ譏ｯ蜷ｦ蝨ｨ譛画譜 CD 荳ｭ・郁ｶ・ｿ・1.0遘抵ｼ会ｼ檎畑莠手ｿ・ｻ､ next[] 荳ｭ逧・｢・ｵ九・
--- FIX (OverridePair): Also checks the paired override ID (e.g. Death Sweep for Blade Dance).
--- 蜷梧慮譽譟･隕・尠蟇ｹ謚閭ｽ逧・CD 迥ｶ諤・ｼ亥ｦ・Blade Dance 竊・Death Sweep・峨・
local function IsSpellOnCooldown(spellID)
    if not spellID then return false end
    -- Primary: check CooldownOverlay tracked states
    if mCooldownOverlay then
        local cds = mCooldownOverlay:GetCooldownStates()
        local cdState = cds[spellID]
        if cdState then
            if not cdState.ready and cdState.remaining and cdState.remaining > 1.0 then
                return true
            end
            -- FIX (OverridePair): paired ID check when primary reports ready
            -- 隕・尠蟇ｹ譽譟･・壻ｸｻ ID 蟆ｱ扈ｪ譌ｶ譟･逵矩・蟇ｹ ID 譏ｯ蜷ｦ蝨ｨ CD
            local pairedID = RA.KNOWN_OVERRIDE_PAIRS and RA.KNOWN_OVERRIDE_PAIRS[spellID]
            if pairedID then
                local pairedState = cds[pairedID]
                if pairedState and not pairedState.ready
                   and pairedState.remaining and pairedState.remaining > 1.0 then
                    return true
                end
            end
            return false
        end
    end
    -- Fallback: direct API query for spells not tracked by CooldownOverlay
    local remaining = RA:GetSpellCooldownSafe(spellID)
    if remaining and remaining > 1.0 then
        return true
    end

    -- FIX (OverridePair): check paired ID via direct API when primary is not on CD
    -- 隕・尠蟇ｹ API 蝗樣・壻ｸｻ ID 譛ｪ蝨ｨ CD 譌ｶ譽譟･驟榊ｯｹ ID
    if remaining ~= nil then
        local pairedID = RA.KNOWN_OVERRIDE_PAIRS and RA.KNOWN_OVERRIDE_PAIRS[spellID]
        if pairedID then
            local pRemaining = RA:GetSpellCooldownSafe(pairedID)
            if pRemaining and pRemaining > 1.0 then
                return true
            end
        end
    end

    -- remaining == nil (secret value): estimate from cast history
    -- 12.0 secret value 蝗樣・壻ｻ取命豕募紙蜿ｲ隶ｰ蠖穂ｸｭ莨ｰ邂怜・蜊ｴ迥ｶ諤・
    if remaining == nil then
        local wsInfo = RA.WhitelistSpells and RA.WhitelistSpells[spellID]
        if wsInfo and wsInfo.cdSeconds and wsInfo.cdSeconds > 1.5 then
            local recorder = RA:GetModule("CastHistoryRecorder")
            if recorder then
                local recent = recorder:GetRecentCasts(20)
                for _, cast in ipairs(recent) do
                    if cast.spellID == spellID then
                        local elapsedTime = GetTime() - cast.timestamp
                        if elapsedTime < wsInfo.cdSeconds then
                            return true
                        end
                        break
                    end
                end
            end
        end
    end
    return false
end

SmartQueueManager._IsSpellOnCooldown = IsSpellOnCooldown

--- Unified castability gate: checks passive, unlearned, unusable, and cooldown.
--- 扈滉ｸ蜿ｯ譁ｽ謾ｾ諤ｧ譽譟･・夊｢ｫ蜉ｨ縲∵悴蟄ｦ荵縲∽ｸ榊庄譁ｽ謾ｾ縲∝・蜊ｴ荳ｭ蝗幃㍾霑・ｻ､縲・
--- @param spellID number
--- @return boolean castable
local function IsSpellCastable(spellID)
    if not spellID or spellID == 0 then return false end
    -- 1. 陲ｫ蜉ｨ鮟大錐蜊募ｿｫ騾溯ｷｯ蠕・
    if PASSIVE_BLACKLIST[spellID] then return false end
    -- 2. RA 陲ｫ蜉ｨ譽豬・
    if RA.IsSpellPassive and RA:IsSpellPassive(spellID) then return false end
    -- 3. 譛ｪ蟄ｦ荵譽豬・
    if IsPlayerSpell then
        local okL, known = pcall(IsPlayerSpell, spellID)
        if okL and not known then return false end
    end
    -- 4. 荳榊庄譁ｽ謾ｾ譽豬具ｼ郁ｦ・尠 Hero Talent 蠅槫ｼｺ蝙玖｢ｫ蜉ｨ遲・IsSpellPassive 貍丞愛逧・ュ蜀ｵ・・
    if C_Spell and C_Spell.IsSpellUsable then
        local okU, usable = pcall(C_Spell.IsSpellUsable, spellID)
        if okU and issecretvalue(usable) then return false end
        if okU and usable == false then return false end
    end
    -- 5. 蜀ｷ蜊ｴ荳ｭ・・1.0遘抵ｼ・
    if IsSpellOnCooldown(spellID) then return false end
    return true
end

SmartQueueManager._IsSpellCastable = IsSpellCastable

---Static safety gate for a future simulated action.
---Do not inspect current cooldown/usability here: the preceding simulated cast may
---make the spell ready or provide its resource. An invalid step truncates the tail
---instead of compacting later actions into an impossible sequence.
---未来模拟步骤的静态安全门。这里不能读取当前冷却/可用性，因为前一步模拟施法可能
---让技能转好或提供资源。无效步骤会截断后续，不能把更后的动作压缩成错误序列。
---@param spellID number
---@return boolean safe
local function IsFutureSpellSafe(spellID)
    if issecretvalue(spellID) then return false end
    if type(spellID) ~= "number" or spellID <= 0 or spellID == 6603 then return false end
    if PASSIVE_BLACKLIST[spellID] or (RA.IsSpellPassive and RA:IsSpellPassive(spellID)) then
        return false
    end

    if RA.ResolveSpellOverride then
        local resolved, wasOverridden = RA:ResolveSpellOverride(spellID)
        if wasOverridden and RA:IsSpellPassive(resolved) then return false end
    end

    if IsPlayerSpell then
        local okKnown, known = pcall(IsPlayerSpell, spellID)
        if not okKnown or known ~= true then return false end
    end

    if C_Spell and C_Spell.GetSpellInfo then
        local okInfo, info = pcall(C_Spell.GetSpellInfo, spellID)
        if not okInfo or type(info) ~= "table" then return false end
    end
    return true
end

SmartQueueManager._IsFutureSpellSafe = IsFutureSpellSafe

------------------------------------------------------------------------
-- Internal State
------------------------------------------------------------------------

local updateFrame = nil
local lastUpdate  = 0

-- Outputs (zero-allocation recycle)
local finalQueue = {
    main      = nil,
    next      = {},
    cooldowns = {},
    defensive = nil,
    phase     = "UNKNOWN",
    tip       = nil,
    accuracy  = 0,
    aiContext = nil -- Keep backward compatible with UI that reads aiContext
}

-- Previous main spell ID to fire event on change
local prevMainSpellID = nil

-- 荳贋ｸ蟶ｧ荳ｻ謗ｨ闕蝕D・御ｾ・AccuracyTracker 蛛壻ｸ贋ｸ蟶ｧ豈泌ｯｹ縲・
local lastRecommendedSpellID = nil

-- Sticky Blizzard recommendation (caches last known ID if Blizzard temporarily returns nil)
-- 隶ｰ蠢・Blizzard 謗ｨ闕撰ｼ磯亟豁｢ GCD 謌門ｻｶ霑溷ｯｼ閾ｴ謗ｨ闕千椪髣ｴ豸亥､ｱ蠑戊ｵｷ鬚・ｵ区竃蜉ｨ・・
local lastKnownBlizzSpell = nil

-- 譁ｽ豕募錘逧・ｽｯ螻剰反・壼惠逵溷ｮ・CD 謨ｰ謐ｮ蛻ｰ譚･蜑堺ｸｴ譌ｶ髦ｻ豁｢蛻壽命謾ｾ逧・橿閭ｽ陲ｫ謗ｨ闕・
-- Soft-block: temporarily suppress the just-cast spell until SPELL_UPDATE_COOLDOWN confirms the real CD.
local softBlockedSpells = {}
local SOFT_BLOCK_DURATION = 0.6  -- seconds until soft-block auto-expires

-- 蠑募ｯｼ謚閭ｽ・壽命豕墓・蜉溷錘荳肴ｸ・勁 lastKnownBlizzSpell・御ｿ晄戟蠑募ｯｼ扈捺據蜷惹ｸ倶ｸ豁･謗ｨ闕千ｨｳ螳・
-- Channeled spells: don't clear sticky on success 窶・keep showing next-spell during channel.
local CHANNELED_SPELL_IDS = {
    [198013] = true,  -- Eye Beam (Havoc)
    [212084] = true,  -- Fel Devastation (Vengeance)
    [258920] = true,  -- Immolation Aura (channel phase)
}

-- 蠑募ｯｼ譛滄龍謐戊執逧・悟ｼ募ｯｼ扈捺據蜷惹ｸ倶ｸ豁･縲行pellID・檎畑莠・sticky fallback
-- Captured next-spell spellID during a channel, used as sticky fallback.
local channelNextSpell = nil

local context_reuse = {
    blizzSpell=nil, aplPred=nil, aplState=nil,
    predictiveEnabled=false,
    cdReadyList={}, blindSpotCandidates={},
    defSpell=nil, defUrgency=0,
    aiPhase="NORMAL", aiTip=nil,
}
local observedWindows_reuse = {}
local candidates_reuse = {}
local scored_reuse = {}
local toRemove_reuse = {}
local passiveRemove_reuse = {}
local sbRemove_reuse = {}
local unlearnedRemove_reuse = {}
-- 譛霑台ｸ蟶ｧ逧・APL 鬚・ｵ狗ｻ捺棡・域ｨ｡蝮礼ｺｧ・御ｾ・CHANNEL_START 髣ｭ蛹・ｯｻ蜿厄ｼ・
-- Most-recent APL predictions at module level so the CHANNEL_START closure can read them.
local aplPredictions = {}

------------------------------------------------------------------------
-- Helper Functions
------------------------------------------------------------------------

---Calculate priority score for a spell candidate.
---隶｡邂怜咎画橿閭ｽ逧・ｼ伜・郤ｧ蠕怜・縲・
---@param spellID number
---@param context table
---@param weights table
---@param aplPredictions table  Full APL prediction array for tiered scoring
---@return number score, string source
local function CalculateScore(spellID, context, weights, aplPredictions)
    local score = 0
    local primarySource = "UNKNOWN"

    -- 1. Blizzard Recommendation
    if context.blizzSpell == spellID then
        score = score + (1.0 * weights.blizzardWeight)
        primarySource = "BLIZZARD"
    end

    -- 2. APL Engine Tiered Prediction Scoring
    -- Step-1 gets full APL weight, step-2 gets 0.5ﾃ・ step-3 gets 0.3ﾃ・
    -- Skip if already scored as a blind-spot to avoid double-counting.
    -- APL 蛻・ｱりｯ・・・夂ｬｬ1豁･蜈ｨ譚・㍾・檎ｬｬ2豁･0.5ﾃ暦ｼ檎ｬｬ3豁･0.3ﾃ暦ｼ帷峇蛹ｺ謚閭ｽ霍ｳ霑・∩蜈榊曙驥崎ｮ｡蛻・
    if aplPredictions and not (context.blindSpotCandidates and context.blindSpotCandidates[spellID]) then
        local APL_TIER = { 1.0, 0.5, 0.3 }
        for i, pred in ipairs(aplPredictions) do
            if pred.spellID == spellID then
                local tier = APL_TIER[i] or 0
                score = score + (pred.confidence * weights.aplWeight * tier)
                if score > (1.0 * weights.blizzardWeight) then
                    primarySource = "APL"
                end
                break  -- a spell only appears once in aplPredictions
            end
        end
    end

    -- 3. Blind-spot bonus: APL-prioritised CD that Blizzard's rotation omits.
    -- 逶ｲ蛹ｺ蜉蛻・ｼ哂PL 莨伜・郤ｧ霎・ｫ倅ｸ・Blizzard 蠕ｪ邇ｯ荳ｭ郛ｺ蟆醍噪蟆ｱ扈ｪ CD・悟ｾ怜・ >= 1.0 雜・ｶ・Blizzard
    if context.blindSpotCandidates and context.blindSpotCandidates[spellID] then
        score = score + 1.2  -- 蠢・｡ｻ雜・ｿ・Blizzard 逧・1.0・御ｽｿ逶ｲ蛹ｺ謚閭ｽ蜿ｯ莉･謌蝉ｸｺ荳ｻ謗ｨ闕・
        primarySource = "APL_BLINDSPOT"
    end

    -- 4. AI Inference Tip Bonus
    if context.aiTip and context.aiTip.text then
        -- Simplified: let APL/Blizzard drive mostly.
    end

    -- 5. Cooldown Overlay (whitelisted CDs ready during BURST prep)
    if context.cdReadyList[spellID] and context.aiPhase == "BURST_PREPARE" then
        score = score + (0.5 * weights.cdWeight)
    end

    -- 6. Defensive Urgency
    if context.defSpell == spellID then
        score = score + ((context.defUrgency or 1.0) * weights.defWeight)
        primarySource = "DEFENSIVE"
    end

    return score, primarySource
end

-- Expose for unit testing (module-level reference)
SmartQueueManager._CalculateScore = CalculateScore

---Move the current Blizzard recommendation to the head of the scored list.
---Its API owns slot 1; local APL blind-spot scores are look-ahead hints and must
---never displace an available, runtime-validated Blizzard action.
---将当前暴雪建议移到评分列表首位。slot 1 由暴雪 API 决定；本地 APL 的盲区分数
---只是前瞻提示，不能覆盖可用且经过运行时验证的暴雪动作。
---@param scored table[]
---@param blizzSpell number|nil
local function PromoteAuthoritativeMain(scored, blizzSpell)
    if not blizzSpell then return end
    for i = 1, #scored do
        if scored[i].spellID == blizzSpell then
            if i ~= 1 then
                scored[1], scored[i] = scored[i], scored[1]
            end
            return
        end
    end
end

SmartQueueManager._PromoteAuthoritativeMain = PromoteAuthoritativeMain

------------------------------------------------------------------------
-- Charge Scanning
-- Only a handful of the ~130 whitelisted spells actually have charges, but
-- every queue rebuild used to call C_Spell.GetSpellCharges on all of them
-- (~870 calls/sec at the in-combat cadence). The first scan after a spec or
-- talent change records which spellIDs really carry charges; later scans walk
-- only that subset.
-- 充能扫描：白名单约 130 条技能里真正有充能的只有少数几个，但过去每次重建
-- 队列都对全部技能调用 C_Spell.GetSpellCharges（战斗节奏下约 870 次/秒）。
-- 专精或天赋变更后的首次扫描记录哪些 spellID 真的有充能，后续只遍历该子集。
------------------------------------------------------------------------

--- spellID -> true for spells confirmed (or presumed) to have charges.
--- Reused across rebuilds; wiped rather than reallocated.
--- 确认（或保守推定）有充能的技能集合，复用不重新分配。
local chargeSpells = {}

--- False until the next scan must re-derive chargeSpells from the full whitelist.
--- 为 false 时下次扫描需要从完整白名单重建 chargeSpells。
local chargeSubsetValid = false

---Decide whether a spell belongs in the charge subset.
--- WOW 12.0 SECRET VALUE SAFE: maxCharges can be secret in combat, so
--- issecretvalue() runs before any comparison. When the value is secret or
--- absent we cannot prove the spell is charge-less, so it is kept in the
--- subset — over-inclusion only costs a call, exclusion would lose data.
--- WOW 12.0 SECRET VALUE 安全：战斗中 maxCharges 可能是 secret，
--- 因此在任何比较之前先过 issecretvalue()。值为 secret 或缺失时无法证明该技能
--- 没有充能，保守保留在子集中——多留只多一次调用，误删则会丢数据。
---@param chargeInfo table
---@return boolean hasCharges
local function ShouldTrackCharges(chargeInfo)
    local mc = chargeInfo.maxCharges
    if issecretvalue(mc) then return true end
    if type(mc) == "number" then return mc > 1 end
    return true
end

---Read current charges into limitedState.charges.
---Rebuilds the tracked subset when it has been invalidated.
---把当前充能数写入 limitedState.charges；子集失效时先重建。
---@param limitedState table
local function ScanCharges(limitedState)
    if not (C_Spell and C_Spell.GetSpellCharges and RA.WhitelistSpells) then return end

    local source
    if chargeSubsetValid then
        source = chargeSpells
    else
        wipe(chargeSpells)
        source = RA.WhitelistSpells
    end

    for sid in pairs(source) do
        local okCharges, chargeInfo = pcall(C_Spell.GetSpellCharges, sid)
        if okCharges and type(chargeInfo) == "table" then
            if not chargeSubsetValid and ShouldTrackCharges(chargeInfo) then
                chargeSpells[sid] = true
            end

            -- WOW 12.0 SECRET VALUE SAFE: currentCharges is a secret value in combat.
            -- The old `and chargeInfo.currentCharges then` truth-tested it before any
            -- guard and then stored the tainted value, which APLEngine later compared.
            -- Gate on issecretvalue() first; leave the entry nil when unreadable so
            -- APLEngine can treat it as "unknown" instead of a bogus number.
            -- WOW 12.0 SECRET VALUE 安全：战斗中 currentCharges 是 secret 值。原写法
            -- `and chargeInfo.currentCharges then` 在无任何守卫的情况下对其做真值判断，
            -- 并把被污染的值存起来供 APLEngine 比较。改为先过 issecretvalue()；读不到时
            -- 保持该项为 nil，让 APLEngine 按"未知"处理而不是拿到一个假数字。
            local cc = chargeInfo.currentCharges
            if not issecretvalue(cc) and type(cc) == "number" then
                limitedState.charges[sid] = cc
                -- Recharge timing is useful only when every input is public.
                -- 回充时间仅在全部输入可公开读取时传给模拟器。
                local mc = chargeInfo.maxCharges
                local st = chargeInfo.cooldownStartTime
                local dur = chargeInfo.cooldownDuration
                local rate = chargeInfo.chargeModRate
                local rateKnown = not issecretvalue(rate)
                if rateKnown and rate == nil then
                    rate = chargeInfo.modRate
                    rateKnown = not issecretvalue(rate)
                end
                if rateKnown and rate == nil then rate = 1 end
                if not issecretvalue(mc) and not issecretvalue(st)
                   and not issecretvalue(dur) and rateKnown
                   and type(mc) == "number" and type(st) == "number"
                   and type(dur) == "number" and type(rate) == "number"
                   and mc > 1 and cc >= 0 and cc <= mc and dur > 0 and rate > 0 then
                    -- Blizzard's CooldownViewer predicts charge gain at st + dur;
                    -- chargeModRate affects cooldown UI updates, not this clock.
                    -- 暴雪按 st + dur 计算回充，rate 只用于冷却 UI 更新。
                    local effectiveDuration = dur
                    local remaining = 0
                    if cc < mc then
                        if st <= 0 then effectiveDuration = nil
                        else remaining = math.max(0, st + effectiveDuration - GetTime()) end
                    end
                    if effectiveDuration then
                        limitedState.chargeRecharges[sid] = {
                            current = cc, max = mc,
                            remaining = remaining, duration = effectiveDuration,
                        }
                    end
                end
            end
        end
    end

    chargeSubsetValid = true
end

---Force the next scan to re-derive the charge subset from the full whitelist.
---Charge counts are spec- and talent-dependent, so both invalidate it.
---让下次扫描从完整白名单重建充能子集。充能数受专精与天赋影响，两者都需失效。
local function InvalidateChargeSubset()
    chargeSubsetValid = false
end

------------------------------------------------------------------------
-- Update Loop
------------------------------------------------------------------------

local function AssembleQueue()
    local independent = RA:GetModule("IndependentObserver")
    if independent then independent:Reset() end
    local targetModule = RA:GetModule("TargetContext")
    local battlefield = targetModule and targetModule:IsActive() and targetModule:GetSnapshot()
    if battlefield and battlefield.targetValid == false then
        lastKnownBlizzSpell = nil
        channelNextSpell = nil
        finalQueue.main = nil
        wipe(finalQueue.next)
        wipe(aplPredictions)
        local events = RA:GetModule("EventHandler")
        if events then events:Fire("ROTAASSIST_QUEUE_UPDATED", nil) end
        return
    end
    if not InCombatLockdown() and not (RA.db and RA.db.profile.display.showOutOfCombat) then
        finalQueue.main      = nil
        finalQueue.next      = {}
        finalQueue.cooldowns = {}
        finalQueue.defensive = nil
        lastKnownBlizzSpell  = nil -- Clear cache out of combat
        return
    end

    local weights = RA.db and RA.db.profile.smartQueue or defaultWeights

    -- 1. Gather Context
    local context = context_reuse
    context.blizzSpell = nil
    context.independentHead = nil
    context.aplPred = nil
    context.aplState = nil
    context.predictiveEnabled = false
    wipe(context.cdReadyList)
    wipe(context.blindSpotCandidates)
    context.defSpell = nil
    context.defUrgency = 0
    context.aiPhase = "NORMAL"
    context.aiTip = nil

    if mBridge then
        local rec = mBridge:GetCurrentRecommendation()
        context.blizzSpell = rec and rec.spellID or nil

        -- Sticky fallback priority:
        -- 1. Real Blizzard recommendation (always wins)
        -- 2. channelNextSpell  窶・captured at channel start (蠑募ｯｼ荳ｭ・壽仞遉ｺ蠑募ｯｼ蜷守噪荳倶ｸ荳ｪ謚閭ｽ)
        -- 3. lastKnownBlizzSpell 窶・normal inter-GCD sticky
        if context.blizzSpell then
            lastKnownBlizzSpell = context.blizzSpell
        elseif channelNextSpell then
            context.blizzSpell = channelNextSpell
        elseif lastKnownBlizzSpell then
            -- FIX (Round14-Bug1): sticky fallback 蠢・｡ｻ鬪瑚ｯ∵橿閭ｽ譏ｯ蜷ｦ莉咲┯蜿ｯ譁ｽ謾ｾ
            -- Sticky fallback must verify the spell is not on cooldown before reuse
            if not IsSpellOnCooldown(lastKnownBlizzSpell) then
                context.blizzSpell = lastKnownBlizzSpell
            else
                -- 謚閭ｽ蟾ｲ霑・CD・梧ｸ・勁 sticky・瑚ｮｩ髦溷・閾ｪ辟ｶ髯咲ｺｧ蛻ｰ APL/AI 謗ｨ闕・
                lastKnownBlizzSpell = nil
            end
        end
    end

    -- Build Blizzard rotation spell set for blind-spot detection
    if battlefield and battlefield.spellRange[context.blizzSpell] == false then
        context.blizzSpell = nil
        lastKnownBlizzSpell = nil
        channelNextSpell = nil
    end
    -- Blizzard 蠕ｪ邇ｯ謚閭ｽ髮・粋・檎畑莠取｣豬狗峇蛹ｺ謚閭ｽ
    local rotationSpells = {}
    if mBridge then
        local list = mBridge:GetRotationSpells()
        for _, sid in ipairs(list) do
            rotationSpells[sid] = true
        end
    end

    -- FIX (Bug1): PredictNext returns an ARRAY of predictions.
    -- Parse it correctly; the first element joins scoring, rest go to next[].
    -- 菫ｮ螟搾ｼ啀redictNext 霑泌屓謨ｰ扈・ｼ檎ｬｬ荳荳ｪ蜈・ｴ蜿ゆｸ手ｯ・・・悟・菴吝｡ｫ蜈・next[]縲・
    -- Reset APL predictions array (module-level, reused across frames)
    -- 驥咲ｽｮ APL 鬚・ｵ区焚扈・ｼ域ｨ｡蝮礼ｺｧ・瑚ｷｨ蟶ｧ螟咲畑・・
    local currentTargetCount = 1
    if mAIInference then
        local aiCtx = mAIInference:GetContext()
        if aiCtx and aiCtx.targetCount then
            currentTargetCount = aiCtx.targetCount
        end
    end
    wipe(aplPredictions)  -- reset module-level table each frame
    if mAPLEngine and mAPLEngine.HasAPL and mAPLEngine:HasAPL()
       and (not battlefield or battlefield.targetValid == true) then
        context.predictiveEnabled = true
        -- FIX (P0-Bug2): Build a valid limitedState table from context
        local limitedState = {
            resource        = nil,
            resourceKnown   = false,
            resourceMax     = nil,
            cooldowns       = {},
            cooldownUnknown = {},
            chargeRecharges = {},
            inMeta          = false,
            targetCount     = 1,
            combatDuration  = 0,
            charges         = {},
            windows         = {},
            softBlocked     = softBlockedSpells,
        }

        -- Read the normalized SpecEnhancements resource config.
        -- 隸ｻ蜿也ｻ滉ｸ蜷守噪 SpecEnhancements 襍・ｺ宣・鄂ｮ縲・
        local powerType = 0  -- default to mana
        local specDetector = RA:GetModule("SpecDetector")
        if specDetector then
            local spec = specDetector:GetCurrentSpec()
            if spec and RA.SpecEnhancements and RA.SpecEnhancements[spec.specID] then
                local resConfig = RA.SpecEnhancements[spec.specID].resource
                if resConfig then
                    powerType = resConfig.powerType or 0
                end
            end
        end
        -- WOW 12.0 SECRET VALUE SAFE: wrap the API call in pcall (it can error in
        -- restricted contexts), then gate on issecretvalue() BEFORE any truth-test or
        -- comparison. `if rawPower and ...` evaluated the value first — that is the bug.
        -- WOW 12.0 SECRET VALUE 安全：先用 pcall 包住 API 调用（受限环境下会报错），
        -- 再在任何真值判断/比较之前过 issecretvalue()。原写法 `if rawPower and ...`
        -- 先对值做了真值判断，正是问题所在。
        local secretByPolicy = false
        if C_Secrets and C_Secrets.ShouldUnitPowerBeSecret then
            local okPolicy, policy = pcall(C_Secrets.ShouldUnitPowerBeSecret, "player", powerType)
            if okPolicy and not issecretvalue(policy) and policy == true then
                secretByPolicy = true
            end
        end
        if not secretByPolicy and UnitPower then
            local okPower, rawPower = pcall(UnitPower, "player", powerType)
            if okPower and not issecretvalue(rawPower) and type(rawPower) == "number" then
                limitedState.resource = rawPower
                limitedState.resourceKnown = true
            end
        end

        -- A public maximum can differ from the spec's static base (Fel-Scarred
        -- Havoc's pinned SimC trace has 170 Fury). Reject secret, invalid, or
        -- stale maxima before allowing the bounded forecast to use them.
        -- 公开的资源上限可能不同于专精静态基础值；秘密、无效或过期值均不进入预测。
        local maxSecretByPolicy = false
        if C_Secrets and C_Secrets.ShouldUnitPowerMaxBeSecret then
            local okPolicy, policy = pcall(C_Secrets.ShouldUnitPowerMaxBeSecret, "player", powerType)
            if not okPolicy or issecretvalue(policy) or policy == true then
                maxSecretByPolicy = true
            end
        end
        if not maxSecretByPolicy and UnitPowerMax then
            local okMax, rawMax = pcall(UnitPowerMax, "player", powerType)
            if okMax and not issecretvalue(rawMax) and type(rawMax) == "number"
               and rawMax > 0 and rawMax < math.huge
               and (not limitedState.resourceKnown or rawMax >= limitedState.resource) then
                limitedState.resourceMax = rawMax
            end
        end

        -- Overlay may infer ready for an unseen spell. Query the guarded API
        -- for simulator provenance instead of copying that inference as fact.
        -- 覆盖层可能推测未见技能已就绪；模拟器只接受安全 API 的实测状态。
        if mCooldownOverlay then
            local cds = mCooldownOverlay:GetCooldownStates()
            for sid in pairs(cds) do
                local remaining = RA:GetSpellCooldownSafe(sid)
                if not issecretvalue(remaining) and type(remaining) == "number"
                   and remaining >= 0 then
                    limitedState.cooldowns[sid] = remaining
                else
                    limitedState.cooldownUnknown[sid] = true
                end
            end
        end

        -- GCD spell 61304 is an observable clock only when the safe API
        -- provides a public, plausible duration.
        local _, _, _, gcdDuration = RA:GetSpellCooldownSafe(61304)
        if not issecretvalue(gcdDuration) and type(gcdDuration) == "number"
           and gcdDuration >= 0.75 and gcdDuration <= 1.5 then
            limitedState.gcdDuration = gcdDuration
        end

        ScanCharges(limitedState)

        -- Populate inMeta from APLEngine state
        limitedState.inMeta = mAPLEngine:IsMetaActive()

        -- Populate targetCount and combatDuration from AIInference if available
        -- 蜷梧慮隸ｻ蜿・targetCount 蜥・timeSincePull・碁∩蜈埼㍾螟崎ｰ・畑 GetContext()
        if mAIInference then
            local aiCtx = mAIInference:GetContext()
            if aiCtx then
                if aiCtx.targetCount then
                    currentTargetCount = aiCtx.targetCount
                end
                limitedState.combatDuration = aiCtx.timeSincePull or 0
                if aiCtx.windows then
                    limitedState.windows = aiCtx.windows
                end
            end
        end
        limitedState.targetCount = currentTargetCount
        if battlefield and battlefield.supported then
            limitedState.targetCount = battlefield.nearbyEnemies
            limitedState.targetCountKnown = battlefield.countComplete
            limitedState.targetValid = battlefield.targetValid
            limitedState.spellRange = battlefield.spellRange
            limitedState.windowUnknown = battlefield.windowUnknown
            limitedState.windowRemains = battlefield.windowRemains
            limitedState.inMetaKnown = battlefield.inMeta ~= nil
            -- Copy observed target windows, never reuse target-agnostic cast timers.
            -- 当前目标的观测替代与目标无关的施法计时猜测。
            wipe(observedWindows_reuse)
            observedWindows_reuse.demonic = limitedState.windows.demonic
            observedWindows_reuse.essence_break = battlefield.windows.essence_break
            limitedState.windows = observedWindows_reuse
            if battlefield.inMeta ~= nil then
                limitedState.inMeta = battlefield.inMeta
                limitedState.metaRemains = battlefield.metaRemains
            end
            currentTargetCount = battlefield.nearbyEnemies
        end
        context.aplState = limitedState

        -- Default to observation; explicit experimental opt-in can select a head.
        -- 默认只观测；显式实验选项可采用独立首位，并从实际首位预测后续。
        if independent then
            independent:Observe(limitedState)
            local selected = independent.GetExperimentalHead and independent:GetExperimentalHead(context.blizzSpell)
            if selected and IsSpellCastable(selected) then
                context.independentHead = selected
                -- blizzSpell is the legacy scoring/seed slot; diagnostics retain the reference.
                -- 保留原参考用于诊断；旧评分/预测首位字段改为实际选择的动作。
                context.blizzSpell = selected
            end
        end

        -- Increase depth to 3 to get better lookahead for the prediction bar
        local ok, result = pcall(mAPLEngine.PredictNext, mAPLEngine, context.blizzSpell, limitedState, 3)
        if ok and type(result) == "table" then
            aplPredictions = result
        end
    end

    -- First APL prediction participates in scoring
    -- 隨ｬ荳荳ｪ APL 鬚・ｵ句盾荳惹ｸｻ謗ｨ闕占ｯ・・
    if aplPredictions[1] then
        context.aplPred = aplPredictions[1]
    end

    if mAIInference then
        local aiCtx = mAIInference:GetContext()
        if aiCtx and aiCtx.inferred then
            context.aiPhase = aiCtx.inferred.combatPhase
            context.aiTip   = aiCtx.inferred.tip
            finalQueue.aiContext = {
                phase           = aiCtx.inferred.combatPhase,
                phaseConfidence = aiCtx.inferred.phaseConfidence,
                targetCount     = aiCtx.targetCount,
                tip             = aiCtx.inferred.tip,
                inferredResource = aiCtx.inferred.resourceState
            }
        end
    end

    if mCooldownOverlay then
        local cds = mCooldownOverlay:GetCooldownStates()
        finalQueue.cooldowns = finalQueue.cooldowns or {}
        wipe(finalQueue.cooldowns)
        local cIdx = 1
        -- GetCooldownStates() returns { [spellID] = {remaining, ready, texture, name, startTime, duration} }
        for spellID, cd in pairs(cds) do
            local isWhitelisted = RA.WhitelistSpells and RA.WhitelistSpells[spellID]
            if isWhitelisted then
                local snapshot = context.aplState
                local observed = snapshot and snapshot.cooldowns[spellID]
                local chargeCount = snapshot and snapshot.charges[spellID]
                if cd.ready and snapshot
                   and ((not issecretvalue(observed) and type(observed) == "number"
                         and observed <= 1.0)
                        or (not issecretvalue(chargeCount) and type(chargeCount) == "number"
                            and chargeCount > 0)) then
                    context.cdReadyList[spellID] = true
                end
                -- 蟆ｱ扈ｪ蜥悟・蜊ｴ荳ｭ逧・､ｧ諡幃・霑帛・ cooldowns 蛻苓｡ｨ萓・CooldownBar 譏ｾ遉ｺ
                -- Include both ready and on-cooldown major CDs in the bar
                cd.spellID = spellID  -- inject spellID for downstream consumers
                finalQueue.cooldowns[cIdx] = cd
                cIdx = cIdx + 1
            end
        end
    end

    if mDefensiveAdvisor then
        local def = mDefensiveAdvisor:GetActiveRecommendation()
        if def then
            context.defSpell  = def.spellID
            context.defUrgency = def.urgency
            finalQueue.defensive = def
        else
            finalQueue.defensive = nil
        end
    end

    -- 2. Build Candidates Map
    local candidates = candidates_reuse
    wipe(candidates)
    if context.blizzSpell and not PASSIVE_BLACKLIST[context.blizzSpell] and not RA:IsSpellPassive(context.blizzSpell) then
        candidates[context.blizzSpell] = true
    end
    if context.predictiveEnabled then
        if context.aplPred and context.aplPred.spellID then
            candidates[context.aplPred.spellID] = true
        end
        if context.defSpell then candidates[context.defSpell] = true end
        for sid, _ in pairs(context.cdReadyList) do candidates[sid] = true end
    end

    -- Blind-spot detection: APL rules that are CD-ready but absent from Blizzard's rotation list
    -- 逶ｲ蛹ｺ譽豬具ｼ哂PL 荳ｭ莨伜・郤ｧ霎・ｫ倅ｸ・CD 蟆ｱ扈ｪ縲∽ｽ・Blizzard 蠕ｪ邇ｯ蛻苓｡ｨ荳ｭ郛ｺ螟ｱ逧・橿閭ｽ
    if context.predictiveEnabled then
        local actionList = mAPLEngine:GetCurrentAPL()
        -- GetCurrentAPL returns the raw APL table; try to get a flat rule list
        local rules = nil
        if actionList then
            if actionList.rules then
                rules = actionList.rules
            elseif actionList.profiles then
                local profName = (mAPLEngine and mAPLEngine.GetProfileName)
                    and mAPLEngine:GetProfileName() or "default"
                local prof = actionList.profiles[profName] or actionList.profiles["default"]
                if prof then
                    if currentTargetCount >= 3 and prof.aoe then
                        rules = prof.aoe
                    else
                        rules = prof.singleTarget
                    end
                end
            end
        end
        if rules then
            for _, rule in ipairs(rules) do
                local sid = rule.spellID
                if sid and not rotationSpells[sid] then
                    -- 霍ｳ霑・悴蟄ｦ荵逧・､ｩ襍区橿閭ｽ・磯∩蜈榊屏 unlearned spell CD = 0 陲ｫ隸ｯ蛻､荳ｺ蟆ｱ扈ｪ・・
                    -- Skip unlearned talent spells (their CD returns 0, falsely appearing ready)
                    local isKnown = not IsPlayerSpell or IsPlayerSpell(sid)
                    if isKnown then
                        local stateOk = true
                        if rule.condition and mAPLEngine.EvaluateCondition and context.aplState then
                            local blindSpotState = {
                                cooldowns = context.aplState.cooldowns or {},
                                cooldownUnknown = context.aplState.cooldownUnknown or {},
                                resource = context.aplState.resource,
                                resourceKnown = context.aplState.resourceKnown,
                                inMeta = context.aplState.inMeta or false,
                                inMetaKnown = context.aplState.inMetaKnown,
                                lastCast = nil,
                                targetCount = context.aplState.targetCount or 1,
                                targetCountKnown = context.aplState.targetCountKnown,
                                combatDuration = context.aplState.combatDuration or 0,
                                charges = context.aplState.charges or {},
                                windows = context.aplState.windows or {},
                                windowUnknown = context.aplState.windowUnknown,
                            }
                            stateOk = mAPLEngine:EvaluateCondition(rule.condition, sid, blindSpotState)
                        end

                        -- A visual overlay's ready flag can be inferred from no
                        -- cast history; only public API data proves readiness.
                        -- 视觉层的就绪标记可能是推测，候选只采用公开实测数据。
                        local snapshot = context.aplState
                        local remaining = snapshot and snapshot.cooldowns[sid]
                        local knownCharge = snapshot and snapshot.charges[sid]
                        if remaining == nil and snapshot and not snapshot.cooldownUnknown[sid] then
                            local observed = RA:GetSpellCooldownSafe(sid)
                            if not issecretvalue(observed) and type(observed) == "number"
                               and observed >= 0 then
                                remaining = observed
                                snapshot.cooldowns[sid] = observed
                            else
                                snapshot.cooldownUnknown[sid] = true
                            end
                        end
                        if stateOk and ((not issecretvalue(knownCharge)
                           and type(knownCharge) == "number" and knownCharge > 0)
                           or (not issecretvalue(remaining)
                           and type(remaining) == "number" and remaining <= 1.0)) then
                            context.blindSpotCandidates[sid] = true
                            candidates[sid] = true
                        end
                    end
                end
            end
        end
    end

    for sid, _ in pairs(context.blindSpotCandidates) do candidates[sid] = true end

    -- 螳牙・鄂托ｼ夊ｿ・ｻ､謗牙ｷｲ遏･蝨ｨ CD 荳ｭ逧・咎会ｼ磯勁 Blizzard 謗ｨ闕仙柱 defensive 莉･螟厄ｼ・
    -- Safety net: drop candidates known to be on cooldown (> 1.0s remaining).
    -- Blizzard rec and defensive are exempt (may have charge/proc info we lack).
    -- FIX (OverridePair): CD safety net now also checks paired override IDs.
    -- If either spell in a pair is on CD, remove BOTH from candidates.
    -- 隕・尠蟇ｹ CD 螳牙・鄂托ｼ壼ｦよ棡莉ｻ荳隕・尠蟇ｹ謚閭ｽ蝨ｨ CD 荳ｭ・檎ｧｻ髯､荳､閠・・
    if mCooldownOverlay then
        local cds = mCooldownOverlay:GetCooldownStates()
        wipe(toRemove_reuse)
        local toRemove = toRemove_reuse
        for sid, _ in pairs(candidates) do
            local onCD = false
            local cdState = cds[sid]
            if cdState then
                if not cdState.ready and cdState.remaining and cdState.remaining > 1.0 then
                    onCD = true
                end
            else
                -- FIX (Round14-Bug2): 譛ｪ陲ｫ CooldownOverlay 霑ｽ雕ｪ逧・橿閭ｽ・檎畑 API 逶ｴ謗･譽譟･
                -- For spells not tracked by CooldownOverlay, fall back to direct API query
                onCD = IsSpellOnCooldown(sid)
            end
            -- Check paired override ID as well
            -- 蜷梧慮譽譟･隕・尠蟇ｹ驟榊ｯｹ ID
            if not onCD then
                local pairedID = RA.KNOWN_OVERRIDE_PAIRS and RA.KNOWN_OVERRIDE_PAIRS[sid]
                if pairedID then
                    local pairedState = cds[pairedID]
                    if pairedState and not pairedState.ready
                       and pairedState.remaining and pairedState.remaining > 1.0 then
                        onCD = true
                    end
                end
            end
            if onCD then
                -- Only exempt defensive spell
                -- 莉・賜髯､髦ｲ蠕｡謚閭ｽ
                if sid ~= context.defSpell then
                    toRemove[#toRemove + 1] = sid
                    -- Also mark paired ID for removal if it's a candidate
                    -- 蜷梧慮譬・ｮｰ驟榊ｯｹ ID 遘ｻ髯､
                    local pairedID = RA.KNOWN_OVERRIDE_PAIRS and RA.KNOWN_OVERRIDE_PAIRS[sid]
                    if pairedID and candidates[pairedID] and pairedID ~= context.defSpell then
                        toRemove[#toRemove + 1] = pairedID
                    end
                end
            end
        end
        for _, sid in ipairs(toRemove) do
            candidates[sid] = nil
            context.blindSpotCandidates[sid] = nil
        end
    end

    -- 霑・ｻ､陲ｫ蜉ｨ謚閭ｽ・井ｸ榊庄譁ｽ謾ｾ逧・橿閭ｽ荳榊ｺ疲・荳ｺ謗ｨ闕仙咎会ｼ・
    -- Filter passive spells (non-castable spells must not appear as candidates)
    do
        wipe(passiveRemove_reuse)
        local passiveToRemove = passiveRemove_reuse
        for sid, _ in pairs(candidates) do
            if RA:IsSpellPassive(sid) or PASSIVE_BLACKLIST[sid] then
                passiveToRemove[#passiveToRemove + 1] = sid
            end
        end
        for _, sid in ipairs(passiveToRemove) do
            candidates[sid] = nil
            context.blindSpotCandidates[sid] = nil
        end
    end

    -- 霓ｯ螻剰反・壽命謾ｾ蜷・SOFT_BLOCK_DURATION 遘貞・・御ｸｴ譌ｶ髦ｻ豁｢蛻壽命謾ｾ謚閭ｽ陲ｫ謗ｨ闕・
    -- Soft-block filter: suppress recently-cast spells until real CD data arrives.
    -- Exempts Blizzard rec and defensive spell in case of charges / procs.
    do
        local now = GetTime()
        wipe(sbRemove_reuse)
        local sbToRemove = sbRemove_reuse
        for sid, expiry in pairs(softBlockedSpells) do
            if now < expiry then
                if sid ~= context.blizzSpell and sid ~= context.defSpell then
                    sbToRemove[#sbToRemove + 1] = sid
                end
            end
        end
        for _, sid in ipairs(sbToRemove) do
            candidates[sid] = nil
            context.blindSpotCandidates[sid] = nil
        end
    end

    -- 霑・ｻ､譛ｪ蟄ｦ荵逧・橿閭ｽ・壼勘諤∵｣譟･邇ｩ螳ｶ蠖灘燕螟ｩ襍具ｼ悟宵謗ｨ闕仙ｷｲ蟄ｦ謚閭ｽ
    -- Filter unlearned spells: dynamically check current talents, only recommend known spells
    do
        wipe(unlearnedRemove_reuse)
        local unlearnedRemove = unlearnedRemove_reuse
        for sid, _ in pairs(candidates) do
            if IsPlayerSpell then
                local okK, isK = pcall(IsPlayerSpell, sid)
                if okK and not isK then
                    unlearnedRemove[#unlearnedRemove + 1] = sid
                end
            end
        end
        for _, sid in ipairs(unlearnedRemove) do
            candidates[sid] = nil
            context.blindSpotCandidates[sid] = nil
        end
    end

    -- 3. Score & Rank
    local scored = scored_reuse
    local nScored = 0
    for sid, _ in pairs(candidates) do
        local score, src = CalculateScore(sid, context, weights, aplPredictions)
        if score > 0 then
            nScored = nScored + 1
            if not scored[nScored] then scored[nScored] = {} end
            scored[nScored].spellID = sid
            scored[nScored].score = score
            scored[nScored].source = src
        end
    end
    for i = nScored + 1, #scored do
        scored[i] = nil
    end
    table.sort(scored, function(a, b) return a.score > b.score end)

    -- 縲先眠蠅槭第怙扈亥ｮ牙・鄂托ｼ壼ｯｹ scored 蛻苓｡ｨ蛛・IsSpellRecommendable 鬪瑚ｯ・
    -- Final safety net: validate scored entries with RA:IsSpellRecommendable
    -- 蛟貞ｺ城″蜴・ｻ･螳牙・遘ｻ髯､荳埼夊ｿ・噪譚｡逶ｮ
    for i = #scored, 1, -1 do
        if not RA:IsSpellRecommendable(scored[i].spellID)
           or (battlefield and battlefield.spellRange[scored[i].spellID] == false) then
            table.remove(scored, i)
        end
    end

    -- Score still ranks fallback candidates, but an available Blizzard action owns
    -- slot 1. In particular, the heuristic blind-spot bonus must not outrank it.
    -- 评分仍用于排列后备候选，但可用的暴雪动作固定占据 slot 1；盲区启发式不能压过它。
    PromoteAuthoritativeMain(scored, context.blizzSpell)

    -- 4. Populate Final Queue
    if #scored > 0 then
        local topScore = scored[1].score
        local topConf  = math.min(1.0, topScore / 1.5)

        -- FIX (Bug2): Save the previous main spell ID BEFORE updating,
        -- so GetLastRecommendedSpellID() can return the pre-cast value.
        -- 菫晏ｭ俶立荳ｻ謗ｨ闕撰ｼ御ｾ・AccuracyTracker 蝨ｨ譁ｽ豕墓・蜉溷錘豈泌ｯｹ縲・
        lastRecommendedSpellID = finalQueue.main and finalQueue.main.spellID or nil

        finalQueue.main = {
            spellID    = scored[1].spellID,
            source     = (context.independentHead == scored[1].spellID) and "INDEPENDENT" or scored[1].source,
            confidence = topConf
        }

        -- 霑ｽ雕ｪ荳ｻ謗ｨ闕先弍蜷ｦ蜿伜喧・井ｾ帛・莉也ｳｻ扈滉ｽｿ逕ｨ・・
        -- Track main spell change for other systems.
        local newMainID = finalQueue.main and finalQueue.main.spellID or nil
        if prevMainSpellID ~= newMainID then
            prevMainSpellID = newMainID
        end

        -- Populate next[] only from the ordered APL simulation.
        -- 后续栏只使用有序 APL 模拟，不能用独立评分候选伪装成施法序列。
        local nIdx = 1

        -- When Blizzard is absent, APL step 1 becomes the head and only that exact
        -- entry is consumed. A later repeated spellID remains a valid sequence step.
        -- 无暴雪建议时，APL 第一步成为主位，只消费这一条记录；后续相同 spellID
        -- 仍可能是合法的连续施法。
        local aplStartIndex = 1
        local tailIsSeeded = context.blizzSpell == finalQueue.main.spellID
        if not tailIsSeeded and aplPredictions[1]
           and aplPredictions[1].spellID == finalQueue.main.spellID then
            aplStartIndex = 2
            tailIsSeeded = true
        end

        if tailIsSeeded then
            for i = aplStartIndex, #aplPredictions do
                if nIdx > 5 then break end
                local sid = aplPredictions[i].spellID
                if IsFutureSpellSafe(sid) then
                    if not finalQueue.next[nIdx] then
                        finalQueue.next[nIdx] = { spellID = 0, confidence = 0 }
                    end
                    finalQueue.next[nIdx].spellID    = sid
                    finalQueue.next[nIdx].confidence = aplPredictions[i].confidence or 0.7
                    nIdx = nIdx + 1
                else
                    break
                end
            end
        end

        -- NeuralPredictor remains available for offline diagnostics and accuracy
        -- research, but its synthetic DT/Markov output is not an authoritative action
        -- source. Do not put it in the actionable queue until it is calibrated against
        -- live outcomes. 可继续用于离线诊断，但未经真机校准的学习结果不进入动作队列。

        for i = nIdx, #finalQueue.next do
            finalQueue.next[i] = nil
        end

        -- 豈乗ｬ｡ AssembleQueue 驛ｽ騾夂衍 UI 譖ｴ譁ｰ・域叛蝨ｨ蝪ｫ蜈・next[] 荵句錘・・
        -- Always fire AFTER filling next[] so the UI sees the complete data.
        local eh = RA:GetModule("EventHandler")
        if eh then eh:Fire("ROTAASSIST_QUEUE_UPDATED", finalQueue.main) end
    else
        -- FIX (Bug2): Also reset lastRecommendedSpellID when queue clears
        lastRecommendedSpellID = finalQueue.main and finalQueue.main.spellID or nil
        finalQueue.main = nil
        for i = 1, #finalQueue.next do finalQueue.next[i] = nil end
        -- 髦溷・貂・ｩｺ・壽峩譁ｰ霑ｽ雕ｪ蛟ｼ蟷ｶ譌譚｡莉ｶ騾夂衍 UI
        -- Queue cleared: update tracking and always notify UI.
        if prevMainSpellID ~= nil then
            prevMainSpellID = nil
        end
        local eh = RA:GetModule("EventHandler")
        if eh then eh:Fire("ROTAASSIST_QUEUE_UPDATED", nil) end
    end
end

local function onUpdate(_, elapsed_dt)
    lastUpdate = lastUpdate + elapsed_dt
    if lastUpdate >= throttleInterval then
        lastUpdate = 0
        AssembleQueue()
    end
end

-- Exposed only for deterministic integration tests; production updates still run
-- through the frame/event path. 仅供确定性集成测试使用。
SmartQueueManager._AssembleQueue = AssembleQueue

------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------

---Get the finalized, prioritized prediction queue.
---闔ｷ蜿匁怙扈井ｼ伜・謗貞ｺ冗噪鬚・ｵ矩弌蛻励・
---@return table
function SmartQueueManager:GetFinalQueue()
    return finalQueue
end

---Get the main spell ID that was recommended in the *previous* frame.
---Returns nil if there was no prior recommendation or the queue was empty.
---闔ｷ蜿紋ｸ贋ｸ蟶ｧ逧・ｸｻ謗ｨ闕先橿閭ｽ ID・檎畑莠取命豕墓・蜉溷錘豈泌ｯｹ蜃・｡ｮ蠎ｦ縲・
---@return number|nil spellID
function SmartQueueManager:GetLastRecommendedSpellID()
    return lastRecommendedSpellID
end

---Borrowed independent policy diagnostics; not a DPS guarantee.
---独立策略诊断快照；不代表伤害最优保证。
function SmartQueueManager:GetIndependentStatus()
    local independent = RA:GetModule("IndependentObserver")
    return independent and independent:GetStatus() or nil
end

---Flatten finalQueue into a plain display-oriented snapshot.
---Legacy shape kept for the integration tests; no addon module reads it today
---(UI consumes ROTAASSIST_QUEUE_UPDATED / GetFinalQueue instead).
---把 finalQueue 拍平成面向显示的快照。该格式为集成测试保留；
---当前插件内已无模块读取（UI 走 ROTAASSIST_QUEUE_UPDATED / GetFinalQueue）。
---@return table
function SmartQueueManager:GetDisplayData()
    local data = {
        main        = nil,
        predictions = {},
        cooldowns   = finalQueue.cooldowns,
        defensive   = finalQueue.defensive,
        aiContext   = finalQueue.aiContext
    }

    if finalQueue.main then
        data.main = {
            spellID    = finalQueue.main.spellID,
            confidence = finalQueue.main.confidence,
            source     = finalQueue.main.source
        }
    end

    for i, nxt in ipairs(finalQueue.next) do
        data.predictions[i] = {
            spellID    = nxt.spellID,
            confidence = nxt.confidence
        }
    end

    return data
end

------------------------------------------------------------------------
-- Module Lifecycle
------------------------------------------------------------------------

function SmartQueueManager:OnInitialize()
    updateFrame = CreateFrame("Frame")
    updateFrame:Hide()
end

function SmartQueueManager:OnEnable()
    mBridge           = RA:GetModule("AssistedCombatBridge")
    mAIInference      = RA:GetModule("AIInference")
    mAPLEngine        = RA:GetModule("APLEngine")
    mCooldownOverlay  = RA:GetModule("CooldownOverlay")
    mDefensiveAdvisor = RA:GetModule("DefensiveAdvisor")

    -- Seed the cadence from the current combat state, then keep it in sync below.
    -- 按当前战斗状态初始化节奏，随后由事件保持同步。
    throttleInterval = InCombatLockdown() and THROTTLE_COMBAT or THROTTLE_IDLE

    updateFrame:SetScript("OnUpdate", onUpdate)
    updateFrame:Show()

    -- Drive APLEngine meta-state from actual spell casts; also apply soft-block and
    -- force-refresh recommendation cache so the UI never lags behind a cast.
    -- 譁ｽ豕墓・蜉溷錘・壽峩譁ｰ蜿倩ｺｫ迥ｶ諤√∬ｽｯ螻剰反縲∝､ｱ謨・Bridge 郛灘ｭ倥・㍾蟒ｺ髦溷・
    local eh = RA:GetModule("EventHandler")
    if eh then
        eh:Subscribe("ROTAASSIST_CHARACTER_CHANGED", "SmartQueueManager", function()
            local independent = RA:GetModule("IndependentObserver")
            if independent then independent:Reset() end
            lastKnownBlizzSpell, channelNextSpell, lastRecommendedSpellID = nil, nil, nil
            wipe(softBlockedSpells)
            wipe(aplPredictions)
            wipe(finalQueue.next)
            finalQueue.main = nil
            InvalidateChargeSubset()
            lastUpdate = throttleInterval
            eh:Fire("ROTAASSIST_QUEUE_UPDATED", nil)
        end)
        eh:Subscribe("ROTAASSIST_TARGET_CONTEXT_CHANGED", "SmartQueueManager", function()
            local independent = RA:GetModule("IndependentObserver")
            if independent then independent:Reset() end
            lastKnownBlizzSpell = nil
            channelNextSpell = nil
            lastRecommendedSpellID = nil
            wipe(aplPredictions)
            wipe(finalQueue.next)
            finalQueue.main = nil
            lastUpdate = throttleInterval
            eh:Fire("ROTAASSIST_QUEUE_UPDATED", nil)
        end)
        eh:Subscribe("ROTAASSIST_INDEPENDENT_MODE_CHANGED", "SmartQueueManager", function()
            if RA:GetModule("IndependentObserver") then RA:GetModule("IndependentObserver"):Reset() end
            lastKnownBlizzSpell, channelNextSpell, lastRecommendedSpellID = nil, nil, nil
            wipe(aplPredictions)
            wipe(finalQueue.next)
            finalQueue.main = nil
            lastUpdate = throttleInterval
            eh:Fire("ROTAASSIST_QUEUE_UPDATED", nil)
        end)
        -- Combat cadence: full rate in combat, widened out of combat. The queue keeps
        -- being rebuilt either way so MainDisplay never goes stale.
        -- 战斗节奏：战斗内全速，脱战放宽。两种状态下队列都持续重建，MainDisplay 不会失效。
        eh:Subscribe("PLAYER_REGEN_DISABLED", "SmartQueueManager_Throttle", function()
            throttleInterval = THROTTLE_COMBAT
            -- Rebuild on the very next frame so the pull is not delayed by the idle interval.
            -- 立刻在下一帧重建，避免起手被脱战间隔拖慢。
            lastUpdate = THROTTLE_COMBAT
        end)

        eh:Subscribe("PLAYER_REGEN_ENABLED", "SmartQueueManager_Throttle", function()
            throttleInterval = THROTTLE_IDLE
        end)

        -- Which spells have charges is spec- and talent-dependent, so both events
        -- force the next scan back over the full whitelist. PLAYER_ENTERING_WORLD is
        -- included because SpecDetector fires ROTAASSIST_SPEC_CHANGED from its own
        -- OnEnable — earlier in MODULE_ORDER than this module, so the login-time
        -- broadcast lands before this subscription exists. Without it the very first
        -- subset could be derived while the spellbook is still populating.
        -- 哪些技能有充能取决于专精与天赋，这些事件都让下次扫描回到完整白名单。
        -- 之所以加 PLAYER_ENTERING_WORLD：SpecDetector 在自己的 OnEnable 里就广播了
        -- ROTAASSIST_SPEC_CHANGED，而它在 MODULE_ORDER 中位于本模块之前，登录时那次
        -- 广播早于本订阅建立。缺了这道保险，首个子集可能在法术书尚未加载完时就被推导出来。
        eh:Subscribe("ROTAASSIST_SPEC_CHANGED",  "SmartQueueManager_Charges", InvalidateChargeSubset)
        eh:Subscribe("ROTAASSIST_SPEC_CHANGED",  "SmartQueueManager_SpecReset", function()
            -- Never carry the previous spec's sticky or simulated tail across a swap.
            -- 切换专精时绝不沿用上一专精的粘滞建议或模拟后续。
            lastKnownBlizzSpell = nil
            channelNextSpell = nil
            wipe(softBlockedSpells)
            for i = 1, #finalQueue.next do finalQueue.next[i] = nil end
        end)
        eh:Subscribe("PLAYER_TALENT_UPDATE",     "SmartQueueManager_Charges", InvalidateChargeSubset)
        eh:Subscribe("PLAYER_ENTERING_WORLD",    "SmartQueueManager_Charges", InvalidateChargeSubset)

        eh:Subscribe("ROTAASSIST_SPELLCAST_SUCCEEDED", "SmartQueueManager", function(_, unit, _, spellID)
            if unit ~= "player" then return end

            -- 1. Update Metamorphosis state in APLEngine
            if mAPLEngine and mAPLEngine.SetMetaStateFromCast then
                mAPLEngine:SetMetaStateFromCast(spellID)
            end

            -- 2. Soft-block: suppress just-cast spell until SPELL_UPDATE_COOLDOWN confirms real CD.
            --    Only block spells with a meaningful CD (>= 3s) listed in WhitelistSpells.
            --    莉・ｯｹ WhitelistSpells 荳ｭ cdSeconds >= 3 逧・橿閭ｽ蜷ｯ逕ｨ霓ｯ螻剰反
            -- FIX (OverridePair): Also soft-block the paired override ID.
            -- 蜷梧慮蟇ｹ隕・尠蟇ｹ謚閭ｽ譁ｽ蜉霓ｯ螻剰反・亥ｦよ命謾ｾ Death Sweep 蜷主酔譌ｶ螻剰反 Blade Dance・峨・
            local wsInfo = RA.WhitelistSpells and RA.WhitelistSpells[spellID]
            if wsInfo and wsInfo.cdSeconds and wsInfo.cdSeconds >= 3 then
                local blockExpiry = GetTime() + SOFT_BLOCK_DURATION
                softBlockedSpells[spellID] = blockExpiry
                local pairedID = RA.KNOWN_OVERRIDE_PAIRS and RA.KNOWN_OVERRIDE_PAIRS[spellID]
                if pairedID then
                    softBlockedSpells[pairedID] = blockExpiry
                end
            end

            -- 3. Invalidate the Bridge recommendation cache so the next call to
            --    GetCurrentRecommendation() fetches a fresh Blizzard spell.
            --    螟ｱ謨・Bridge 郛灘ｭ假ｼ御ｸ区ｬ｡遶句綾諡ｿ蛻ｰ譛譁ｰ謗ｨ闕・
            if mBridge and mBridge.InvalidateCache then
                mBridge:InvalidateCache()
            end

            -- 4. Clear sticky Blizzard spell if we just cast it 窶・unless it's a channeled
            --    spell. During a channel the sticky should keep showing what comes AFTER.
            --    蠑募ｯｼ謚閭ｽ譁ｽ豕募錘荳肴ｸ・勁 sticky・瑚ｮｩ蠑募ｯｼ譛滄龍扈ｧ扈ｭ譏ｾ遉ｺ荳倶ｸ豁･謚閭ｽ
            -- FIX (OverridePair): Also clear when paired ID matches (e.g. cast Death Sweep
            -- while sticky is Blade Dance).
            -- 隕・尠蟇ｹ荵滓ｸ・勁 sticky・亥ｦ・sticky 荳ｺ Blade Dance 菴・命謾ｾ莠・Death Sweep・峨・
            if lastKnownBlizzSpell then
                local shouldClear = (lastKnownBlizzSpell == spellID)
                if not shouldClear then
                    local pairedID = RA.KNOWN_OVERRIDE_PAIRS and RA.KNOWN_OVERRIDE_PAIRS[spellID]
                    if pairedID and lastKnownBlizzSpell == pairedID then
                        shouldClear = true
                    end
                end
                if shouldClear and not CHANNELED_SPELL_IDS[spellID] then
                    lastKnownBlizzSpell = nil
                end
            end

            -- 5. Trigger an immediate queue rebuild.
            --    遶句綾驥榊ｻｺ髦溷・
            lastUpdate = throttleInterval
            AssembleQueue()
        end)

        -- 蠖・SPELL_UPDATE_COOLDOWN 隗ｦ蜿第慮・檎悄螳・CD 謨ｰ謐ｮ蟾ｲ蟆ｱ扈ｪ・壽ｸ・勁霓ｯ螻剰反蟷ｶ遶句綾驥榊ｻｺ髦溷・
        -- When real CD data arrives, clear soft-blocks and rebuild to reflect true CD state.
        eh:Subscribe("ROTAASSIST_CD_UPDATED", "SmartQueueManager", function()
            if next(softBlockedSpells) then
                wipe(softBlockedSpells)
                lastUpdate = throttleInterval
                AssembleQueue()
            end
        end)

        -- 蠑募ｯｼ蠑蟋具ｼ壼ｿｫ辣ｧ蠖灘燕 APL 鬚・ｵ・step-1 逧・spellID・御ｽ應ｸｺ蠑募ｯｼ譛・sticky fallback
        -- Channel start: capture APL step-1 spellID so UI shows next-spell during channel.
        eh:Subscribe("ROTAASSIST_CHANNEL_START", "SmartQueueManager", function(_, unit)
            if unit ~= "player" then return end
            channelNextSpell = aplPredictions and aplPredictions[1]
                and aplPredictions[1].spellID or nil
        end)

        -- 蠑募ｯｼ扈捺據謌冶｢ｫ謇捺妙譌ｶ貂・勁 channelNextSpell・梧△螟榊ｸｸ隗・耳闕宣ｻ霎・
        -- Clear channelNextSpell on channel end or interrupt to resume normal logic.
        local function onChannelEnd()
            channelNextSpell = nil
        end
        eh:Subscribe("ROTAASSIST_SPELLCAST_STOP",        "SmartQueueManager_Chan", onChannelEnd)
        eh:Subscribe("ROTAASSIST_SPELLCAST_INTERRUPTED", "SmartQueueManager_Chan", onChannelEnd)
    end
end

function SmartQueueManager:OnDisable()
    local eh = RA:GetModule("EventHandler")
    if eh then
        -- Each key owns a distinct subset of subscriptions. Remove all of them so
        -- a disabled queue cannot react to casts/spec changes, and re-enable starts
        -- from exactly one callback per event.
        -- 每个 key 管理一组独立订阅；全部解绑，确保禁用后不再响应事件，重新启用时
        -- 每个事件也只恢复一个回调。
        eh:UnsubscribeAll("SmartQueueManager")
        eh:UnsubscribeAll("SmartQueueManager_Throttle")
        eh:UnsubscribeAll("SmartQueueManager_Charges")
        eh:UnsubscribeAll("SmartQueueManager_SpecReset")
        eh:UnsubscribeAll("SmartQueueManager_Chan")
    end

    if updateFrame then
        updateFrame:SetScript("OnUpdate", nil)
        updateFrame:Hide()
    end
    prevMainSpellID        = nil
    lastRecommendedSpellID = nil
    lastKnownBlizzSpell    = nil
    channelNextSpell       = nil
    wipe(softBlockedSpells)
    wipe(aplPredictions)
    for i = 1, #finalQueue.next do finalQueue.next[i] = nil end
    finalQueue.main = nil
    finalQueue.defensive = nil
    finalQueue.aiContext = nil

    mBridge           = nil
    mAIInference      = nil
    mAPLEngine        = nil
    mCooldownOverlay  = nil
    mDefensiveAdvisor = nil
end
