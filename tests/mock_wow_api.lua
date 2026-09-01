-- RotaAssist WoW API Mock for busted unit tests
-- WoW 插件单元测试用 API 模拟层
-- All globals that WoW addons expect are set here on _G.

-- ============================================================
-- Table utilities (WoW builtins that may not exist in vanilla Lua)
-- ============================================================

--- wipe(t): Clear all keys in table, return it (WoW global)
function wipe(t)
    for k in pairs(t) do t[k] = nil end
    return t
end
_G.wipe = wipe

--- strsplit(delim, str, maxParts): split str by delim
function strsplit(delim, str, maxParts)
    local result = {}
    local pattern = string.format("([^%s]+)", delim)
    local count = 0
    for part in str:gmatch(pattern) do
        count = count + 1
        result[count] = part
        if maxParts and count >= maxParts then
            -- Remainder goes into last slot as-is: re-join leftover
            local consumed = table.concat(result, delim, 1, count - 1) .. delim
            result[count] = str:sub(#consumed + 1)
            break
        end
    end
    return unpack(result)
end
_G.strsplit = strsplit

-- ============================================================
-- Chat frame mock
-- ============================================================

DEFAULT_CHAT_FRAME = {
    _messages = {},
    AddMessage  = function(self, msg)
        table.insert(self._messages, msg)
    end,
}
_G.DEFAULT_CHAT_FRAME = DEFAULT_CHAT_FRAME

-- ============================================================
-- Time / Combat state mock
-- ============================================================

--- GetTime(): returns fixed value for deterministic tests
function GetTime() return 1000.0 end
_G.GetTime = GetTime

--- InCombatLockdown(): always false in tests
function InCombatLockdown() return false end
_G.InCombatLockdown = InCombatLockdown

-- ============================================================
-- Secret value mock  (WoW 12.0 security model)
-- ============================================================

--- issecretvalue(): always false — test values are never secret
function issecretvalue(_) return false end
_G.issecretvalue = issecretvalue

-- ============================================================
-- Unit API mocks
-- ============================================================

function UnitExists(unit) return unit == "target" or unit == "player" end
function UnitCanAttack(_, unit) return unit == "target" end
function UnitIsDead(unit) return false end
function UnitHealth(unit) return (unit == "player") and 80000 or 50000 end
function UnitHealthMax(unit) return 100000 end
function UnitPower(unit, powerType) return 50 end
function UnitPowerMax(unit, powerType) return 100 end
function UnitCastingInfo(unit) return nil end
function UnitChannelInfo(unit) return nil end

_G.UnitExists     = UnitExists
_G.UnitCanAttack  = UnitCanAttack
_G.UnitIsDead     = UnitIsDead
_G.UnitHealth     = UnitHealth
_G.UnitHealthMax  = UnitHealthMax
_G.UnitPower      = UnitPower
_G.UnitPowerMax   = UnitPowerMax
_G.UnitCastingInfo = UnitCastingInfo
_G.UnitChannelInfo = UnitChannelInfo

-- ============================================================
-- Spell API mocks
-- ============================================================

function IsPlayerSpell(spellID) return true end
function IsPassiveSpell(spellID) return false end
function FindSpellOverrideByID(spellID) return spellID end
function GetActionInfo(slot) return nil end
function GetBindingKey(action) return nil end
function GetAddOnMetadata(name, key) return (key == "Version") and "test-dev" or nil end

_G.IsPlayerSpell        = IsPlayerSpell
_G.IsPassiveSpell       = IsPassiveSpell
_G.FindSpellOverrideByID = FindSpellOverrideByID
_G.GetActionInfo         = GetActionInfo
_G.GetBindingKey         = GetBindingKey
_G.GetAddOnMetadata      = GetAddOnMetadata

-- ============================================================
-- C_Spell namespace mock
-- ============================================================

C_Spell = {
    --- GetSpellCooldown: returns a ready-state (no CD) by default
    GetSpellCooldown = function(spellID)
        return { startTime = 0, duration = 0, isEnabled = true, modRate = 1.0 }
    end,
    --- IsSpellPassive: returns false by default
    IsSpellPassive = function(spellID) return false end,
    --- IsSpellUsable: returns true by default
    IsSpellUsable = function(spellID) return true, false end,
    --- GetOverrideSpell: returns same spellID (no override)
    GetOverrideSpell = function(spellID) return spellID end,
    --- GetSpellCharges: returns single-charge spell info
    GetSpellCharges = function(spellID)
        return { currentCharges = 1, maxCharges = 1,
                 cooldownStartTime = 0, cooldownDuration = 0 }
    end,
    --- GetSpellInfo: returns minimal spell info table
    GetSpellInfo = function(spellID)
        return { name = "MockSpell" .. tostring(spellID), castTime = 0 }
    end,
    --- IsSpellInRange: returns true by default (Round 19 / round15 merge)
    --- 射程判定：默认返回 true（第 19 轮从 round15 合入）
    IsSpellInRange = function(spellID, unit) return true end,
}
_G.C_Spell = C_Spell

-- ============================================================
-- C_SpellActivationOverlay namespace mock (proc glow)
-- Round 19: merged from origin/improve/round15-ui-overhaul.
-- 第 19 轮：从 round15 分支合入，供 proc 高亮测试使用。
-- ============================================================

C_SpellActivationOverlay = {
    IsSpellOverlayed = function(spellID) return false end,
}
_G.C_SpellActivationOverlay = C_SpellActivationOverlay

-- ============================================================
-- C_AddOns namespace mock
-- ============================================================

C_AddOns = {
    GetAddOnMetadata = function(name, key)
        return (key == "Version") and "test-dev" or nil
    end,
}
_G.C_AddOns = C_AddOns

-- ============================================================
-- Talent API mocks
-- ============================================================

C_ClassTalents = {
    GetActiveConfigID = function()
        return _G._testTalentConfigID
    end,
}
_G.C_ClassTalents = C_ClassTalents

C_Traits = {
    GetConfigInfo = function(configID)
        if _G._testTalentConfigInfo then
            return _G._testTalentConfigInfo[configID]
        end
        return nil
    end,
    GetTreeNodes = function(treeID)
        if _G._testTalentTreeNodes then
            return _G._testTalentTreeNodes[treeID]
        end
        return {}
    end,
    GetNodeInfo = function(configID, nodeID)
        if _G._testTalentNodeInfo then
            return _G._testTalentNodeInfo[configID .. ":" .. nodeID]
        end
        return nil
    end,
    GetEntryInfo = function(configID, entryID)
        if _G._testTalentEntryInfo then
            return _G._testTalentEntryInfo[configID .. ":" .. entryID]
        end
        return nil
    end,
    GetDefinitionInfo = function(definitionID)
        if _G._testTalentDefinitionInfo then
            return _G._testTalentDefinitionInfo[definitionID]
        end
        return nil
    end,
}
_G.C_Traits = C_Traits

-- ============================================================
-- C_Timer namespace mock
-- ============================================================

C_Timer = {
    NewTicker = function(interval, callback, iterations)
        -- Return a mock ticker with a Cancel method
        return { Cancel = function(self) end }
    end,
    --- NewTimer: cancellable one-shot timer (Round 19 / round15 merge)
    --- 可取消的一次性定时器（第 19 轮从 round15 合入；IconWidget 的
    --- crossfade 竞态修复与 DefensiveAlert 的自动消失都依赖它）
    NewTimer = function(delay, callback)
        return { Cancel = function(self) end }
    end,
    After = function(delay, callback)
        -- No-op in tests
    end,
}
_G.C_Timer = C_Timer

-- ============================================================
-- CreateFrame mock  (minimal Frame object)
-- ============================================================

local function makeFrame(frameType, name, parent, template)
    local frame = {
        _scripts   = {},
        _alpha     = 1.0,
        _shown     = true,
        _children  = {},
        _type      = frameType or "Frame",
    }

    function frame:SetScript(event, fn) self._scripts[event] = fn end
    function frame:GetScript(event) return self._scripts[event] end
    function frame:Show() self._shown = true end
    function frame:Hide() self._shown = false end
    function frame:IsShown() return self._shown end
    function frame:SetSize(w, h) self._w, self._h = w, h end
    function frame:GetSize() return self._w or 0, self._h or 0 end
    function frame:SetPoint(...) end
    function frame:ClearAllPoints() end
    function frame:SetAlpha(a) self._alpha = a end
    function frame:GetAlpha() return self._alpha end
    function frame:SetScale(s) self._scale = s end
    function frame:GetScale() return self._scale or 1 end
    function frame:SetFrameStrata(s) end
    function frame:SetFrameLevel(n) self._frameLevel = n end
    function frame:GetFrameLevel() return self._frameLevel or 1 end
    -- Round 19 (round15 merge): drag handlers read the current anchor back.
    -- 第 19 轮（合入 round15）：拖拽结束时要读回当前锚点。
    function frame:GetPoint() return "CENTER", nil, "CENTER", 0, 0 end
    function frame:SetMovable(b) end
    function frame:EnableMouse(b) end
    function frame:RegisterForDrag(...) end
    function frame:StartMoving() end
    function frame:StopMovingOrSizing() end
    function frame:SetClampedToScreen(b) end
    function frame:SetWidth(w) self._w = w end
    function frame:SetHeight(h) self._h = h end
    function frame:GetWidth() return self._w or 0 end
    function frame:GetHeight() return self._h or 0 end
    function frame:SetText(t) self._text = t end
    function frame:GetText() return self._text or "" end
    function frame:SetTextColor(...) end
    function frame:SetFont(...) end
    function frame:SetJustifyH(j) end
    function frame:SetJustifyV(j) end
    function frame:SetTexture(t) self._texture = t end
    function frame:GetTexture() return self._texture end
    -- Round 19 (round15 merge): texture/cooldown widgets used by IconWidget.
    -- 第 19 轮（合入 round15）：IconWidget 用到的纹理 / 冷却帧接口。
    function frame:SetTexCoord(...) end
    function frame:SetDesaturated(b) self._desaturated = b end
    function frame:IsDesaturated() return self._desaturated end
    function frame:SetDrawEdge(b) end
    function frame:SetVertexColor(...) self._vertexColor = { ... } end
    function frame:SetAllPoints(parent) end
    function frame:SetMinMaxValues(min, max) self._min, self._max = min, max end
    function frame:SetValue(v) self._value = v end
    function frame:GetValue() return self._value or 0 end
    function frame:SetStatusBarTexture(t) end
    function frame:SetStatusBarColor(...) end
    function frame:SetBackdrop(backdrop) self._backdrop = backdrop end
    function frame:GetBackdrop() return self._backdrop end
    function frame:SetBackdropColor(...) self._backdropColor = { ... } end
    function frame:SetBackdropBorderColor(...) self._backdropBorderColor = { ... } end
    function frame:SetCooldown(start, duration)
        self._cooldownStart = start
        self._cooldownDuration = duration
    end
    function frame:Clear()
        self._cooldownStart = nil
        self._cooldownDuration = nil
    end
    function frame:CreateTexture(name, layer)
        return makeFrame("Texture", name, frame)
    end
    function frame:CreateFontString(name, layer, template)
        return makeFrame("FontString", name, frame)
    end
    -- Round 19 (round15 merge): animation groups back the alert / out-of-range
    -- pulses and the phase / accuracy fade in-out.
    -- 第 19 轮（合入 round15）：动画组支撑警报与超距脉冲、阶段与准确率淡入淡出。
    function frame:CreateAnimationGroup()
        local ag = {
            _looping    = "NONE",
            _playing    = false,
            _scripts    = {},
            _animations = {},
        }
        function ag:SetLooping(mode) self._looping = mode end
        function ag:GetLooping() return self._looping end
        function ag:Play() self._playing = true end
        function ag:Stop() self._playing = false end
        function ag:IsPlaying() return self._playing end
        function ag:SetScript(event, fn) self._scripts[event] = fn end
        function ag:GetScript(event) return self._scripts[event] end
        function ag:CreateAnimation(animType)
            local anim = { _type = animType }
            function anim:SetFromAlpha(a) self._fromAlpha = a end
            function anim:SetToAlpha(a) self._toAlpha = a end
            function anim:SetDuration(d) self._duration = d end
            function anim:SetOrder(o) self._order = o end
            table.insert(ag._animations, anim)
            return anim
        end
        return ag
    end
    function frame:RegisterEvent(event) end
    function frame:UnregisterEvent(event) end
    function frame:UnregisterAllEvents() end

    return frame
end

function CreateFrame(frameType, name, parent, template)
    local frame = makeFrame(frameType, name, parent, template)
    -- WoW publishes named frames as globals; tests rely on that to reach
    -- RotaAssistMainFrame without poking at module internals.
    -- WoW 会把具名框体挂到全局；测试借此拿到 RotaAssistMainFrame，
    -- 而不必窥探模块内部状态。
    if type(name) == "string" and name ~= "" then
        _G[name] = frame
    end
    return frame
end
_G.CreateFrame = CreateFrame

-- ============================================================
-- Sound / UI mock
-- ============================================================

function PlaySound(soundID, channel, forceNoDuplicates) end
_G.PlaySound = PlaySound

-- Round 19 (round15 merge): DefensiveAlert plays a sound file, and the UI
-- fade helpers / action-button glow are used by every alert widget.
-- 第 19 轮（合入 round15）：减伤提示要播音效；淡入淡出与动作条高亮为各警报挂件所用。
function PlaySoundFile(file, channel) end
_G.PlaySoundFile = PlaySoundFile

function UIFrameFadeIn(frame, time, startAlpha, endAlpha)
    if frame and frame.SetAlpha then frame:SetAlpha(endAlpha or 1) end
end
function UIFrameFadeOut(frame, time, startAlpha, endAlpha)
    if frame and frame.SetAlpha then frame:SetAlpha(endAlpha or 0) end
end
_G.UIFrameFadeIn = UIFrameFadeIn
_G.UIFrameFadeOut = UIFrameFadeOut

function ActionButton_ShowOverlayGlow(frame) end
function ActionButton_HideOverlayGlow(frame) end
_G.ActionButton_ShowOverlayGlow = ActionButton_ShowOverlayGlow
_G.ActionButton_HideOverlayGlow = ActionButton_HideOverlayGlow

SOUNDKIT = setmetatable({}, { __index = function(_, k) return 0 end })
_G.SOUNDKIT = SOUNDKIT

STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
_G.STANDARD_TEXT_FONT = STANDARD_TEXT_FONT

UIParent = makeFrame("Frame", "UIParent", nil)
_G.UIParent = UIParent

GameTooltip = makeFrame("GameTooltip", "GameTooltip", UIParent)
function GameTooltip:SetOwner(owner, anchor) end
function GameTooltip:AddLine(text, r, g, b) end
function GameTooltip:Show() end
function GameTooltip:Hide() end
_G.GameTooltip = GameTooltip

-- ============================================================
-- WoW Settings / Menu API mocks
-- ============================================================

Settings = {}
function Settings.RegisterCanvasLayoutCategory(...) end
function Settings.RegisterAddOnCategory(...) end
function Settings.OpenToCategory(...) end
_G.Settings = Settings

function InterfaceOptionsFrame_OpenToCategory(panel) end
_G.InterfaceOptionsFrame_OpenToCategory = InterfaceOptionsFrame_OpenToCategory

MenuUtil = {}
function MenuUtil.CreateContextMenu(...) end
_G.MenuUtil = MenuUtil

Enum = {}
_G.Enum = Enum

-- ============================================================
-- LibStub mock
-- ============================================================

-- Minimal AceAddon-like object that Init.lua constructs via LibStub.
-- 模拟 Ace3 LibStub，返回一个支持 NewAddon 的伪库。

local _libstub_libs = {}

local function makeAceAddon(name, ...)
    local addon = {
        name      = name,
        modules   = {},
        _enabled  = false,
        _mixins   = { ... },
    }

    -- AceEvent message system mock
    -- Stores message callbacks: _messageCallbacks[eventName] = callback
    addon._messageCallbacks = {}
    addon._eventCallbacks = {}

    function addon:RegisterChatCommand(cmd, handler) end

    function addon:RegisterMessage(eventName, callback)
        self._messageCallbacks[eventName] = callback
    end

    function addon:UnregisterMessage(eventName)
        self._messageCallbacks[eventName] = nil
    end

    function addon:SendMessage(eventName, ...)
        local cb = self._messageCallbacks[eventName]
        if cb then cb(eventName, ...) end
        -- Also dispatch to event callbacks so EH:Fire works for native events
        local ecb = self._eventCallbacks[eventName]
        if ecb and ecb ~= cb then ecb(eventName, ...) end
    end

    function addon:RegisterEvent(eventName, callback)
        self._eventCallbacks[eventName] = callback
    end

    function addon:UnregisterEvent(eventName)
        self._eventCallbacks[eventName] = nil
    end

    function addon:Print(msg)
        DEFAULT_CHAT_FRAME:AddMessage(msg)
    end

    return addon
end

local AceAddonLib = {
    NewAddon = function(self, name, ...)
        local a = makeAceAddon(name, ...)
        _libstub_libs["AceAddon:" .. name] = a
        return a
    end,
}

local AceLocaleLib = {
    GetLocale = function(self, name)
        -- Returns a table that returns the key itself for any locale lookup
        return setmetatable({}, { __index = function(_, k) return k end })
    end,
}

local AceDBLib = {
    New = function(self, svName, defaults)
        return { profile = { general = {} } }
    end,
}

_libstub_libs["AceAddon-3.0"]  = AceAddonLib
_libstub_libs["AceLocale-3.0"] = AceLocaleLib
_libstub_libs["AceDB-3.0"]     = AceDBLib
-- Stubs for other libs referenced by Init.lua slash commands
_libstub_libs["AceConfigDialog-3.0"] = { Open = function() end }

function LibStub(libName, optional)
    local lib = _libstub_libs[libName]
    if not lib and not optional then
        -- Unknown lib: return a harmless mock table so require-like calls succeed
        lib = setmetatable({}, {
            __index    = function(_, k) return function() end end,
            __newindex = function() end,
        })
    end
    return lib
end
_G.LibStub = LibStub

-- ============================================================
-- Additional mocks for E2E integration tests
-- ============================================================

-- bit library (Lua 5.1 may not have it)
if not _G.bit then
    _G.bit = {
        bxor   = function(a, b) return 0 end,
        bor    = function(a, b) return 0 end,
        band   = function(a, b) return 0 end,
        lshift = function(a, b) return 0 end,
        rshift = function(a, b) return 0 end,
    }
end

-- C_AssistedCombat namespace mock
if not _G.C_AssistedCombat then
    _G.C_AssistedCombat = {
        GetSpellRecommendation = function() return nil end,
        IsAvailable = function() return false end,
        GetRotationSpells = function() return {} end,
    }
end

-- C_UnitAuras namespace mock
if not _G.C_UnitAuras then
    _G.C_UnitAuras = {}
end
_G.C_UnitAuras.GetBuffDataByIndex = _G.C_UnitAuras.GetBuffDataByIndex or function() return nil end
_G.C_UnitAuras.GetAuraDataBySpellName = _G.C_UnitAuras.GetAuraDataBySpellName or function() return nil end

-- AuraUtil namespace mock
_G.AuraUtil = _G.AuraUtil or {}

-- GetCVar mock
_G.GetCVar = _G.GetCVar or function(name) return "0" end

-- C_CurveUtil mock (for DefensiveAdvisor)
_G.C_CurveUtil = _G.C_CurveUtil or {}
_G.C_CurveUtil.CreateColorCurve = _G.C_CurveUtil.CreateColorCurve or function()
    return { SetType = function() end, AddPoint = function() end }
end

-- CreateColor mock
_G.CreateColor = _G.CreateColor or function(r, g, b, a)
    return { GetRGBA = function() return r, g, b, a end }
end

-- Enum extensions
_G.Enum.LuaCurveType = _G.Enum.LuaCurveType or { Step = 1, Linear = 0 }

-- UnitClass mock
_G.UnitClass = _G.UnitClass or function() return "Unknown", "UNKNOWN", 1 end

-- GetSpecialization / GetSpecializationInfo mocks
_G.GetSpecialization = _G.GetSpecialization or function() return 1 end
_G.GetSpecializationInfo = _G.GetSpecializationInfo or function()
    return 577, "Havoc", "", 0, "DAMAGER"
end

-- date / time fallbacks
_G.time = _G.time or os.time
_G.date = _G.date or os.date

-- UnitHealthPercent mock (12.0 curve API)
_G.UnitHealthPercent = _G.UnitHealthPercent or function() return nil end

-- GetSpecialization for multi-spec mock support
_G.GetNumSpecializations = _G.GetNumSpecializations or function() return 2 end

-- ============================================================
-- hooksecurefunc mock (for CDMHook tests)
-- 模拟 Blizzard 安全钩子函数；测试中替换为简单包装。
-- ============================================================
_G.hooksecurefunc = _G.hooksecurefunc or function(arg1, arg2, arg3)
    -- Two-arg form: hooksecurefunc(name, post)
    -- Three-arg form: hooksecurefunc(table, name, post)
    if type(arg1) == "table" and type(arg2) == "string" and type(arg3) == "function" then
        local tbl, methodName, post = arg1, arg2, arg3
        local orig = tbl[methodName]
        tbl[methodName] = function(...)
            local r1, r2, r3 = nil, nil, nil
            if type(orig) == "function" then
                r1, r2, r3 = orig(...)
            end
            local ok, err = pcall(post, ...)
            if not ok then
                -- swallow; matches Blizzard taint-safe behavior in tests
            end
            return r1, r2, r3
        end
    end
end

-- NOTE: do NOT define _G.EssentialCooldownViewer here. The CDMHook
-- graceful-degradation tests rely on its absence; tests that need it
-- install a synthetic table locally and clean it up afterwards.
