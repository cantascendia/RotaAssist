------------------------------------------------------------------------
-- RotaAssist - Config Panel
-- Settings UI using AceConfig-3.0.
------------------------------------------------------------------------

local _, NS = ...
local RA = NS.RA

-- Design tokens (D-016): even the chat colour escapes in the About page come
-- from the theme, so there is exactly one place to restyle the addon.
-- 设计令牌（D-016）：连"关于"页的聊天框颜色转义也走主题，改风格只需改一处。
local Theme = RA.Theme

local ConfigPanel = {}
RA:RegisterModule("ConfigPanel", ConfigPanel)

------------------------------------------------------------------------
-- Options Table
------------------------------------------------------------------------

-- FIX (Issue 4): GetOptions() is called by AceConfig every time the
-- panel opens.  The "about" description used heavy ".." concat, which
-- re-allocates strings on every open.  We cache the pre-built string
-- in ConfigPanel._aboutText during OnInitialize (called once) and
-- reference it from GetOptions() thereafter.

local function GetOptions()
    local L = RA.L

    local function notifySettingsChanged()
        local eventHandler = RA:GetModule("EventHandler")
        if eventHandler and eventHandler.Fire then
            eventHandler:Fire("ROTAASSIST_SETTINGS_RESET")
        end
    end

    local options = {
        name = "RotaAssist",
        type = "group",
        args = {
            general = {
                name = L["CONFIG_HEADER_GENERAL"],
                type = "group",
                order = 1,
                get = function(info) return RA.db.profile.general[info[#info]] end,
                set = function(info, value)
                    RA.db.profile.general[info[#info]] = value
                    notifySettingsChanged()
                end,
                args = {
                    quickStart = {
                        name = L["CONFIG_QUICK_START"],
                        type = "description",
                        order = 1,
                    },
                    focusPreset = {
                        name = L["CONFIG_FOCUS_PRESET"],
                        desc = L["CONFIG_FOCUS_PRESET_DESC"],
                        type = "execute",
                        order = 2,
                        func = function() ConfigPanel:ApplyViewPreset("focus") end,
                    },
                    learningPreset = {
                        name = L["CONFIG_LEARNING_PRESET"],
                        desc = L["CONFIG_LEARNING_PRESET_DESC"],
                        type = "execute",
                        order = 3,
                        func = function() ConfigPanel:ApplyViewPreset("learning") end,
                    },
                    enabled = {
                        name = L["CONFIG_ENABLED"],
                        desc = L["CONFIG_ENABLED_DESC"],
                        type = "toggle",
                        order = 10,
                    },
                    debugMode = {
                        name = L["CONFIG_DEBUG"],
                        desc = L["CONFIG_DEBUG_DESC"],
                        type = "toggle",
                        order = 20,
                        set = function(info, value)
                            RA.db.profile.general.debugMode = value
                            RA.debugMode = value
                            notifySettingsChanged()
                        end,
                    },
                    minimapButton = {
                        name = L["CONFIG_MINIMAP"],
                        desc = L["CONFIG_MINIMAP_DESC"],
                        type = "toggle",
                        order = 30,
                        set = function(info, value)
                            RA.db.profile.general.minimapButton = value
                            local minimap = RA:GetModule("MinimapButton")
                            if minimap then
                                minimap:SetShown(value)
                            end
                            notifySettingsChanged()
                        end,
                    },
                },
            },
            display = {
                name = L["CONFIG_HEADER_DISPLAY"],
                type = "group",
                order = 2,
                get = function(info) return RA.db.profile.display[info[#info]] end,
                set = function(info, value)
                    RA.db.profile.display[info[#info]] = value
                    notifySettingsChanged()
                end,
                args = {
                    -- NOTE: iconCount keeps main's meaning — the number of
                    -- PREDICTION icons, not the total. The round15 branch
                    -- redefined it as "total icons"; adopting that would have
                    -- silently halved every existing user's lookahead.
                    -- 注意：iconCount 沿用 main 的语义（预测图标数，非总数）。
                    -- round15 曾把它改成"图标总数"，直接采用会让老用户的前瞻数腰斩。
                    iconCount = {
                        name = L["CONFIG_ICON_COUNT"],
                        desc = L["CONFIG_ICON_COUNT_DESC"],
                        type = "range",
                        min = 1, max = 4, step = 1,
                        order = 10,
                    },
                    iconSpacing = {
                        name = L["CONFIG_ICON_SPACING"],
                        desc = L["CONFIG_ICON_SPACING_DESC"],
                        type = "range",
                        min = 0, max = 16, step = 1,
                        order = 15,
                    },
                    scale = {
                        name = L["CONFIG_SCALE"],
                        desc = L["CONFIG_SCALE_DESC"],
                        type = "range",
                        min = 0.5, max = 2.0, step = 0.1,
                        isPercent = true,
                        order = 20,
                    },
                    alpha = {
                        name = L["CONFIG_ALPHA"],
                        desc = L["CONFIG_ALPHA_DESC"],
                        type = "range",
                        min = 0.1, max = 1.0, step = 0.05,
                        isPercent = true,
                        order = 30,
                    },
                    locked = {
                        name = L["CONFIG_LOCK"],
                        desc = L["CONFIG_LOCK_DESC"],
                        type = "toggle",
                        order = 40,
                    },
                    showOutOfCombat = {
                        name = L["CONFIG_SHOW_OOC"],
                        desc = L["CONFIG_SHOW_OOC_DESC"],
                        type = "toggle",
                        order = 50,
                    },
                    fadeOutOfCombat = {
                        name = L["CONFIG_FADE_OOC"],
                        desc = L["CONFIG_FADE_OOC_DESC"],
                        type = "toggle",
                        order = 60,
                    },
                    showKeybinds = {
                        name = L["CONFIG_KEYBINDS"],
                        desc = L["CONFIG_KEYBINDS_DESC"],
                        type = "toggle",
                        order = 70,
                    },
                    showCooldownSwirl = {
                        name = L["CONFIG_COOLDOWN_SWIRL"],
                        desc = L["CONFIG_COOLDOWN_SWIRL_DESC"],
                        type = "toggle",
                        order = 80,
                    },
                    reducedMotion = {
                        name = L["CONFIG_REDUCED_MOTION"],
                        desc = L["CONFIG_REDUCED_MOTION_DESC"],
                        type = "toggle",
                        order = 82,
                    },
                    hideCooldownPredictions = {
                        name = L["CONFIG_HIDE_CD_PREDICTIONS"],
                        desc = L["CONFIG_HIDE_CD_PREDICTIONS_DESC"],
                        type = "toggle",
                        order = 85,
                    },
                    showRangeIndicator = {
                        name = L["CONFIG_SHOW_RANGE"],
                        desc = L["CONFIG_SHOW_RANGE_DESC"],
                        type = "toggle",
                        order = 90,
                    },
                    showProcGlow = {
                        name = L["CONFIG_SHOW_PROC"],
                        desc = L["CONFIG_SHOW_PROC_DESC"],
                        type = "toggle",
                        order = 100,
                    },
                },
            },
            -- Coach attachments: the widgets that separate RotaAssist from the
            -- seven C_AssistedCombat icon bars (VISION.md). Each ships enabled.
            -- 教练挂件：本产品区别于 7 个竞品图标条的部分（VISION.md），默认全开。
            coach = {
                name = L["CONFIG_HEADER_COACH"],
                type = "group",
                order = 3,
                args = {
                    phaseIndicator = {
                        name = L["CONFIG_PHASE_INDICATOR"],
                        desc = L["CONFIG_PHASE_INDICATOR_DESC"],
                        type = "toggle",
                        order = 10,
                        get = function()
                            return RA.db.profile.coach and RA.db.profile.coach.enabled ~= false
                        end,
                        set = function(_, value)
                            RA.db.profile.coach = RA.db.profile.coach or {}
                            RA.db.profile.coach.enabled = value
                            notifySettingsChanged()
                        end,
                    },
                    resourceBar = {
                        name = L["CONFIG_RESOURCE_BAR"],
                        desc = L["CONFIG_RESOURCE_BAR_DESC"],
                        type = "toggle",
                        order = 20,
                        get = function() return RA.db.profile.display.showResourceBar ~= false end,
                        set = function(_, value)
                            RA.db.profile.display.showResourceBar = value
                            notifySettingsChanged()
                        end,
                    },
                    accuracyMeter = {
                        name = L["CONFIG_ACCURACY_METER"],
                        desc = L["CONFIG_ACCURACY_METER_DESC"],
                        type = "toggle",
                        order = 30,
                        get = function()
                            return RA.db.profile.accuracy and RA.db.profile.accuracy.enabled ~= false
                        end,
                        set = function(_, value)
                            RA.db.profile.accuracy = RA.db.profile.accuracy or {}
                            RA.db.profile.accuracy.enabled = value
                            notifySettingsChanged()
                        end,
                    },
                    prePullPanel = {
                        name = L["CONFIG_PREPULL_PANEL"],
                        desc = L["CONFIG_PREPULL_PANEL_DESC"],
                        type = "toggle",
                        order = 40,
                        get = function() return RA.db.profile.display.showPrePullPanel ~= false end,
                        set = function(_, value)
                            RA.db.profile.display.showPrePullPanel = value
                            notifySettingsChanged()
                        end,
                    },
                },
            },
            -- Floating alerts / 独立浮动警报
            alerts = {
                name = L["CONFIG_HEADER_ALERTS"],
                type = "group",
                order = 4,
                args = {
                    defensiveSound = {
                        name = L["CONFIG_DEFENSIVE_SOUND"],
                        desc = L["CONFIG_DEFENSIVE_SOUND_DESC"],
                        type = "toggle",
                        order = 10,
                        get = function()
                            return RA.db.profile.defensive
                                and RA.db.profile.defensive.soundAlert ~= false
                        end,
                        set = function(_, value)
                            RA.db.profile.defensive = RA.db.profile.defensive or {}
                            RA.db.profile.defensive.soundAlert = value
                            notifySettingsChanged()
                        end,
                    },
                    interruptSound = {
                        name = L["CONFIG_INTERRUPT_SOUND"],
                        desc = L["CONFIG_INTERRUPT_SOUND_DESC"],
                        type = "toggle",
                        order = 20,
                        get = function()
                            return RA.db.profile.interrupt
                                and RA.db.profile.interrupt.soundAlert ~= false
                        end,
                        set = function(_, value)
                            RA.db.profile.interrupt = RA.db.profile.interrupt or {}
                            RA.db.profile.interrupt.soundAlert = value
                            notifySettingsChanged()
                        end,
                    },
                },
            },
            cooldowns = {
                name = L["CONFIG_HEADER_COOLDOWNS"],
                type = "group",
                order = 5,
                get = function(info) return RA.db.profile.cooldowns[info[#info]] end,
                set = function(info, value)
                    RA.db.profile.cooldowns[info[#info]] = value
                    notifySettingsChanged()
                end,
                args = {
                    showPanel = {
                        name = L["CONFIG_CD_ENABLED"],
                        desc = L["CONFIG_CD_ENABLED_DESC"],
                        type = "toggle",
                        order = 10,
                    },
                    panelScale = {
                        name = L["CONFIG_CD_SCALE"],
                        desc = L["CONFIG_CD_SCALE_DESC"],  -- FIX: was incorrectly L["CONFIG_CD_SCALE"]
                        type = "range",
                        min = 0.5, max = 2.0, step = 0.1,
                        isPercent = true,
                        order = 20,
                    },
                    panelLocked = {
                        name = L["CONFIG_CD_LOCK"],
                        desc = L["CONFIG_CD_LOCK_DESC"],   -- FIX: was incorrectly L["CONFIG_CD_LOCK"]
                        type = "toggle",
                        order = 30,
                    },
                },
            },
            about = {
                name = L["CONFIG_HEADER_ABOUT"],
                type = "group",
                order = 6,
                args = {
                    title = {
                        -- FIX (Issue 4): reference the pre-built string cached in OnInitialize
                        name = function() return ConfigPanel._aboutText end,
                        type = "description",
                        order = 1,
                        fontSize = "medium",
                    },
                },
            },
        },
    }

    return options
end

------------------------------------------------------------------------
-- Module Lifecycle
------------------------------------------------------------------------

function ConfigPanel:OnInitialize()
    -- FIX (Issue 4): Build the about string ONCE here instead of on every
    -- panel open.  AceConfig calls GetOptions() each open; we avoid the
    -- repeated ".." allocations by pre-building and caching the text.
    local L = RA.L
    local hex = Theme.hex
    self._aboutText = hex.accent .. RA.name .. hex.reset .. "\n"
        .. string.format(L["ABOUT_VERSION"], RA.version) .. "\n"
        .. L["ABOUT_AUTHOR"] .. "\n"
        .. L["ABOUT_LICENSE"] .. "\n\n"
        .. hex.muted .. L["ABOUT_DESCRIPTION"] .. hex.reset .. "\n\n"
        .. hex.link .. L["ABOUT_WEBSITE"] .. hex.reset

    LibStub("AceConfig-3.0"):RegisterOptionsTable("RotaAssist", GetOptions)
    self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("RotaAssist", "RotaAssist")
end

function ConfigPanel:OnEnable()
    -- Nothing
end

------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------

---Change presentation only, retaining position, bindings and recommendation mode.
---仅切换展示配置，保留位置、按键和推荐模式。
function ConfigPanel:ApplyViewPreset(name)
    if name ~= "focus" and name ~= "learning" then return false end
    local profile = RA.db.profile
    local learning = name == "learning"
    local display = profile.display
    display.iconCount = 2
    display.showKeybinds = true
    display.showRangeIndicator = true
    display.reducedMotion = true
    display.showResourceBar = true
    display.showPrePullPanel = learning
    profile.coach = profile.coach or {}
    profile.accuracy = profile.accuracy or {}
    profile.cooldowns = profile.cooldowns or {}
    profile.coach.enabled = learning
    profile.accuracy.enabled = learning
    profile.cooldowns.showPanel = learning
    local events = RA:GetModule("EventHandler")
    if events then events:Fire("ROTAASSIST_SETTINGS_RESET") end
    return true
end

function ConfigPanel:Toggle()
    LibStub("AceConfigDialog-3.0"):Open("RotaAssist")
end

function ConfigPanel:Open()
    LibStub("AceConfigDialog-3.0"):Open("RotaAssist")
end

function ConfigPanel:Close()
    LibStub("AceConfigDialog-3.0"):Close("RotaAssist")
end
