-- test: additive safety cases for Blizzard SpellCooldownInfo.isEnabled.
local helpers = require("tests.helpers")

describe("cooldown enabled-state provenance", function()
    local RA
    local originalCooldown
    local originalSecretCheck

    before_each(function()
        RA = helpers.loadAddon()
        originalCooldown = C_Spell.GetSpellCooldown
        originalSecretCheck = issecretvalue
    end)

    after_each(function()
        C_Spell.GetSpellCooldown = originalCooldown
        _G.issecretvalue = originalSecretCheck
    end)

    it("does not declare an on-hold zero-duration cooldown ready", function()
        C_Spell.GetSpellCooldown = function()
            return { startTime = 100, duration = 0, isEnabled = false, isActive = false }
        end
        local remaining, ready, startTime, duration = RA:GetSpellCooldownSafe(12345)
        assert.is_nil(remaining)
        assert.is_nil(ready)
        assert.is_nil(startTime)
        assert.is_nil(duration)
    end)

    it("treats an on-hold positive-duration cooldown as unknown", function()
        C_Spell.GetSpellCooldown = function()
            return { startTime = 100, duration = 30, isEnabled = false, isActive = false }
        end
        local remaining, ready, startTime, duration = RA:GetSpellCooldownSafe(12345)
        assert.is_nil(remaining)
        assert.is_nil(ready)
        assert.is_nil(startTime)
        assert.is_nil(duration)
    end)

    it("keeps an enabled inactive zero-duration cooldown ready", function()
        C_Spell.GetSpellCooldown = function()
            return { startTime = 0, duration = 0, isEnabled = true, isActive = false }
        end
        local remaining, ready, startTime, duration = RA:GetSpellCooldownSafe(12345)
        assert.equals(0, remaining)
        assert.is_true(ready)
        assert.equals(0, startTime)
        assert.equals(0, duration)
    end)

    it("retains legacy mocks with no isEnabled field", function()
        C_Spell.GetSpellCooldown = function()
            return { startTime = 0, duration = 0, isActive = false }
        end
        local remaining, ready = RA:GetSpellCooldownSafe(12345)
        assert.equals(0, remaining)
        assert.is_true(ready)
    end)

    it("checks secret isEnabled before comparing its value", function()
        _G.issecretvalue = function(value) return value == "SECRET" end
        C_Spell.GetSpellCooldown = function()
            return { startTime = 0, duration = 0, isEnabled = "SECRET" }
        end
        local remaining, ready = RA:GetSpellCooldownSafe(12345)
        assert.is_nil(remaining)
        assert.is_nil(ready)
    end)
end)
