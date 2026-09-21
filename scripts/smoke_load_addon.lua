-- Offline load-order smoke test. This is not a replacement for a WoW client run.
local addonDir = assert(arg[1], "addon directory required")
local mockPath = assert(arg[2], "WoW API mock path required")
assert(loadfile(mockPath))()
-- The general test mock supplies a lightweight LibStub function for unit tests.
-- The packaged library must initialize its real table implementation instead.
_G.LibStub = nil
_G.GetLocale = _G.GetLocale or function() return "enUS" end
_G.GetRealmName = _G.GetRealmName or function() return "OfflineRealm" end
_G.UnitName = _G.UnitName or function() return "OfflinePlayer" end
_G.UnitClass = _G.UnitClass or function() return "Warrior", "WARRIOR", 1 end
_G.UnitRace = _G.UnitRace or function() return "Human", "Human" end
_G.UnitFactionGroup = _G.UnitFactionGroup or function() return "Alliance" end
_G.GetCurrentRegion = _G.GetCurrentRegion or function() return 1 end
_G.GetCurrentRegionName = _G.GetCurrentRegionName or function() return "US" end
local baseCreateFrame = _G.CreateFrame
_G.CreateFrame = function(...)
    local frame = baseCreateFrame(...)
    frame.SetFixedFrameStrata = frame.SetFixedFrameStrata or function() end
    frame.SetFixedFrameLevel = frame.SetFixedFrameLevel or function() end
    frame.SetNormalFontObject = frame.SetNormalFontObject or function() end
    frame.SetHighlightFontObject = frame.SetHighlightFontObject or function() end
    frame.SetNormalTexture = frame.SetNormalTexture or function(self) self._normal = self:CreateTexture() end
    frame.GetNormalTexture = frame.GetNormalTexture or function(self) return self._normal end
    frame.SetPushedTexture = frame.SetPushedTexture or function(self) self._pushed = self:CreateTexture() end
    frame.GetPushedTexture = frame.GetPushedTexture or function(self) return self._pushed end
    frame.SetHighlightTexture = frame.SetHighlightTexture or function(self) self._highlight = self:CreateTexture() end
    frame.GetHighlightTexture = frame.GetHighlightTexture or function(self) return self._highlight end
    frame.HookScript = frame.HookScript or function(self, event, callback) self:SetScript(event, callback) end
    return frame
end
_G.Minimap = _G.Minimap or _G.CreateFrame("Frame", "Minimap", _G.UIParent)

local namespace = {}
for index = 3, #arg do
    local relative = arg[index]
    local path = addonDir .. "/" .. relative
    local chunk, loadError = loadfile(path)
    if not chunk then
        error("compile failed for " .. relative .. ": " .. tostring(loadError))
    end
    local ok, runtimeError = pcall(chunk, "RotaAssist", namespace)
    if not ok then
        error("load failed for " .. relative .. ": " .. tostring(runtimeError))
    end
end

assert(_G.RotaAssist, "RotaAssist global was not created")
print("PASS: loaded " .. tostring(#arg - 2) .. " Lua files in TOC/XML order")
