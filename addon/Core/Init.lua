---@class RotaAssist
---@field modules table<string, table> Registered module table
---@field version string Addon version string
---@field debugMode boolean Whether debug output is enabled
---@field locale table Current locale table (L)
---@field db table SavedVariables reference (set after ADDON_LOADED)

------------------------------------------------------------------------
-- RotaAssist - Core Initialization
-- Addon bootstrap, module registry, slash commands, and event frame.
------------------------------------------------------------------------

local ADDON_NAME, NS = ...

--- Global addon namespace
RotaAssist = LibStub("AceAddon-3.0"):NewAddon("RotaAssist", "AceConsole-3.0", "AceEvent-3.0")
local RA = RotaAssist
NS.RA = RA

--- Addon metadata
-- FIX (Issue 8/Suggestion): prefer C_AddOns.GetAddOnMetadata if available
RA.name    = ADDON_NAME
RA.version = (C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata)(ADDON_NAME, "Version") or "dev"
RA.debugMode = false

--- Module registry
RA.modules = {}

------------------------------------------------------------------------
-- Module Registration System
------------------------------------------------------------------------

-- FIX (Issue 3): Stable module initialisation order.
-- Add modules here in the exact sequence they should be OnInitialize'd /
-- OnEnable'd. Modules not listed will still be called, but AFTER these.
local MODULE_ORDER = {
    -- Core (data layer first, then event infrastructure)
    "SavedVars",
    "EventHandler",
    "CharacterState",
    -- Engine (depends on Data + Core modules)
    "SpecDetector",
    "AssistedCombatBridge",
    "TargetContext",
    "AccuracyTracker",
    "AIInference",
    "CastHistoryRecorder",
    "PatternDetector",
    "NeuralPredictor",
    "APLEngine",
    "IndependentDecision",
    "IndependentConsensus",
    "ResourceEvidence",
    "PublicAuraFacts",
    "IndependentObserver",
    "SmartQueueManager",
    "CooldownOverlay",
    "CDMHook",
    "DefensiveAdvisor",
    "InterruptAdvisor",
    "PrePullChecker",
    -- UI (depends on everything above)
    "Widgets",
    "MainDisplay",
    "CooldownPanel",
    "MinimapButton",
    "ConfigPanel",
}

---Register a module with the addon.
---Every module must call this during file load so the core can
---initialize it after PLAYER_LOGIN.
---@param name string Unique module name (PascalCase)
---@param moduleTable table The module table with optional :OnInitialize() and :OnEnable()
---@return table moduleTable The same table, for convenience
function RA:RegisterModule(name, moduleTable)
    if self.modules[name] then
        self:PrintWarning("Module already registered: " .. name)
        return self.modules[name]
    end
    moduleTable._name = name
    moduleTable._enabled = false
    self.modules[name] = moduleTable
    return moduleTable
end

---Retrieve a registered module by name.
---@param name string Module name
---@return table|nil module The module table, or nil if not found
function RA:GetModule(name)
    return self.modules[name]
end

------------------------------------------------------------------------
-- Debug & Output Utilities
------------------------------------------------------------------------

--- Color constants
local COLORS = {
    PREFIX  = "|cFF00CCFF",  -- cyan
    WARNING = "|cFFFF8800",  -- orange
    ERROR   = "|cFFFF0000",  -- red
    DEBUG   = "|cFF888888",  -- grey
    RESET   = "|r",
}

local PREFIX = COLORS.PREFIX .. "[RotaAssist]" .. COLORS.RESET .. " "

---Print a standard message to chat.
---@param msg string
function RA:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. tostring(msg))
end

---Print a warning message to chat.
---@param msg string
function RA:PrintWarning(msg)
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. COLORS.WARNING .. tostring(msg) .. COLORS.RESET)
end

---Print an error message to chat.
---@param msg string
function RA:PrintError(msg)
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. COLORS.ERROR .. tostring(msg) .. COLORS.RESET)
end

---Print a debug message (only when debugMode is enabled).
---@param msg string
function RA:PrintDebug(msg)
    if not self.debugMode then return end
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. COLORS.DEBUG .. tostring(msg) .. COLORS.RESET)
end

------------------------------------------------------------------------
-- WOW 12.0 SECRET VALUE SAFE: 全局工具函数
------------------------------------------------------------------------

--- 安全获取法术冷却剩余时间
--- @param spellID number
--- @return number|nil remaining 剩余秒数，nil=無法読取
--- @return boolean|nil ready 是否就绪，nil=無法判断
--- @return number|nil start CD 开始时间，nil=secret
--- @return number|nil duration CD 总时长，nil=secret
function RA:GetSpellCooldownSafe(spellID)
    if issecretvalue(spellID) then
        return nil, nil, nil, nil
    end
    if type(spellID) ~= "number" or spellID <= 0 then
        return 0, true, 0, 0
    end
    if not (C_Spell and C_Spell.GetSpellCooldown) then
        return nil, nil, nil, nil
    end

    local ok, cdInfo = pcall(C_Spell.GetSpellCooldown, spellID)
    if not ok or type(cdInfo) ~= "table" then
        return nil, nil, nil, nil
    end

    -- Blizzard documents isEnabled=false as a cooldown on hold. In that state
    -- duration may be zero, but zero does not establish readiness. isActive=false
    -- also describes an ordinary inactive cooldown, so do not gate on isActive.
    -- isEnabled=false 表示冷却暂停；此时 duration=0 不等于可施放。
    local enabled = cdInfo.isEnabled
    if issecretvalue(enabled) then
        return nil, nil, nil, nil
    end
    if enabled == false then
        return nil, nil, nil, nil
    end

    local dur = cdInfo.duration
    local st  = cdInfo.startTime

    -- WOW 12.0 SECRET VALUE SAFE: issecretvalue() must precede the nil truth-test.
    -- A truth-test on a secret value is itself a violation, so this ordering matters.
    -- WOW 12.0 SECRET VALUE 安全：issecretvalue() 必须早于 nil 真值判断。
    -- 对 secret 值做真值判断本身就是违规，所以这两步的顺序不可颠倒。
    if issecretvalue(dur) or issecretvalue(st) then
        return nil, nil, nil, nil
    end

    if not dur or not st then
        return nil, nil, nil, nil
    end

    -- Charge-spell handling: when duration is short (GCD range),
    -- check C_Spell.GetSpellCharges for the real cooldown state.
    if dur > 0 and dur < 2.5 then
        local chOk, chInfo = pcall(C_Spell.GetSpellCharges, spellID)
        if chOk and type(chInfo) == "table" then
            local mc = chInfo.maxCharges
            if not issecretvalue(mc) and type(mc) == "number" and mc > 1 then
                local cc = chInfo.currentCharges
                if not issecretvalue(cc) and type(cc) == "number" and cc > 0 then
                    local now = GetTime()
                    local gcdRemain = (st + dur) - now
                    if gcdRemain <= 0 then
                        return 0, true, 0, 0
                    end
                    return gcdRemain, false, st, dur
                else
                    local cst = chInfo.cooldownStartTime
                    local cdur = chInfo.cooldownDuration
                    if not issecretvalue(cst) and not issecretvalue(cdur)
                       and type(cst) == "number" and type(cdur) == "number"
                       and cdur > 0 then
                        local now = GetTime()
                        local realRemaining = (cst + cdur) - now
                        if realRemaining <= 0 then
                            return 0, true, cst, cdur
                        end
                        return realRemaining, false, cst, cdur
                    end
                    -- secret fields: fall through to standard path
                end
            end
            -- maxCharges is secret or <= 1: fall through to standard path
        end
    end

    -- Standard path
    if dur <= 0 then
        return 0, true, 0, 0
    end

    local now = GetTime()
    local remaining = (st + dur) - now
    if remaining <= 0 then
        return 0, true, st, dur
    end

    return remaining, false, st, dur
end

--- Check if a spell is a passive (non-castable) ability.
--- 检测技能是否为被动技能（不可施放）。
--- WoW 12.0: C_Spell.IsSpellPassive or fallback to IsPassiveSpell
---@param spellID number
---@return boolean isPassive
function RA:IsSpellPassive(spellID)
    if not spellID then return false end

    -- 硬编码已知被动天赋：12.0 API 对部分天赋系统被动返回 false，必须手动补充
    -- Hardcoded passives: WoW 12.0 API misidentifies some talent-system passives
    local KNOWN_PASSIVES = RA.Registry and RA.Registry.PASSIVE_BLACKLIST or {}
    if KNOWN_PASSIVES[spellID] then return true end

    -- Primary: WoW 12.0 API
    if C_Spell and C_Spell.IsSpellPassive then
        local ok, result = pcall(C_Spell.IsSpellPassive, spellID)
        if ok then return result == true end
    end
    -- Fallback: legacy API
    if IsPassiveSpell then
        local ok, result = pcall(IsPassiveSpell, spellID)
        if ok then return result == true end
    end
    -- Last resort: check if spell has no cast time AND is not on GCD
    -- (heuristic, not 100% reliable)
    return false
end

--- Resolve spell override (detect talent replacements)
--- 检测技能覆盖关系（如点了天赋后 Time Skip 变为 Interwoven Threads）
---@param spellID number
---@return number resolvedID
---@return boolean wasOverridden
function RA:ResolveSpellOverride(spellID)
    if not spellID or spellID == 0 then return spellID, false end

    -- 1. Try C_Spell.GetOverrideSpell (WoW 12.0)
    if C_Spell and C_Spell.GetOverrideSpell then
        local ok, overrideID = pcall(C_Spell.GetOverrideSpell, spellID)
        if ok and overrideID and overrideID ~= spellID then
            return overrideID, true
        end
    end

    -- 2. Fallback to FindSpellOverrideByID (Legacy/11.x)
    if FindSpellOverrideByID then
        local ok, overrideID = pcall(FindSpellOverrideByID, spellID)
        if ok and overrideID and overrideID ~= spellID then
            return overrideID, true
        end
    end

    return spellID, false
end

--- Check if a spell is safe to display as a recommendation.
--- Multi-layer runtime filter (MaxDps CheckSpellUsable pattern):
---   1. Reject nil / 0 / auto-attack (6603)
---   2. Resolve overrides (talent replacements)
---   3. Reject passive spells via RA:IsSpellPassive
---   4. Reject unlearned spells via IsPlayerSpell
---   5. Reject unusable spells via C_Spell.IsSpellUsable (pcall-protected)
--- 推荐可用性の综合チェック（被動/未習得/使用不可を排除）
---@param spellID number
---@return boolean isRecommendable
function RA:IsSpellRecommendable(spellID)
    -- 1. Nil / 0 / auto-attack
    if not spellID or spellID == 0 or spellID == 6603 then return false end

    -- 2. Resolve overrides & check passive
    local resolvedID, wasOverridden = self:ResolveSpellOverride(spellID)
    if wasOverridden and self:IsSpellPassive(resolvedID) then
        return false
    end

    -- 3. Passive spell check (original ID)
    if self:IsSpellPassive(spellID) then return false end

    -- 4. Unlearned spell check
    if IsPlayerSpell then
        local okK, known = pcall(IsPlayerSpell, spellID)
        if okK and not known then return false end
    end

    -- 5. C_Spell.IsSpellUsable runtime gate
    if C_Spell and C_Spell.IsSpellUsable then
        -- Check both original and resolved ID to be safe
        local checkID = wasOverridden and resolvedID or spellID
        local okU, usable = pcall(C_Spell.IsSpellUsable, checkID)
        if okU and issecretvalue(usable) then return false end
        if okU and usable == false then return false end
    end

    return true
end

------------------------------------------------------------------------
-- Known Override Pairs (shared cooldown / form-swap spells)
-- 已知覆盖对：共享 CD 或变身切换的技能对照表
-- FIX (OverridePair): Bidirectional mapping so any spell can find its
-- paired form. Used by SmartQueue, CooldownOverlay, and APLEngine to
-- treat A↔B as a single cooldown.
------------------------------------------------------------------------

RA.Registry = RA.Registry or {}
RA.KNOWN_OVERRIDE_PAIRS = RA.Registry.OVERRIDE_PAIRS

--- Return the "base" (lower-ID) form of a spell if it belongs to an
--- override pair, or the spell itself if not paired.
--- 返回覆盖对中 ID 较小的「基底」版本；不在表中则返回自身。
--- FIX (OverridePair): Normalizes spellIDs for cooldown dedup.
---@param spellID number
---@return number baseID
function RA:GetBaseSpellID(spellID)
    if not spellID then return spellID end
    local paired = self.KNOWN_OVERRIDE_PAIRS[spellID]
    if not paired then return spellID end
    return math.min(spellID, paired)
end

--- Check whether two spells share a cooldown via KNOWN_OVERRIDE_PAIRS.
--- 判断两个技能是否通过 KNOWN_OVERRIDE_PAIRS 共享 CD。
--- FIX (OverridePair): Used as a predicate in queue filtering.
---@param spellA number
---@param spellB number
---@return boolean sharesCooldown
function RA:SharesCooldown(spellA, spellB)
    if not spellA or not spellB then return false end
    if spellA == spellB then return true end
    local pairedA = self.KNOWN_OVERRIDE_PAIRS[spellA]
    return pairedA ~= nil and pairedA == spellB
end

--- 安全获取玩家生命百分比

--- @return number|nil hpPct 0.0-1.0，nil=secret 无法读取
function RA:GetPlayerHealthPercentSafe()
    local ok1, hp = pcall(UnitHealth, "player")
    local ok2, hpMax = pcall(UnitHealthMax, "player")
    if not ok1 then hp = nil end
    if not ok2 then hpMax = nil end

    if issecretvalue(hp) or issecretvalue(hpMax) then
        return nil
    end
    if not hp or not hpMax or hpMax <= 0 then
        return nil
    end
    return hp / hpMax
end

------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------

---Reusable scratch set for iterModulesOrdered. Module-level so the ordered
---walk allocates nothing per call (it runs twice on every OnEnable).
---iterModulesOrdered 复用的临时集合；提到模块级避免每次调用都分配 table。
---@type table<string, boolean>
local orderVisited = {}

---Modules already reported as missing from MODULE_ORDER, so the drift warning
---is printed at most once per module per session.
---已经报告过「不在 MODULE_ORDER 中」的模块，保证每个模块每会话只警告一次。
---@type table<string, boolean>
local orderDriftReported = {}

---Iterate modules in stable MODULE_ORDER, then any extras not in the list.
---
---Modules missing from MODULE_ORDER still run, but only AFTER every listed
---module — including all UI modules — which silently breaks dependency order.
---That drift is invisible today, so emit a one-shot debug warning per module.
---不在 MODULE_ORDER 中的模块仍会执行，但会被排到所有已列模块（含全部 UI）之后，
---静默破坏依赖顺序。此处对每个漂移模块打印一次 debug 警告，让问题自动暴露。
---@param callback function(name, mod)
local function iterModulesOrdered(callback)
    wipe(orderVisited)
    for _, name in ipairs(MODULE_ORDER) do
        local mod = RA.modules[name]
        if mod then
            orderVisited[name] = true
            callback(name, mod)
        end
    end
    -- Any module registered but NOT in the order list runs last
    for name, mod in pairs(RA.modules) do
        if not orderVisited[name] then
            if not orderDriftReported[name] then
                orderDriftReported[name] = true
                RA:PrintDebug(string.format(
                    "Module '%s' is not in MODULE_ORDER (Core/Init.lua) — it runs after every listed module. "
                    .. "模块 '%s' 不在 MODULE_ORDER 中，会被排到所有已列模块之后。",
                    name, name))
            end
            callback(name, mod)
        end
    end
end

------------------------------------------------------------------------
-- Core Event Frame (AceAddon Lifecycle)
------------------------------------------------------------------------

function RA:OnInitialize()
    self.L = LibStub("AceLocale-3.0"):GetLocale("RotaAssist")

    -- SavedVars must be the very first module initialized so RA.db exists
    -- for every subsequent module that may read it in OnInitialize.
    local savedVarsModule = self:GetModule("SavedVars")
    if savedVarsModule and savedVarsModule.OnInitialize then
        local ok, err = pcall(savedVarsModule.OnInitialize, savedVarsModule)
        if ok then
            savedVarsModule._initialized = true
            savedVarsModule._initializationFailed = nil
        else
            savedVarsModule._initialized = false
            savedVarsModule._initializationFailed = tostring(err)
            self:PrintError("Failed to initialize SavedVars: " .. tostring(err))
        end
    end

    self:RegisterChatCommand("ra", "SlashCommand")
    self:RegisterChatCommand("rotaassist", "SlashCommand")
end

function RA:OnEnable()
    local savedVarsModule = self:GetModule("SavedVars")
    if savedVarsModule and savedVarsModule._initializationFailed then
        self:PrintError("RotaAssist modules were not started because SavedVars failed to initialize.")
        return
    end

    -- FIX (Issue 3): Use stable MODULE_ORDER so dependencies are always
    -- initialized before the modules that rely on them.
    iterModulesOrdered(function(name, mod)
        -- Skip SavedVars — already initialized in OnInitialize above.
        if name == "SavedVars" then return end

        if mod.OnInitialize and not mod._initialized then
            local ok, err = pcall(mod.OnInitialize, mod)
            if ok then
                mod._initialized = true
                mod._initializationFailed = nil
            else
                mod._initialized = false
                mod._initializationFailed = tostring(err)
                self:PrintError("Failed to initialize " .. name .. ": " .. tostring(err))
            end
        end
    end)

    iterModulesOrdered(function(name, mod)
        -- A module whose initialization failed cannot safely run OnEnable. Keep both
        -- lifecycle flags truthful so a future reload/retry can diagnose the failure.
        -- 初始化失败的模块不能继续启用；保持状态标志真实，便于后续重试与诊断。
        if mod.OnEnable and not mod._enabled and not mod._initializationFailed then
            local ok, err = pcall(mod.OnEnable, mod)
            if ok then
                mod._enabled = true
                mod._enableFailed = nil
            else
                mod._enabled = false
                mod._enableFailed = tostring(err)
                self:PrintError("Failed to enable " .. name .. ": " .. tostring(err))
            end
        end
    end)

    self:Print(string.format(self.L["STARTUP_MESSAGE"], self.version))
end

function RA:OnDisable()
    for name, mod in pairs(self.modules) do
        if mod.OnDisable then
            mod:OnDisable()
            mod._enabled = false
        end
    end
end

------------------------------------------------------------------------
-- Slash Commands
------------------------------------------------------------------------

---Process a slash command string.
---@param input string Raw slash command input after /ra
function RA:SlashCommand(input)
    local L = self.L
    local cmd, rest = strsplit(" ", (input or ""):trim():lower(), 2)

    if cmd == "" or cmd == "help" then
        self:Print(L["SLASH_HELP_HEADER"])
        self:Print("  /ra config   — " .. L["SLASH_HELP_CONFIG"])
        self:Print("  /ra toggle   — " .. L["SLASH_HELP_TOGGLE"])
        self:Print("  /ra lock     — " .. L["SLASH_HELP_LOCK"])
        self:Print("  /ra reset    — " .. L["SLASH_HELP_RESET"])
        self:Print("  /ra debug    — " .. L["SLASH_HELP_DEBUG"])
        self:Print("  /ra accuracy — Show combat accuracy history")
        self:Print("  /ra aplcheck — Report APL rules with unsupported conditions or unknown spellIDs")
        self:Print("  /ra version  — " .. L["SLASH_HELP_VERSION"])
        self:Print(L["INDEPENDENT_USAGE"])
        self:Print(L["BUILD_USAGE"])
    elseif cmd == "config" or cmd == "options" or cmd == "settings" then
        LibStub("AceConfigDialog-3.0"):Open("RotaAssist")
    elseif cmd == "toggle" then
        local mainDisplay = self:GetModule("MainDisplay")
        if mainDisplay and mainDisplay.Toggle then
            mainDisplay:Toggle()
        end
    elseif cmd == "lock" then
        local mainDisplay = self:GetModule("MainDisplay")
        if mainDisplay and mainDisplay.ToggleLock then
            mainDisplay:ToggleLock()
        end
    elseif cmd == "reset" then
        local savedVars = self:GetModule("SavedVars")
        if savedVars and savedVars.ResetToDefaults then
            savedVars:ResetToDefaults()
        end
    elseif cmd == "debug" then
        self.db.profile.general.debugMode = not self.db.profile.general.debugMode
        self.debugMode = self.db.profile.general.debugMode
        if self.debugMode then
            self:Print(L["DEBUG_ENABLED"])
        else
            self:Print(L["DEBUG_DISABLED"])
        end
    elseif cmd == "accuracy" then
        local tracker = self:GetModule("AccuracyTracker")
        if tracker and tracker.PrintHistory then
            tracker:PrintHistory()
        end
    elseif cmd == "aplcheck" then
        -- Diagnostics for APL condition tokens the engine cannot evaluate, plus
        -- spellIDs that do not resolve on this client (D-015).
        -- 打印 APL 引擎无法求值的条件 token，以及在本客户端解析不出来的 spellID 诊断（D-015）。
        local aplEngine = self:GetModule("APLEngine")
        if aplEngine and aplEngine.PrintConditionReport then
            aplEngine:PrintConditionReport()
        else
            self:PrintWarning("APLEngine is not available. / APLEngine 不可用。")
        end
    elseif cmd == "build" then
        local character = self:GetModule("CharacterState")
        if character then character:PrintSummary() else self:Print(L["BUILD_UNKNOWN"]) end
    elseif cmd == "independent" then
        if rest ~= "on" and rest ~= "off" then
            self:Print(L["INDEPENDENT_USAGE"])
            return
        end
        self.db.profile.smartQueue = self.db.profile.smartQueue or {}
        self.db.profile.smartQueue.independentExperimental = rest == "on"
        local events = self:GetModule("EventHandler")
        if events then events:Fire("ROTAASSIST_INDEPENDENT_MODE_CHANGED") end
        self:Print(L[rest == "on" and "INDEPENDENT_ENABLED" or "INDEPENDENT_DISABLED"])
    elseif cmd == "version" or cmd == "ver" then
        self:Print(string.format("%s v%s", self.name, self.version))
    else
        self:PrintWarning(string.format(L["UNKNOWN_COMMAND"], cmd))
    end
end
