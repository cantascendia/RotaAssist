-- test: stable Havoc hero profile selection across localized clients and API failures.
local helpers = require("tests.helpers")

describe("Havoc talent profile IDs", function()
    local RA, APL, havoc

    setup(function()
        local ns
        RA, ns = helpers.loadAddon()
        helpers.loadRegistry(ns)
        helpers.loadAddonFile("addon/Engine/APLEngine.lua", "RotaAssist", ns)
        helpers.loadAddonFile("addon/Data/APL/DemonHunter_Havoc.lua", "RotaAssist", ns)
        APL = RA:GetModule("APLEngine")
        havoc = RA.APLData[577]
    end)

    local function selectDefinitions(ids, localeName)
        local spells = {
            [122524] = 442290,
            [122526] = 452402,
            [122511] = 452412,
            [141389] = 452412,
        }
        _G._testTalentConfigID = 1
        _G._testTalentConfigInfo = { [1] = { treeIDs = { 101 } } }
        _G._testTalentTreeNodes = { [101] = {} }
        _G._testTalentNodeInfo = {}
        _G._testTalentEntryInfo = {}
        _G._testTalentDefinitionInfo = {}
        for i, definitionID in ipairs(ids) do
            local nodeID, entryID = 200 + i, 300 + i
            _G._testTalentTreeNodes[101][i] = nodeID
            _G._testTalentNodeInfo["1:" .. nodeID] = {
                activeRank = 1, activeEntry = { entryID = entryID },
            }
            _G._testTalentEntryInfo["1:" .. entryID] = { definitionID = definitionID }
            _G._testTalentDefinitionInfo[definitionID] = {
                spellID = spells[definitionID], overrideName = localeName,
            }
        end
    end

    it("selects Fel-Scarred from numeric definitions with Chinese and Japanese names", function()
        selectDefinitions({ 122526 }, "恶魔涌动")
        APL:SetAPL(577, havoc, 12)
        assert.equals("fel_scarred", APL:GetProfileName())

        selectDefinitions({ 141389 }, "苦痛の弟子")
        APL:RefreshProfileFromTalents()
        assert.equals("fel_scarred", APL:GetProfileName())
    end)

    it("resolves Aldrachi and conflicting hero signatures to the safe default", function()
        selectDefinitions({ 122524 }, "战刃艺术")
        APL:SetAPL(577, havoc, 12)
        assert.equals("default", APL:GetProfileName())

        selectDefinitions({ 122524, 122526 }, "任意の才能")
        APL:RefreshProfileFromTalents()
        assert.equals("default", APL:GetProfileName())
    end)

    it("does not treat an unselected choice entry as an active hero talent", function()
        selectDefinitions({}, "未选择")
        _G._testTalentTreeNodes[101] = { 201 }
        _G._testTalentNodeInfo["1:201"] = {
            activeRank = 1, entryIDs = { 301, 302 },
        }
        _G._testTalentEntryInfo["1:301"] = { definitionID = 122526 }
        _G._testTalentEntryInfo["1:302"] = { definitionID = 999999 }
        _G._testTalentDefinitionInfo[122526] = { spellID = 452402 }
        _G._testTalentDefinitionInfo[999999] = { spellID = 999999 }
        APL:SetAPL(577, havoc, 12)
        assert.equals("default", APL:GetProfileName())
    end)

    it("drops a stale profile when the talent API fails or the spec changes", function()
        selectDefinitions({ 122526 }, "恶魔涌动")
        APL:SetAPL(577, havoc, 12)
        assert.equals("fel_scarred", APL:GetProfileName())

        local original = C_ClassTalents.GetActiveConfigID
        C_ClassTalents.GetActiveConfigID = function() error("temporary API failure") end
        APL:RefreshProfileFromTalents()
        assert.equals("default", APL:GetProfileName())
        C_ClassTalents.GetActiveConfigID = original

        selectDefinitions({ 122526 }, "恶魔涌动")
        APL:SetAPL(577, havoc, 12)
        _G._testTalentConfigID = nil
        APL:SetAPL(581, { profiles = { default = {}, fel_scarred = {} } }, 12)
        assert.equals("default", APL:GetProfileName())
    end)

    teardown(function()
        _G._testTalentConfigID = nil
        _G._testTalentConfigInfo = nil
        _G._testTalentTreeNodes = nil
        _G._testTalentNodeInfo = nil
        _G._testTalentEntryInfo = nil
        _G._testTalentDefinitionInfo = nil
    end)
end)
