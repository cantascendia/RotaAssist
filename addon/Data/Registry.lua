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
}

-- Backward compatibility for legacy callers.
RA.KNOWN_OVERRIDE_PAIRS = RA.Registry.OVERRIDE_PAIRS
