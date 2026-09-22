------------------------------------------------------------------------
-- RotaAssist - English Locale (Primary)
-- All user-facing text keys are defined here first.
-- Other locale files only override translations.
------------------------------------------------------------------------

local L = LibStub("AceLocale-3.0"):NewLocale("RotaAssist", "enUS", true)
if not L then return end

------------------------------------------------------------------------
-- General
------------------------------------------------------------------------
L["ADDON_NAME"]         = "RotaAssist"
L["STARTUP_MESSAGE"]    = "RotaAssist v%s loaded. Type /ra for help."
L["UNKNOWN_COMMAND"]    = "Unknown command: %s — Type /ra help"

------------------------------------------------------------------------
-- Slash Command Help
------------------------------------------------------------------------
L["SLASH_HELP_HEADER"]  = "RotaAssist Commands:"
L["SLASH_HELP_CONFIG"]  = "Open settings panel"
L["SLASH_HELP_TOGGLE"]  = "Toggle display on/off"
L["SLASH_HELP_LOCK"]    = "Lock/unlock display position"
L["SLASH_HELP_RESET"]   = "Reset all settings to defaults"
L["SLASH_HELP_DEBUG"]   = "Toggle debug mode"
L["SLASH_HELP_VERSION"] = "Show version info"

------------------------------------------------------------------------
-- Settings / Config Panel
------------------------------------------------------------------------
L["CONFIG_NOT_LOADED"]  = "Config panel is not loaded yet."
L["SETTINGS_RESET"]     = "All settings have been reset to defaults."
L["DEBUG_ENABLED"]      = "Debug mode: ON"
L["DEBUG_DISABLED"]     = "Debug mode: OFF"

-- Config panel headers
L["CONFIG_HEADER_GENERAL"]    = "General"
L["CONFIG_HEADER_DISPLAY"]    = "Display"
L["CONFIG_HEADER_COOLDOWNS"]  = "Cooldowns"
L["CONFIG_HEADER_ABOUT"]      = "About"
L["CONFIG_HEADER_COACH"]      = "Coach Attachments"
L["CONFIG_HEADER_ALERTS"]     = "Alerts"

-- General settings
L["CONFIG_ENABLED"]           = "Enable RotaAssist"
L["CONFIG_ENABLED_DESC"]      = "Toggle the addon on or off."
L["CONFIG_LANGUAGE"]          = "Language"
L["CONFIG_LANGUAGE_DESC"]     = "Select display language (requires /reload)."
L["CONFIG_DEBUG"]             = "Debug Mode"
L["CONFIG_DEBUG_DESC"]        = "Show debug messages in chat."
L["CONFIG_MINIMAP"]           = "Show Minimap Button"
L["CONFIG_MINIMAP_DESC"]      = "Toggle the minimap icon."

-- Display settings
L["CONFIG_ICON_COUNT"]        = "Number of Icons"
L["CONFIG_ICON_COUNT_DESC"]   = "How many lookahead prediction icons to show next to the main spell (1-4)."
L["CONFIG_ICON_SPACING"]      = "Icon Spacing"
L["CONFIG_ICON_SPACING_DESC"] = "Gap between icons in the strip, in pixels."
L["CONFIG_SCALE"]             = "Scale"
L["CONFIG_SCALE_DESC"]        = "Overall display scale (50% - 200%)."
L["CONFIG_ALPHA"]             = "Opacity"
L["CONFIG_ALPHA_DESC"]        = "Display opacity (10% - 100%)."
L["CONFIG_LOCK"]              = "Lock Position"
L["CONFIG_LOCK_DESC"]         = "Prevent the display from being dragged."
L["CONFIG_SHOW_OOC"]          = "Show Out of Combat"
L["CONFIG_SHOW_OOC_DESC"]     = "Keep the display visible outside combat."
L["CONFIG_FADE_OOC"]          = "Fade Out of Combat"
L["CONFIG_FADE_OOC_DESC"]     = "Reduce opacity when not in combat."
L["CONFIG_KEYBINDS"]          = "Show Keybinds"
L["CONFIG_KEYBINDS_DESC"]     = "Display keybind text on icons."
L["CONFIG_COOLDOWN_SWIRL"]    = "Show Cooldown Spiral"
L["CONFIG_COOLDOWN_SWIRL_DESC"] = "Show the cooldown sweep animation on icons."
L["CONFIG_HIDE_CD_PREDICTIONS"]      = "Hide Predictions on Cooldown"
L["CONFIG_HIDE_CD_PREDICTIONS_DESC"] = "Drop predicted spells that are still on cooldown instead of showing them with a sweep."
L["CONFIG_SHOW_RANGE"]        = "Show Range Indicator"
L["CONFIG_SHOW_RANGE_DESC"]   = "Pulse the main icon red when the target is out of range."
L["CONFIG_SHOW_PROC"]         = "Show Proc Glow"
L["CONFIG_SHOW_PROC_DESC"]    = "Glow the main icon when Blizzard flags the spell as procced."

-- Coach attachments
L["CONFIG_PHASE_INDICATOR"]      = "Show Phase Indicator"
L["CONFIG_PHASE_INDICATOR_DESC"] = "Show the combat-phase badge above the icon strip."
L["CONFIG_RESOURCE_BAR"]         = "Show Resource Bar"
L["CONFIG_RESOURCE_BAR_DESC"]    = "Show the primary resource bar under the icon strip."
L["CONFIG_ACCURACY_METER"]       = "Show Recommendation Adherence"
L["CONFIG_ACCURACY_METER_DESC"]  = "Show how often your casts match RotaAssist's recommendation. This is not a DPS score."
L["CONFIG_PREPULL_PANEL"]        = "Show Pre-Pull Checklist"
L["CONFIG_PREPULL_PANEL_DESC"]   = "Show the out-of-combat readiness checklist."

-- Alerts
L["CONFIG_DEFENSIVE_SOUND"]      = "Defensive Sound Alert"
L["CONFIG_DEFENSIVE_SOUND_DESC"] = "Play a warning sound when a defensive is recommended."
L["CONFIG_INTERRUPT_SOUND"]      = "Interrupt Sound Alert"
L["CONFIG_INTERRUPT_SOUND_DESC"] = "Play a warning sound for high-urgency interrupts."

-- Cooldown panel
L["CONFIG_CD_ENABLED"]        = "Enable Cooldown Panel"
L["CONFIG_CD_ENABLED_DESC"]   = "Show the major cooldown tracking strip."
L["CONFIG_CD_SCALE"]          = "Cooldown Panel Scale"
L["CONFIG_CD_SCALE_DESC"]     = "Scale of the cooldown tracking strip (50% - 200%)."
L["CONFIG_CD_LOCK"]           = "Lock Cooldown Panel"
L["CONFIG_CD_LOCK_DESC"]      = "Prevent the cooldown panel from being dragged."

------------------------------------------------------------------------
-- Display / UI
------------------------------------------------------------------------
L["DISPLAY_LOCKED"]           = "Display locked."
L["DISPLAY_UNLOCKED"]         = "Display unlocked. Drag to reposition."
L["DISPLAY_ENABLED"]          = "Display enabled."
L["DISPLAY_DISABLED"]         = "Display hidden."

-- Right-click context menu (MainDisplay)
L["LOCK_POSITION"]            = "Lock Position"
L["UNLOCK_POSITION"]          = "Unlock Position"
L["COMBAT_ONLY_TOOLTIP"]      = "Combat Only"
L["OPTIONS"]                  = "Options"

-- PrePull Panel (PrePullPanel widget)
L["PREPULL_CHECKLIST"]        = "Pre-Pull Checklist"
L["MISSING_ITEMS"]            = "Missing %d items"

------------------------------------------------------------------------
-- Cooldown Tracker
------------------------------------------------------------------------
L["CD_READY"]                 = "Ready"
L["CD_SECONDS"]               = "%ds"
L["CD_MINUTES"]               = "%d:%02d"
-- Compact variants rendered on top of a 28px cooldown icon (CooldownBar widget)
L["CD_READY_SHORT"]           = "OK"
L["CD_MINUTES_SHORT"]         = "%dm"
-- Placeholder used when a spell name cannot be resolved
L["SPELL_UNNAMED"]            = "Spell#%d"

------------------------------------------------------------------------
-- Tooltips & Info
------------------------------------------------------------------------
L["TOOLTIP_SOURCE_BLIZZARD"]  = "Source: Blizzard Recommendation"
L["TOOLTIP_SOURCE_APL"]       = "Source: APL Prediction"
L["INDEPENDENT_USAGE"]       = "/ra independent on|off - experimental independent recommendations"
L["BUILD_USAGE"] = "/ra build - inspect current character configuration"
L["BUILD_READY"] = "complete"
L["BUILD_UNKNOWN"] = "Configuration incomplete or talents not committed; independent mode cannot confirm this build."
L["BUILD_STATUS"] = "Spec %d / config %d / hero subtree %s: %d selected entries, %d scanned nodes."
L["BUILD_METADATA"] = "Equipment: %d items (%s). Rotation/talent spell metadata: %d entries."
L["BUILD_STATS"] = "Observed attack power %s; haste %s%%; crit %s%%; mastery effect %s%%."
L["BUILD_IMPORT"] = "Talent import: %s"
L["BUILD_LIMITS"] = "Configuration recognition is not DPS qualification. Stats and spell metadata are snapshots; damage coefficients and all talent effects are not calibrated."
L["INDEPENDENT_ENABLED"]     = "Experimental independent recommendations enabled. This policy has not beaten the reference benchmark. Unknown states use the existing fallback."
L["INDEPENDENT_DISABLED"]    = "Experimental independent recommendations disabled."
L["INDEPENDENT_BADGE"]       = "EXP"
L["TOOLTIP_SOURCE_COOLDOWN"]  = "Source: Cooldown Ready"
L["TOOLTIP_CONFIDENCE"]       = "Confidence: %d%%"
L["TOOLTIP_KEYBIND"]          = "Keybind: %s"
L["TOOLTIP_COOLDOWN"]         = "Cooldown: %s"
L["TOOLTIP_DRAG_HINT"]        = "Left-click to drag. Right-click for options."
L["TOOLTIP_MINIMAP_LEFT"]     = "Left-click: Open settings"
L["TOOLTIP_MINIMAP_RIGHT"]    = "Right-click: Toggle display"

------------------------------------------------------------------------
-- About
------------------------------------------------------------------------
L["ABOUT_DESCRIPTION"]        = "RotaAssist is an intelligent combat assistant for WoW Midnight (12.0). A smart Hekili alternative with multi-language support."
L["ABOUT_VERSION"]            = "Version: %s"
L["ABOUT_AUTHOR"]             = "Author: RotaAssist Team"
L["ABOUT_LICENSE"]            = "License: MIT"
L["ABOUT_WEBSITE"]            = "Website: github.com/yourname/rotaassist"

------------------------------------------------------------------------
-- Spec Detection
------------------------------------------------------------------------
L["SPEC_DETECTED"]            = "Detected: %s %s (%s)"
L["SPEC_NO_APL"]              = "No APL data found for your specialization."
L["SPEC_APL_LOADED"]          = "APL loaded for %s."

------------------------------------------------------------------------
-- Demon Hunter
------------------------------------------------------------------------
-- Specs
L["spec_havoc"]               = "Havoc"
L["spec_vengeance"]           = "Vengeance"
L["spec_devourer"]            = "Devourer"

-- Hero Talents
L["hero_aldrachi_reaver"]     = "Aldrachi Reaver"
L["hero_fel_scarred"]         = "Fel-Scarred"
L["hero_annihilator"]         = "Annihilator"
L["hero_void_scarred"]        = "Void-Scarred"

-- Abilities
L["EYE_BEAM"]                 = "Eye Beam"
L["BLADE_DANCE"]              = "Blade Dance"
L["DEATH_SWEEP"]              = "Death Sweep"
L["METAMORPHOSIS"]            = "Metamorphosis"
L["THE_HUNT"]                 = "The Hunt"
L["VENGEFUL_RETREAT"]         = "Vengeful Retreat"
L["ESSENCE_BREAK"]            = "Essence Break"
L["GLAIVE_TEMPEST"]           = "Glaive Tempest"
L["IMMOLATION_AURA"]          = "Immolation Aura"
L["FELBLADE"]                 = "Felblade"
L["FEL_RUSH"]                 = "Fel Rush"
L["CHAOS_STRIKE"]             = "Chaos Strike"
L["ANNIHILATION"]             = "Annihilation"
L["FIERY_BRAND"]              = "Fiery Brand"
L["FEL_DEVASTATION"]          = "Fel Devastation"
L["SPIRIT_BOMB"]              = "Spirit Bomb"
L["SOUL_CARVER"]              = "Soul Carver"
L["SIGIL_OF_FLAME"]           = "Sigil of Flame"
L["FRACTURE"]                 = "Fracture"
L["SHEAR"]                    = "Shear"
L["VOID_METAMORPHOSIS"]       = "Void Metamorphosis"
L["VOID_RAY"]                 = "Void Ray"
L["COLLAPSING_STAR"]          = "Collapsing Star"
L["CONSUME"]                  = "Consume"
L["DEVOUR"]                   = "Devour"
L["REAP"]                     = "Reap"
L["CULL"]                     = "Cull"
L["VOIDBLADE"]                = "Voidblade"
L["SOUL_IMMOLATION"]          = "Soul Immolation"
L["SHIFT"]                    = "Shift"

-- Hints
L["HINT_EYE_BEAM_DEMONIC"]    = "Use Eye Beam to enter Demonic form"
L["HINT_VOID_RAY_FURY"]       = "Void Ray at 100 Fury"
L["HINT_COLLAPSING_STAR"]     = "Collapsing Star when 30+ Souls"
L["HINT_REAP_STACKS"]         = "Reap at 3 Voidfall stacks"

------------------------------------------------------------------------
-- Rogue
------------------------------------------------------------------------
L["spec_subtlety"]            = "Subtlety"
L["SHADOW_DANCE"]             = "Shadow Dance"
L["SYMBOLS_OF_DEATH"]         = "Symbols of Death"
L["SECRET_TECHNIQUE"]         = "Secret Technique"
L["SHADOW_BLADES"]            = "Shadow Blades"
L["SHADOWSTRIKE"]             = "Shadowstrike"
L["BACKSTAB"]                 = "Backstab"
L["EVISCERATE"]               = "Eviscerate"
L["BLACK_POWDER"]             = "Black Powder"
L["RUPTURE"]                  = "Rupture"

------------------------------------------------------------------------
-- Shaman
------------------------------------------------------------------------
L["spec_elemental"]           = "Elemental"
L["STORMKEEPER"]              = "Stormkeeper"
L["FIRE_ELEMENTAL"]           = "Fire Elemental"
L["LAVA_BURST"]               = "Lava Burst"
L["LIGHTNING_BOLT"]           = "Lightning Bolt"
L["CHAIN_LIGHTNING"]          = "Chain Lightning"
L["EARTH_SHOCK"]              = "Earth Shock"
L["EARTHQUAKE"]               = "Earthquake"
L["FLAME_SHOCK"]              = "Flame Shock"
L["ICEFURY"]                  = "Icefury"

------------------------------------------------------------------------
-- Druid
------------------------------------------------------------------------
L["spec_balance"]             = "Balance"
L["CELESTIAL_ALIGNMENT"]      = "Celestial Alignment"
L["INCARNATION"]              = "Incarnation"
L["STARSURGE"]                = "Starsurge"
L["STARFALL"]                 = "Starfall"
L["WRATH"]                    = "Wrath"
L["STARFIRE"]                 = "Starfire"
L["MOONFIRE"]                 = "Moonfire"
L["SUNFIRE"]                  = "Sunfire"
L["STELLAR_FLARE"]            = "Stellar Flare"

------------------------------------------------------------------------
-- Smart AI Inference Tips
------------------------------------------------------------------------
L["BURST_SOON_POOL_RESOURCE"] = "Burst in %ds — Pool resource!"
L["BURST_READY"]              = "Ready for Burst!"
L["AOE_DETECTED"]             = "%d Targets — AoE Mode"
L["DEATH_SWEEP_NOTE"]         = "Death Sweep = Meta Blade Dance"
L["RESOURCE_CAPPING"]         = "Resource capping! Spend it!"

-- Combat Phases
L["PREPULL"]                  = "Pre-Pull"
L["OPENER"]                   = "Opener"
L["NORMAL"]                   = "Normal"
L["AOE"]                      = "AoE"
L["BURST_PREPARE"]            = "Burst Soon"
L["BURST_ACTIVE"]             = "BURST!"
L["BURST_COOLDOWN"]           = "Cooldown"
L["RESOURCE_STARVED"]         = "Low Res"
L["RESOURCE_CAP"]             = "Cap!"
L["EXECUTE"]                  = "Execute"
L["EMERGENCY"]                = "DANGER!"

-- UI Toggles & Metrics
L["SHOW_ACCURACY_METER"]      = "Show Recommendation Adherence"
L["SHOW_PHASE_INDICATOR"]     = "Show Phase Indicator"
L["SHOW_RESOURCE_BAR"]        = "Show Resource Bar"
L["ACCURACY"]                 = "Recommendation Adherence"
L["BLIZZARD_ACCURACY"]        = "Blizzard Recommendation Match"
L["SMART_ACCURACY"]           = "RotaAssist Recommendation Match"
-- Single-character mode suffix on the accuracy meter: S = SmartQueue, B = Blizzard
L["ACCURACY_SUFFIX_SMART"]    = "S"
L["ACCURACY_SUFFIX_BLIZZARD"] = "B"

------------------------------------------------------------------------
-- Missing Keys (Fix AceLocale strict mode errors)
------------------------------------------------------------------------
L["UNKNOWN"]                  = "Unknown"
L["USE_DEFENSIVE"]            = "USE!"
L["READY_STATUS"]             = "✓ Ready!"
L["COMBAT_ENDED"]             = "COMBAT_ENDED"
L["ICON_SIZE_TOOLTIP"]        = "Scale"
L["PHASE_UNKNOWN"]            = "Unknown"
L["ACCURACY_LABEL"]           = "Adherence"
L["COMBAT_ONLY_MODE"]         = "Combat Only Mode"
L["MINIMAP_TOOLTIP_TITLE"]    = "RotaAssist"
L["DISPLAY_MODE"]             = "Display Mode"
L["INTERRUPT_ALERT"]          = "INTERRUPT!"
L["COOLDOWN_READY_ALERT"]     = "CD Ready!"
L["AOE_MODE"]                 = "AoE Mode"

------------------------------------------------------------------------
-- Spec Support Scope (v1.1.0 ships Demon Hunter only — see D-014)
-- 专精支持范围（v1.1.0 仅发布恶魔猎手三专精 —— 见 D-014）
------------------------------------------------------------------------
-- %s = localized spec name. Shown once per unsupported spec, then the addon
-- keeps running in pure Blizzard-recommendation mode.
-- %s = 本地化专精名。每个不支持的专精只提示一次，之后插件继续以纯暴雪推荐模式运行。
L["SPEC_NOT_SUPPORTED"]       = "%s is not yet supported — showing Blizzard's suggestion only."


-- Recommendation clarity / 推荐可读性
L["CONFIG_REDUCED_MOTION"] = "Reduce icon motion"
L["CONFIG_REDUCED_MOTION_DESC"] = "Update recommendation icons immediately; use static borders instead of pulsing glows. Other panels keep their own animations."
L["RANGE_BADGE"] = "Range"
L["STATUS_SELECT_TARGET"] = "Select a target"
L["STATUS_WAITING"] = "Waiting for a recommendation"
L["CONFIG_QUICK_START"] = "Large icon: next action. Small icons: forecasts that may change. Right-click the strip for settings; /ra lock toggles the dragging lock. Choose a view below."
L["CONFIG_FOCUS_PRESET"] = "Combat focus"
L["CONFIG_FOCUS_PRESET_DESC"] = "Keep recommendations, resources and safety alerts. Hide the coaching, adherence and separate cooldown panels."
L["CONFIG_LEARNING_PRESET"] = "Learning view"
L["CONFIG_LEARNING_PRESET_DESC"] = "Show coaching, pre-pull checks, adherence and cooldowns. Adherence measures following suggestions, not DPS quality."
L["CAPTURE_USAGE"] = "/ra capture on|off — record public recommendation samples locally for testing. Starting replaces the previous capture."
L["CAPTURE_ENABLED"] = "Capture started (up to 1200 events). Reload or log out normally after stopping to save. This is not a DPS measurement."
L["CAPTURE_DISABLED"] = "Capture stopped. Samples will be saved in this profile's SavedVariables on reload or normal logout."
