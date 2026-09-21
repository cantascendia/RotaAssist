-- tests/test_release_engine_safety.lua
-- test: additive release-safety regressions for authoritative recommendation
-- ordering, unverified-spec fallback, truthful lifecycle state, and secret values.
local helpers = require("tests.helpers")

describe("release engine safety", function()
    describe("authoritative slot 1", function()
        local SQM

        setup(function()
            local RA, ns = helpers.loadAddon()
            helpers.loadRegistry(ns)
            helpers.loadAddonFile("addon/Engine/SmartQueueManager.lua", "RotaAssist", ns)
            SQM = RA:GetModule("SmartQueueManager")
        end)

        it("keeps Blizzard first across a grid of larger heuristic scores", function()
            -- Property-style invariant: score magnitude must never let a local
            -- heuristic displace an available Blizzard recommendation.
            for competitorScore = 1.1, 10.0, 0.1 do
                local scored = {
                    { spellID = 222, score = competitorScore, source = "APL_BLINDSPOT" },
                    { spellID = 111, score = 1.0, source = "BLIZZARD" },
                    { spellID = 333, score = competitorScore / 2, source = "APL" },
                }
                SQM._PromoteAuthoritativeMain(scored, 111)
                assert.equals(111, scored[1].spellID)
                assert.equals("BLIZZARD", scored[1].source)
            end
        end)

        it("leaves fallback score order intact when Blizzard has no candidate", function()
            local scored = {
                { spellID = 222, score = 1.2 },
                { spellID = 333, score = 0.5 },
            }
            SQM._PromoteAuthoritativeMain(scored, nil)
            assert.equals(222, scored[1].spellID)
        end)
    end)

    describe("actionable queue provenance", function()
        local function buildQueue(hasAPL, blizzSpell, predictions, includeHeuristics)
            local RA, ns = helpers.loadAddon()
            helpers.loadRegistry(ns)
            RA.db = {
                profile = {
                    display = { showOutOfCombat = true },
                    smartQueue = {
                        blizzardWeight = 1.0, aplWeight = 0.6, aiWeight = 0.4,
                        cdWeight = 0.5, defWeight = 0.8,
                    },
                },
            }
            RA.WhitelistSpells = {
                [111] = { cdSeconds = 0 },
                [222] = { cdSeconds = 0 },
                [333] = { cdSeconds = 0 },
            }

            RA:RegisterModule("AssistedCombatBridge", {
                GetCurrentRecommendation = function()
                    return blizzSpell and { spellID = blizzSpell } or nil
                end,
                GetRotationSpells = function() return {} end,
            })
            RA:RegisterModule("APLEngine", {
                HasAPL = function() return hasAPL end,
                PredictNext = function()
                    if type(predictions) == "function" then return predictions() end
                    return predictions or {}
                end,
                IsMetaActive = function() return false end,
                GetCurrentAPL = function()
                    return {
                        rules = includeHeuristics and {
                            { spellID = 222, condition = "always" },
                        } or {},
                    }
                end,
                EvaluateCondition = function() return true end,
            })
            RA:RegisterModule("CooldownOverlay", {
                GetCooldownStates = function()
                    return includeHeuristics and {
                        [222] = { ready = true, remaining = 0 },
                    } or {}
                end,
            })
            RA:RegisterModule("DefensiveAdvisor", {
                GetActiveRecommendation = function()
                    return includeHeuristics and { spellID = 333, urgency = 1.0 } or nil
                end,
            })

            helpers.loadAddonFile("addon/Engine/SmartQueueManager.lua", "RotaAssist", ns)
            local SQM = RA:GetModule("SmartQueueManager")
            SQM:OnInitialize()
            SQM:OnEnable()
            SQM._AssembleQueue()
            return SQM:GetFinalQueue(), SQM
        end

        it("is genuinely Blizzard-only when no predictive APL is enabled", function()
            local queue = buildQueue(false, 111, {}, true)
            assert.equals(111, queue.main.spellID)
            assert.equals("BLIZZARD", queue.main.source)
            assert.equals(0, #queue.next)
        end)

        it("keeps Blizzard in assembled slot 1 when a ready APL blind spot scores higher", function()
            local queue = buildQueue(true, 111, {
                { spellID = 222, confidence = 0.9 },
            }, true)
            assert.equals(111, queue.main.spellID)
            assert.equals("BLIZZARD", queue.main.source)
        end)

        it("preserves legitimate repeated spells after consuming only the APL head entry", function()
            local queue = buildQueue(true, nil, {
                { spellID = 222, confidence = 0.9 },
                { spellID = 222, confidence = 0.8 },
                { spellID = 333, confidence = 0.7 },
            }, false)
            assert.equals(222, queue.main.spellID)
            assert.equals(222, queue.next[1].spellID)
            assert.equals(333, queue.next[2].spellID)
        end)

        it("keeps a future APL step even when that spell is on cooldown right now", function()
            local originalCooldown = C_Spell.GetSpellCooldown
            C_Spell.GetSpellCooldown = function(spellID)
                if spellID == 333 then
                    return { startTime = 990, duration = 30 }
                end
                return { startTime = 0, duration = 0 }
            end

            local queue = buildQueue(true, nil, {
                { spellID = 222, confidence = 0.9 },
                { spellID = 333, confidence = 0.8 },
            }, false)
            assert.equals(333, queue.next[1].spellID)

            C_Spell.GetSpellCooldown = originalCooldown
        end)

        it("clears an old tail immediately when the rebuilt APL sequence is empty", function()
            local currentPredictions = {
                { spellID = 222, confidence = 0.9 },
            }
            local queue, SQM = buildQueue(true, 111, function()
                local copy = {}
                for i, entry in ipairs(currentPredictions) do
                    copy[i] = entry
                end
                return copy
            end, false)
            assert.equals(222, queue.next[1].spellID)

            currentPredictions = {}
            SQM._AssembleQueue()
            assert.equals(0, #queue.next)
        end)

        it("ignores events while disabled and restores one callback after re-enable", function()
            local RA, ns = helpers.loadAddon()
            helpers.loadRegistry(ns)
            helpers.loadAddonFile("addon/Core/EventHandler.lua", "RotaAssist", ns)
            local EH = RA:GetModule("EventHandler")

            RA.db = {
                profile = {
                    display = { showOutOfCombat = true },
                    smartQueue = {
                        blizzardWeight = 1.0, aplWeight = 0.6, aiWeight = 0.4,
                        cdWeight = 0.5, defWeight = 0.8,
                    },
                },
            }
            RA.WhitelistSpells = { [111] = { cdSeconds = 0 }, [222] = { cdSeconds = 0 } }

            local currentSpell, recommendationReads = 111, 0
            RA:RegisterModule("AssistedCombatBridge", {
                GetCurrentRecommendation = function()
                    recommendationReads = recommendationReads + 1
                    return { spellID = currentSpell }
                end,
                GetRotationSpells = function() return {} end,
                InvalidateCache = function() end,
            })
            RA:RegisterModule("APLEngine", {
                HasAPL = function() return false end,
                SetMetaStateFromCast = function() end,
            })

            helpers.loadAddonFile("addon/Engine/SmartQueueManager.lua", "RotaAssist", ns)
            local SQM = RA:GetModule("SmartQueueManager")
            SQM:OnInitialize()
            SQM:OnEnable()
            SQM._AssembleQueue()
            assert.equals(111, SQM:GetFinalQueue().main.spellID)

            SQM:OnDisable()
            currentSpell = 222
            recommendationReads = 0
            EH:Fire("ROTAASSIST_SPELLCAST_SUCCEEDED", "player", "cast", 222)
            assert.equals(0, recommendationReads)
            assert.is_nil(SQM:GetFinalQueue().main)

            SQM:OnEnable()
            recommendationReads = 0
            EH:Fire("ROTAASSIST_SPELLCAST_SUCCEEDED", "player", "cast", 222)
            assert.equals(1, recommendationReads)
            assert.equals(222, SQM:GetFinalQueue().main.spellID)
        end)
    end)

    describe("unverified predictive data", function()
        it("keeps Devourer in Blizzard-only mode even when placeholder APL data is loaded", function()
            local originalGetSpecialization = _G.GetSpecialization
            local originalGetSpecializationInfo = _G.GetSpecializationInfo
            local originalUnitClass = _G.UnitClass

            _G.GetSpecialization = function() return 1 end
            _G.GetSpecializationInfo = function()
                return 1480, "Devourer", "", 0, "DAMAGER"
            end
            _G.UnitClass = function()
                return "Demon Hunter", "DEMONHUNTER", 12
            end

            local RA, ns = helpers.loadAddon()
            helpers.loadRegistry(ns)
            RA.APLData = {
                [1480] = { specID = 1480, class = "DEMONHUNTER", rules = {} },
            }

            local setCalls, clearCalls = 0, 0
            RA:RegisterModule("APLEngine", {
                SetAPL = function() setCalls = setCalls + 1 end,
                ClearAPL = function() clearCalls = clearCalls + 1 end,
            })
            helpers.loadAddonFile("addon/Engine/SpecDetector.lua", "RotaAssist", ns)
            local specDetector = RA:GetModule("SpecDetector")
            specDetector:OnEnable()

            assert.equals(0, setCalls)
            assert.equals(1, clearCalls)
            assert.is_false(specDetector:IsPredictiveSpecSupported(1480))

            _G.GetSpecialization = originalGetSpecialization
            _G.GetSpecializationInfo = originalGetSpecializationInfo
            _G.UnitClass = originalUnitClass
        end)
    end)

    describe("truthful module lifecycle", function()
        it("stops all dependent startup when SavedVars initialization failed", function()
            local RA = helpers.loadAddon()
            local dependentInitialized, dependentEnabled = false, false
            RA:RegisterModule("SavedVars", {
                OnInitialize = function() error("intentional SavedVars failure") end,
            })
            RA:RegisterModule("ReleaseSafetyDependent", {
                OnInitialize = function() dependentInitialized = true end,
                OnEnable = function() dependentEnabled = true end,
            })

            RA:OnInitialize()
            RA:OnEnable()

            assert.is_false(dependentInitialized)
            assert.is_false(dependentEnabled)
        end)

        it("does not enable a module whose initialization failed", function()
            local RA = helpers.loadAddon()
            RA:OnInitialize()

            local enableCalled = false
            local broken = {
                OnInitialize = function() error("intentional init failure") end,
                OnEnable = function() enableCalled = true end,
            }
            RA:RegisterModule("ReleaseSafetyBrokenInit", broken)
            RA:OnEnable()

            assert.is_false(broken._initialized)
            assert.is_false(broken._enabled)
            assert.is_false(enableCalled)
            assert.is_not_nil(broken._initializationFailed)
        end)

        it("does not report enable success when OnEnable failed", function()
            local RA = helpers.loadAddon()
            RA:OnInitialize()

            local broken = {
                OnInitialize = function() end,
                OnEnable = function() error("intentional enable failure") end,
            }
            RA:RegisterModule("ReleaseSafetyBrokenEnable", broken)
            RA:OnEnable()

            assert.is_true(broken._initialized)
            assert.is_false(broken._enabled)
            assert.is_not_nil(broken._enableFailed)
        end)
    end)

    describe("secret cooldown fields", function()
        it("never truth-tests or compares secret charge fields", function()
            local RA = helpers.loadAddon()
            local originalCooldown = C_Spell.GetSpellCooldown
            local originalCharges = C_Spell.GetSpellCharges
            local originalIsSecret = _G.issecretvalue

            C_Spell.GetSpellCooldown = function()
                return { startTime = 999, duration = 1.5 }
            end
            C_Spell.GetSpellCharges = function()
                return {
                    maxCharges = "SECRET",
                    currentCharges = "SECRET",
                    cooldownStartTime = "SECRET",
                    cooldownDuration = "SECRET",
                }
            end
            _G.issecretvalue = function(value) return value == "SECRET" end

            local ok, remaining = pcall(RA.GetSpellCooldownSafe, RA, 12345)
            assert.is_true(ok)
            assert.is_number(remaining)

            C_Spell.GetSpellCooldown = originalCooldown
            C_Spell.GetSpellCharges = originalCharges
            _G.issecretvalue = originalIsSecret
        end)
    end)
end)
