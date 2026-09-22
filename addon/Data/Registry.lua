-- RotaAssist - Centralized Data Registry
-- Shared constants for passive spell filters, override pairs, and fallback values.
local _, NS = ...
local RA = NS.RA

RA.Registry = RA.Registry or {}

-- Passive/non-castable spell blacklist (shared by SmartQueue, APL, NeuralPredictor)
RA.Registry.PASSIVE_BLACKLIST = {
    [203555] = true,  -- Demon Blades (Havoc DH passive)
    [342817] = true,  -- Glaive Tempest (Havoc Blade Dance proc, not a cast action)
    [290271] = true,  -- Demon Blades AI Passive variant
    [412713] = true,  -- Interwoven Threads (Evoker Aug passive)
}

-- Bidirectional override pairs (shared cooldown / form-swap spells)
RA.Registry.OVERRIDE_PAIRS = {
    [188499] = 210152, [210152] = 188499,  -- Blade Dance <-> Death Sweep
    [162243] = 203555, [203555] = 162243,  -- Demon's Bite <-> Demon Blades
    [162794] = 201427, [201427] = 162794,  -- Chaos Strike <-> Annihilation
}

-- Fallback texture ID (question mark icon)
RA.Registry.FALLBACK_TEXTURE = 134400

-- Observable Havoc context IDs, pinned to the source audit.
-- 浩劫可观测战况：近战探针不等于所有范围技能的命中半径。
RA.Registry.HAVOC_CONTEXT = {
    specID = 577, meleeProbe = 162794, metaAura = 162264, essenceBreakAura = 320338,
    powerType = 17,
    -- Pinned SimC class source, 774babd: real buff IDs, not virtual flags.
    -- 固定版本职业源码中的真实光环 ID，不包含模拟器内部强化标志。
    playerAuraFacts = {
        ["buff.initiative"] = 391215,
        ["buff.inertia_trigger"] = 1215159,
        ["buff.metamorphosis"] = 162264,
        ["buff.reavers_glaive"] = 444686,
        ["buff.glaive_flurry"] = 442435,
        ["buff.rending_strike"] = 442442,
    },
}

-- One-way learned-base evidence; a pair alone never proves a proc is active.
-- 已学基础技能映射；还必须实时确认替换，不能把静态映射当作触发状态。
RA.Registry.ACTIVE_OVERRIDE_BASES = {
    [442294] = 185123, -- Reaver's Glaive -> Throw Glaive (Havoc only)
    [201427] = 162794, [210152] = 188499,
}
RA.Registry.HAVOC_HERO_TALENTS = {fel_scarred=452402, aldrachi_reaver=442290}

-- SimC 774babd, 12.1.0.69875: selected-talent transitions, not damage weights.
-- 固定版本天赋状态转移；持续时间下界不当作精确光环时长。
RA.Registry.HAVOC_TRANSITIONS = {
    specID = 577, eyeBeam = 198013, metamorphosis = 191427,
    demonicTalent = 213410, chaoticTalent = 388112,
    demonicMinimum = 5, metamorphosisDuration = 20,
    resetCooldowns = {198013, 188499, 210152},
}

-- Model flags from SimC 774babd, not client aura IDs / 模型标志不是光环 ID。
RA.Registry.HAVOC_SURGE = {
    specID = 577, talent = 452402, demonicTalent = 213410, metaAura = 162264,
    metamorphosis = 191427, eyeBeam = 198013, abyssalGaze = 452497,
    manualMinimum = 20, demonicMinimum = 5,
    facts = {"action.annihilation.demonsurge_available", "action.death_sweep.demonsurge_available",
        "action.immolation_aura.demonsurge_available"},
    consumers = {[201427]=1, [162794]=1, [210152]=2, [188499]=2, [258920]=3},
}

-- Backward compatibility for legacy callers.
RA.KNOWN_OVERRIDE_PAIRS = RA.Registry.OVERRIDE_PAIRS
