------------------------------------------------------------------------
-- Read-only native button bindings / 只读原生按钮绑定。
-- Never infer a binding from a numeric slot or conditional macro.
-- 不从槽位编号猜按键，也不推测条件宏的当前技能。
------------------------------------------------------------------------
local _, NS = ...
local RA = NS.RA
RA.UI = RA.UI or {}
local Resolver = {}
RA.UI.KeybindResolver = Resolver
local cache, buttons = {}, {}
for _, prefix in ipairs({"ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
    "MultiBarRightButton", "MultiBarLeftButton", "MultiBar5Button", "MultiBar6Button", "MultiBar7Button"}) do
    for i = 1, 12 do buttons[#buttons + 1] = { name = prefix .. i, main = prefix == "ActionButton" } end
end

local function public(v)
    return not (issecretvalue and issecretvalue(v))
end
local function validID(v)
    return public(v) and type(v) == "number" and v > 0 and v < math.huge and v == math.floor(v)
end
local function publicString(v)
    return public(v) and type(v) == "string" and v ~= ""
end
local function resolve(id)
    if not validID(id) then return nil end
    if RA.ResolveSpellOverride then
        local ok, current = pcall(RA.ResolveSpellOverride, RA, id)
        if not ok or not validID(current) then return nil end
        return current
    end
    return id
end
local function keyFor(command)
    if not publicString(command) or not GetBindingKey then return nil end
    local ok, key = pcall(GetBindingKey, command)
    if ok and publicString(key) then return key end
end
local function label(key)
    if GetBindingText then
        local ok, text = pcall(GetBindingText, key, 1)
        if ok and publicString(text) then return text end
    end
    return (key:gsub("SHIFT%-", "S-"):gsub("CTRL%-", "C-"):gsub("ALT%-", "A-"):gsub("NUMPAD", "N"))
end

function Resolver:Invalidate()
    wipe(cache)
end

function Resolver:Get(spellID)
    if not validID(spellID) then return nil end
    if cache[spellID] ~= nil then return cache[spellID] or nil end
    local wanted = resolve(spellID)
    if not wanted or not GetActionInfo then return nil end
    local suppressMain = false
    if OverrideActionBar and OverrideActionBar.IsShown then
        local ok, shown = pcall(OverrideActionBar.IsShown, OverrideActionBar)
        -- An unreadable override state is not evidence that normal keys work.
        -- 无法读取覆盖状态时，不宣称主动作栏绑定仍有效。
        suppressMain = not ok or not public(shown) or shown ~= false
    end
    for i = 1, #buttons do
        local descriptor = buttons[i]
        local button = _G[descriptor.name]
        if button and not (descriptor.main and suppressMain) then
            local slot
            if type(button.CalculateAction) == "function" then
                local ok, current = pcall(button.CalculateAction, button)
                if ok and validID(current) then slot = current end
            elseif validID(button.action) then
                slot = button.action
            end
            if slot then
                local ok, kind, id = pcall(GetActionInfo, slot)
                if ok and public(kind) and kind == "spell" and validID(id) and resolve(id) == wanted then
                    local key = keyFor(button.bindingAction) or keyFor("CLICK " .. descriptor.name .. ":LeftButton")
                    if key then
                        cache[spellID] = label(key)
                        return cache[spellID]
                    end
                end
            end
        end
    end
    cache[spellID] = false
    return nil
end
