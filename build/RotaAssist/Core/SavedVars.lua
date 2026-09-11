------------------------------------------------------------------------
-- RotaAssist - SavedVariables Manager
-- Persistent settings with defaults, deep-copy, and version migration.
------------------------------------------------------------------------

local _, NS = ...
local RA = NS.RA
local SavedVars = {}
RA:RegisterModule("SavedVars", SavedVars)

------------------------------------------------------------------------
-- Default Configuration
------------------------------------------------------------------------

---@type table Default settings applied on first load or reset.
local defaults = {
    profile = {
        general = {
            enabled       = true,
            language      = "auto",   -- auto-detect client locale
            debugMode     = false,
            minimapButton = true,
        },
        display = {
            iconCount   = 2,         -- number of prediction icons (1-4)
            iconSize    = 48,        -- pixels per icon
            iconSpacing = 4,         -- gap between icons
            scale       = 1.0,       -- overall scale (0.5 – 2.0)
            alpha       = 1.0,       -- opacity (0.1 – 1.0)
            locked      = false,     -- prevent dragging
            showOutOfCombat = true,  -- show icons even out of combat
            fadeOutOfCombat  = true, -- fade when not in combat
            fadeAlpha   = 0.3,       -- alpha when faded
            anchorPoint = "CENTER",  -- frame anchor
            anchorX     = 0,         -- x offset from anchor
            anchorY     = -200,      -- y offset from anchor
            showKeybinds   = true,   -- display keybind text on icons
            showCooldownSwirl = true,-- show cooldown spiral animation
            -- Added: keys used by MainDisplay that were missing defaults
            combatOnly      = false, -- hide display when out of combat
            mode            = "Raid",-- "Raid" (single-target) or "M+" (AoE)
            hideBackground  = false, -- remove backdrop panel
            bgAlpha         = 0.5,   -- background opacity
            point           = nil,   -- saved frame anchor: {point, relPoint, x, y} or nil
            -- Round 19 (UI fusion) / 第 19 轮 UI 融合
            showRangeIndicator = true,  -- pulse the main icon red when out of range
                                        -- 目标超距时主图标红色脉冲
            showProcGlow       = true,  -- glow the main icon on Blizzard proc overlays
                                        -- 暴雪 proc 覆盖时主图标高亮
            hideCooldownPredictions = false,
                                        -- OFF by default: main's lookahead shows spells
                                        -- that are on cooldown (greyed + sweep). Turning
                                        -- this on adopts round15's "hide them" behaviour.
                                        -- 默认关闭：main 的前瞻会显示冷却中的技能（灰显+转圈）。
                                        -- 开启后采用 round15 的"直接隐去"行为。
            showResourceBar    = true,  -- resource bar under the strip / 条下方资源条
            showPrePullPanel   = true,  -- out-of-combat checklist / 战前清单
        },
        cooldowns = {
            enabled        = true,
            showPanel      = true,
            panelScale     = 0.8,
            panelAlpha     = 1.0,
            panelLocked    = false,
            panelAnchor    = "CENTER",
            panelAnchorX   = 0,
            panelAnchorY   = -260,
            trackedSpells  = {},     -- user overrides: { [spellID] = true/false }
        },
        minimapIcon = {
            hide = false,            -- managed by LibDBIcon
        },
        accuracy = {
            enabled = true,
            history = {},            -- recent combat accuracy ratings
        },
        smartQueue = {
            blizzardWeight = 1.0,
            aplWeight      = 0.6,
            aiWeight       = 0.4,
            cdWeight       = 0.5,
            defWeight      = 0.8
        },
        interrupt = {
            enabled    = true,
            soundAlert = true,
            point      = nil,        -- floating InterruptAlert anchor / 打断浮窗位置
        },
        -- Round 19: the defensive alert used to call PlaySoundFile unconditionally
        -- with no way to silence it. It now reads defensive.soundAlert.
        -- 第 19 轮：减伤提示此前无条件 PlaySoundFile 且无法关闭，现读取 defensive.soundAlert。
        defensive = {
            enabled    = true,
            soundAlert = true,
            point      = nil,        -- floating DefensiveAlert anchor / 减伤浮窗位置
        },
        -- Combat-phase coaching. This table had NO defaults before Round 19,
        -- so `db.profile.coach.enabled` was always nil and the PhaseIndicator
        -- could never be shown.
        -- 战斗阶段教练。第 19 轮前本表无默认值，coach.enabled 恒为 nil，
        -- 导致阶段徽章永远无法显示。
        coach = {
            enabled = true
        }
    }
}

------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------

---Initialize SavedVariables.  Called from Init.lua:OnInitialize().
function SavedVars:OnInitialize()
    -- RotaAssistDB is the global SavedVariables key declared in .toc
    RA.db = LibStub("AceDB-3.0"):New("RotaAssistDB", defaults, true)

    RA.db.RegisterCallback(self, "OnProfileChanged", "RefreshProfile")
    RA.db.RegisterCallback(self, "OnProfileCopied", "RefreshProfile")
    RA.db.RegisterCallback(self, "OnProfileReset", "RefreshProfile")

    -- FIX (Issue 2): Sync debug mode directly here.
    -- Do NOT fire ROTAASSIST_SETTINGS_RESET at this stage — no module has
    -- called Subscribe() yet (OnEnable hasn't run), so the message would
    -- fire into a void and the AceEvent internal state may not be ready.
    RA.debugMode = RA.db.profile.general.debugMode or false
end

---Called by AceDB callbacks whenever the active profile changes/resets.
---Also safe to call after OnEnable when all modules are listening.
function SavedVars:RefreshProfile()
    RA.debugMode = RA.db.profile.general.debugMode or false

    -- Fire the settings-changed event so UI modules can re-read db.profile.
    -- This is only called after OnInitialize, so EventHandler is ready.
    local eventHandler = RA:GetModule("EventHandler")
    if eventHandler and eventHandler.Fire then
        eventHandler:Fire("ROTAASSIST_SETTINGS_RESET")
    end
end

---Reset all settings to factory defaults.
function SavedVars:ResetToDefaults()
    RA.db:ResetProfile()
    RA:Print(RA.L["SETTINGS_RESET"])
end

---Get a deep copy of the full defaults table (for UI reset preview).
---@return table defaults
function SavedVars:GetDefaults()
    local function deepCopy(src, dest)
        dest = dest or {}
        for k, v in pairs(src) do
            if type(v) == "table" then
                dest[k] = deepCopy(v, {})
            else
                dest[k] = v
            end
        end
        return dest
    end
    return deepCopy(defaults)
end

---Export the deep-copy utility for other modules.
---@param src table
---@return table
function RA.DeepCopy(src)
    local function deepCopy(s, d)
        d = d or {}
        for k, v in pairs(s) do
            if type(v) == "table" then
                d[k] = deepCopy(v, {})
            else
                d[k] = v
            end
        end
        return d
    end
    return deepCopy(src)
end
