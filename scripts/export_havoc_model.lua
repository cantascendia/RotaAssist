-- Export the Havoc model actually loaded by the addon in the offline WoW mock.
-- 从离线 WoW mock 实际加载的数据导出浩劫模型；不重写规则或优先级。
-- Usage: lua scripts/export_havoc_model.lua [output.json] [--addon-root PATH]
package.path = "./?.lua;./?/init.lua;" .. package.path

local helpers = require("tests.helpers")
local outputPath, addonRoot = nil, "addon"
local argument = 1
while arg and argument <= #arg do
    if arg[argument] == "--addon-root" then
        addonRoot = assert(arg[argument + 1], "--addon-root needs a path")
        argument = argument + 2
    else
        assert(not outputPath, "only one output path is supported")
        outputPath = arg[argument]
        argument = argument + 1
    end
end
local function loadAddonFile(relative, ns)
    local path = addonRoot .. "/" .. relative
    local chunk, err = loadfile(path)
    assert(chunk, path .. ": " .. tostring(err))
    local ok, runtimeError = pcall(chunk, "RotaAssist", ns)
    assert(ok, path .. ": " .. tostring(runtimeError))
end
helpers.ensureMockLoaded()
local ns = {}
loadAddonFile("Core/Init.lua", ns)
local RA = assert(ns.RA)
loadAddonFile("Data/Registry.lua", ns)

local sources = {
    "Data/WhitelistSpells.lua",
    "Data/SpecEnhancements/DemonHunter.lua",
    "Data/APL/DemonHunter_Havoc.lua",
    "Engine/APLEngine.lua",
}
for _, path in ipairs(sources) do
    loadAddonFile(path, ns)
end

local engine = assert(RA:GetModule("APLEngine"), "APLEngine not loaded")
local havoc = assert(RA.APLData and RA.APLData[577], "Havoc APL not loaded")
engine:SetAPL(577, havoc, 12)
local loaded = assert(engine:GetCurrentAPL(), "APLEngine did not retain Havoc APL")
assert(loaded.profiles and loaded.profiles.default and loaded.profiles.fel_scarred,
    "Havoc default/fel_scarred profiles missing")

local function encodeString(value)
    local escaped = value:gsub('[%z\1-\31\\"]', function(character)
        local byte = string.byte(character)
        if character == '"' then return '\\"' end
        if character == '\\' then return '\\\\' end
        if character == '\n' then return '\\n' end
        if character == '\r' then return '\\r' end
        if character == '\t' then return '\\t' end
        return string.format('\\u%04x', byte)
    end)
    return '"' .. escaped .. '"'
end

local function isArray(value)
    local count, maximum = 0, 0
    for key in pairs(value) do
        if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then return false end
        count = count + 1
        if key > maximum then maximum = key end
    end
    return count > 0 and count == maximum
end

local function encode(value, stack)
    local kind = type(value)
    if kind == "nil" then return "null" end
    if kind == "boolean" then return value and "true" or "false" end
    if kind == "number" then
        assert(value == value and value ~= math.huge and value ~= -math.huge,
            "non-finite model number")
        return string.format("%.17g", value)
    end
    if kind == "string" then return encodeString(value) end
    assert(kind == "table", "unsupported model field type: " .. kind)
    assert(not stack[value], "cyclic model table")
    stack[value] = true
    local parts = {}
    if isArray(value) then
        for index = 1, #value do
            parts[#parts + 1] = encode(value[index], stack)
        end
        stack[value] = nil
        return "[" .. table.concat(parts, ",") .. "]"
    end
    local keys = {}
    for key in pairs(value) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for _, key in ipairs(keys) do
        parts[#parts + 1] = encodeString(tostring(key)) .. ":" .. encode(value[key], stack)
    end
    stack[value] = nil
    return "{" .. table.concat(parts, ",") .. "}"
end

local model = {
    schema = "rotaassist.havoc.loaded-model.v1",
    verification = "offline-mock-load; not a WoW-client validation",
    addonRoot = addonRoot,
    sources = sources,
    specID = 577,
    classID = 12,
    apl = loaded,
    whitelist = RA.WhitelistSpells,
    specEnhancements = RA.SpecEnhancements and RA.SpecEnhancements[577],
    overridePairs = RA.KNOWN_OVERRIDE_PAIRS,
    unknownSpells = engine.unknownSpells,
    invalidRules = engine.invalidRules,
}

local json = encode(model, {}) .. "\n"
if outputPath then
    local file = assert(io.open(outputPath, "wb"))
    assert(file:write(json))
    assert(file:close())
    io.stderr:write("Exported loaded Havoc model to " .. outputPath .. "\n")
else
    io.write(json)
end
