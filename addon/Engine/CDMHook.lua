------------------------------------------------------------------------
-- RotaAssist - CDM (Cooldown Manager) Hook
-- WoW 12.0 introduced Blizzard's built-in EssentialCooldownViewer (the
-- in-game default cooldown UI). This module is a read-only observer that
-- bridges Blizzard's CDV with RotaAssist's CooldownOverlay so that:
--   1. RotaAssist consumers (InterruptAdvisor, SmartQueueManager, future UI)
--      can ask for "what does Blizzard think about this CD right now?" via a
--      stable, pcall-safe public namespace `RA.CDM`.
--   2. Blizzard's TriggerAlertEvent firings get re-emitted as the addon's own
--      `ROTAASSIST_CDM_ALERT` custom event so other modules can subscribe
--      without having to know about CDV internals.
-- DESIGN: option (a) "observer-only". CDV's writer-side API (registering
-- our own cooldowns into Blizzard's panel) is not a documented post-12.0
-- contract; observer mode keeps us future-proof and avoids touching
-- Blizzard frames if the player has CDV disabled or moved.
-- DEFAULT DISABLED — per ROADMAP §CDM, opt-in via db.profile.cdm.enabled.
-- 12.0 Blizzard 默认 CD UI Hook（只读观察者，默认禁用）。
------------------------------------------------------------------------

local _, NS = ...
local RA = NS.RA
local CDMHook = {}
RA:RegisterModule("CDMHook", CDMHook)

------------------------------------------------------------------------
-- Internal State
------------------------------------------------------------------------

--- Whether we successfully attached hooks to a real Blizzard CDV frame.
--- 是否已成功 hook 到真实的 CDV 框架。
---@type boolean
local hooked = false

--- Whether the module's lifecycle is enabled (independent of hooked).
--- 模块的生命周期开关；与 hooked 相互独立（启用但 CDV 不存在时 hooked=false）。
---@type boolean
local active = false

--- Set of spellIDs we've already attached a hook to, to avoid double-hooking
--- when CDV repopulates its children list.
--- 已挂钩的 spellID 集合；防止 CDV 重新创建子节点时重复 hook。
---@type table<number, boolean>
local hookedSpells = {}

--- Cache of the latest observed CDV state per spellID.
---  state = { spellID, ready, lastEvent, lastEventTime }
--- 最近一次观察到的 CDV 状态（每 spellID）。
---@type table<number, table>
local cdvStates = {}

--- Tunable: max retries while waiting for CDV frame to appear.
--- WoW may not have built EssentialCooldownViewer yet at OnEnable time
--- (e.g. UI add-ons load order, EditMode swap), so we retry a few times.
local MAX_HOOK_RETRIES = 4
local HOOK_RETRY_DELAY = 1.0  -- seconds

------------------------------------------------------------------------
-- Configuration helpers
------------------------------------------------------------------------

---Read effective config with safe defaults.
---读取配置；不存在时返回安全默认值。
---@return table cfg { enabled, trackInterrupt, trackMajorCD }
local function getConfig()
    local profile = RA.db and RA.db.profile or nil
    local cdm = profile and profile.cdm or nil
    return {
        enabled        = cdm and cdm.enabled        or false,  -- default DISABLED
        trackInterrupt = cdm and cdm.trackInterrupt ~= false,  -- default true
        trackMajorCD   = cdm and cdm.trackMajorCD   ~= false,  -- default true
    }
end

------------------------------------------------------------------------
-- Hook Logic
------------------------------------------------------------------------

---Translate a Blizzard CooldownViewer alert event enum into a string
---we use on our `ROTAASSIST_CDM_ALERT` payload. Stays stable across
---future Enum renames because we never expose the raw enum to consumers.
---将 Blizzard 的 CooldownViewerAlertEventType 枚举转成字符串。
---@param ev any The raw Enum value from the Blizzard hook.
---@return string normalised
local function normalizeAlertEvent(ev)
    if type(Enum) == "table" and Enum.CooldownViewerAlertEventType then
        local eAvailable  = Enum.CooldownViewerAlertEventType.Available
        local eOnCooldown = Enum.CooldownViewerAlertEventType.OnCooldown
        if eAvailable  ~= nil and ev == eAvailable  then return "Available"  end
        if eOnCooldown ~= nil and ev == eOnCooldown then return "OnCooldown" end
    end
    -- Best-effort fallback when the Enum table is missing (older clients,
    -- test environments). Numeric 0/1 are the values shipped in 12.0.
    if ev == 0 then return "Available"  end
    if ev == 1 then return "OnCooldown" end
    return "Unknown"
end

---Fire `ROTAASSIST_CDM_ALERT` with a normalised payload.
---@param spellID number
---@param normEvent string  "Available" | "OnCooldown" | "Unknown"
local function fireAlert(spellID, normEvent)
    cdvStates[spellID] = {
        spellID       = spellID,
        ready         = (normEvent == "Available"),
        lastEvent     = normEvent,
        lastEventTime = GetTime(),
    }
    local eh = RA:GetModule("EventHandler")
    if eh and eh.Fire then
        eh:Fire("ROTAASSIST_CDM_ALERT", spellID, normEvent)
    end
end

---Attach the secure-function hook to a single CDV child if it has GetSpellID.
---对单个 CDV 子节点挂钩 TriggerAlertEvent。
---@param child any  A frame returned from CDV:GetChildren()
---@return boolean hookedNow  True if we attached a hook on this call.
local function tryHookChild(child)
    if type(child) ~= "table" then return false end
    if type(child.GetSpellID) ~= "function" then return false end

    local okID, spellID = pcall(child.GetSpellID, child)
    if not okID or type(spellID) ~= "number" or spellID == 0 then
        return false
    end
    if hookedSpells[spellID] then return false end
    if type(child.TriggerAlertEvent) ~= "function" then return false end
    if type(hooksecurefunc) ~= "function" then return false end

    -- hooksecurefunc on the instance method. Lua's `hooksecurefunc(table, name, fn)`
    -- variant is the safe form WoW exposes for this exact use-case.
    local okHook = pcall(hooksecurefunc, child, "TriggerAlertEvent", function(_, ev)
        local norm = normalizeAlertEvent(ev)
        fireAlert(spellID, norm)
    end)
    if not okHook then return false end

    hookedSpells[spellID] = true
    return true
end

---Walk EssentialCooldownViewer's children and hook them.
---遍历 EssentialCooldownViewer 子节点并挂钩。
---@return boolean attachedAny
local function attachToBlizzardCDV()
    local viewer = rawget(_G, "EssentialCooldownViewer")
    if type(viewer) ~= "table" or type(viewer.GetChildren) ~= "function" then
        return false
    end

    local okChildren, children = pcall(function()
        return { viewer:GetChildren() }
    end)
    if not okChildren or type(children) ~= "table" then return false end

    local attachedAny = false
    for _, child in ipairs(children) do
        if tryHookChild(child) then attachedAny = true end
    end
    return attachedAny
end

---Schedule a retry to hook CDV after a short delay.
---WoW EssentialCooldownViewer may not exist yet at OnEnable time on
---some characters / EditMode setups, so retry a small number of times.
---@param remaining number
local function scheduleHookRetry(remaining)
    if remaining <= 0 or not C_Timer or type(C_Timer.After) ~= "function" then
        return
    end
    C_Timer.After(HOOK_RETRY_DELAY, function()
        if not active then return end
        if hooked then return end
        if attachToBlizzardCDV() then
            hooked = true
            local eh = RA:GetModule("EventHandler")
            if eh and eh.Fire then eh:Fire("ROTAASSIST_CDM_HOOKED") end
        else
            scheduleHookRetry(remaining - 1)
        end
    end)
end

---Refresh hooks, e.g. after spec change when CDV repopulates its rows.
---专精切换或 CDV 重建子节点后重新尝试挂钩。
local function refreshHooks()
    if not active then return end
    -- Don't reset hookedSpells: hooksecurefunc on the same method+frame is
    -- idempotent and Blizzard typically reuses the child frame instances
    -- across spec swaps. Re-walk to catch any new rows.
    if attachToBlizzardCDV() then hooked = true end
end

------------------------------------------------------------------------
-- Module Lifecycle
------------------------------------------------------------------------

function CDMHook:OnInitialize()
    -- Pre-allocate the public namespace early so other modules can `if RA.CDM`
    -- without ordering against our OnEnable.
    -- 提前创建公共命名空间，便于其他模块在我们的 OnEnable 之前安全引用。
    RA.CDM = RA.CDM or {}

    function RA.CDM.IsAvailable()
        local viewer = rawget(_G, "EssentialCooldownViewer")
        return type(viewer) == "table" and type(viewer.GetChildren) == "function"
    end

    function RA.CDM.IsActive()
        return active and hooked
    end

    function RA.CDM.GetTrackedCooldowns()
        -- Return a shallow copy so external readers cannot mutate our state.
        -- 返回浅拷贝；防止外部消费者污染我们的状态表。
        local out = {}
        for sid, st in pairs(cdvStates) do
            out[sid] = {
                spellID       = st.spellID,
                ready         = st.ready,
                lastEvent     = st.lastEvent,
                lastEventTime = st.lastEventTime,
            }
        end
        return out
    end

    function RA.CDM.GetState(spellID)
        if not spellID then return nil end
        local st = cdvStates[spellID]
        if not st then return nil end
        return {
            spellID       = st.spellID,
            ready         = st.ready,
            lastEvent     = st.lastEvent,
            lastEventTime = st.lastEventTime,
        }
    end

    --- Bridge: surface RotaAssist's existing CooldownOverlay data through a
    --- read-only-friendly accessor so external UIs (or our own future UI
    --- replacement for CDV) can consume it without reaching into internals.
    --- 桥接：通过只读访问器暴露 CooldownOverlay 数据，供外部 UI 消费。
    function RA.CDM.GetOverlayCooldowns()
        local overlay = RA:GetModule("CooldownOverlay")
        if not overlay or type(overlay.GetCooldownStates) ~= "function" then
            return {}
        end
        local raw = overlay:GetCooldownStates()
        local out = {}
        for sid, state in pairs(raw or {}) do
            out[sid] = {
                spellID   = sid,
                ready     = state.ready and true or false,
                remaining = state.remaining or 0,
                texture   = state.texture,
                name      = state.name,
                startTime = state.startTime or 0,
                duration  = state.duration  or 0,
            }
        end
        return out
    end
end

function CDMHook:OnEnable()
    local cfg = getConfig()
    if not cfg.enabled then
        active = false
        return  -- module stays dormant, RA.CDM accessors still work (return empty/false)
    end

    active = true

    -- Try to attach now; if CDV doesn't exist yet, retry briefly.
    if attachToBlizzardCDV() then
        hooked = true
        local eh = RA:GetModule("EventHandler")
        if eh and eh.Fire then eh:Fire("ROTAASSIST_CDM_HOOKED") end
    else
        scheduleHookRetry(MAX_HOOK_RETRIES)
    end

    -- Re-attempt hook attachment when spec/talents change. Blizzard rebuilds
    -- the CDV row list on these events.
    -- 专精/天赋切换后 CDV 会重建节点，重新挂钩。
    local eh = RA:GetModule("EventHandler")
    if eh and eh.Subscribe then
        eh:Subscribe("ROTAASSIST_SPEC_CHANGED", "CDMHook", function()
            -- Reset spell-side hook tracking so refreshHooks can re-hook
            -- newly-built children. (hooksecurefunc on the SAME frame+method
            -- is idempotent in WoW, but a respawned child is a new frame.)
            for k in pairs(hookedSpells) do hookedSpells[k] = nil end
            for k in pairs(cdvStates)   do cdvStates[k]   = nil end
            hooked = false
            refreshHooks()
            if not hooked then scheduleHookRetry(MAX_HOOK_RETRIES) end
        end)

        eh:Subscribe("PLAYER_TALENT_UPDATE", "CDMHook", function()
            refreshHooks()
        end)
    end
end

function CDMHook:OnDisable()
    active = false
    -- We cannot un-hook a hooksecurefunc'ed function; closures stay attached
    -- but become no-ops because they early-return when `active == false`
    -- via the fireAlert→cdvStates/EventHandler:Fire path which respects
    -- subscription presence. Clear cached state so consumers see "no data".
    -- 无法解除 hooksecurefunc；通过 active 标志和清理缓存来停止数据流。
    for k in pairs(cdvStates)   do cdvStates[k]   = nil end
    -- Keep hookedSpells intact — re-enabling the module would re-hook
    -- the same frames, which Blizzard guards against via security.

    local eh = RA:GetModule("EventHandler")
    if eh and eh.Unsubscribe then
        eh:Unsubscribe("ROTAASSIST_SPEC_CHANGED",  "CDMHook")
        eh:Unsubscribe("PLAYER_TALENT_UPDATE",      "CDMHook")
    end
end

------------------------------------------------------------------------
-- Test/diagnostic helpers (NOT used at runtime; safe public surface)
------------------------------------------------------------------------

---For tests and /ra debug. Returns whether internal state says we're hooked.
---@return boolean
function CDMHook:IsHookedForTests()
    return hooked
end

---For tests: deliver an alert as if the Blizzard hook fired. Bypasses the
---real CDV frame so we can exercise the dispatch path on busted.
---@param spellID number
---@param ev any  Raw enum value or 0/1 numeric fallback
function CDMHook:_TestSimulateAlert(spellID, ev)
    if not spellID then return end
    fireAlert(spellID, normalizeAlertEvent(ev))
end
