-- Strict offline startup smoke: load every active Lua entry in TOC order, then
-- exercise the addon lifecycle and fail on errors Core/Init would otherwise log.
-- 严格离线启动冒烟：按 TOC 顺序加载所有启用 Lua，并检查完整生命周期。

local helpers = require("tests.helpers")

describe("active TOC startup smoke", function()
    local function deepCopy(source)
        if type(source) ~= "table" then return source end
        local copy = {}
        for key, value in pairs(source) do copy[key] = deepCopy(value) end
        return copy
    end

    local function installLifecycleLibraryMocks()
        local originalLibStub = _G.LibStub
        local originalCreateFrame = _G.CreateFrame
        local locales = {}

        -- Engine teardown reparents secure probe frames. The shared mock omits
        -- SetParent because ordinary unit tests never need it; add it locally so
        -- this lifecycle smoke can exercise real OnDisable implementations.
        _G.CreateFrame = function(...)
            local frame = originalCreateFrame(...)
            function frame:SetParent(parent) self._parent = parent end
            return frame
        end

        local aceLocale = {}
        function aceLocale:NewLocale(addonName, locale, isDefault)
            if not isDefault then return nil end
            locales[addonName] = locales[addonName] or {}
            return locales[addonName]
        end
        function aceLocale:GetLocale(addonName)
            return locales[addonName]
                or setmetatable({}, { __index = function(_, key) return key end })
        end

        local aceDB = {}
        function aceDB:New(_, defaults)
            local db = deepCopy(defaults)
            function db:RegisterCallback() end
            function db:ResetProfile()
                self.profile = deepCopy(defaults.profile)
            end
            return db
        end

        local aceConfig = { RegisterOptionsTable = function() end }
        local aceConfigDialog = {
            AddToBlizOptions = function() return CreateFrame("Frame") end,
            Open = function() end,
            Close = function() end,
        }

        local function resolveLibrary(name, optional)
            if name == "AceLocale-3.0" then return aceLocale end
            if name == "AceDB-3.0" then return aceDB end
            if name == "AceConfig-3.0" then return aceConfig end
            if name == "AceConfigDialog-3.0" then return aceConfigDialog end
            return originalLibStub(name, optional)
        end

        local libStubProxy = {}
        function libStubProxy:GetLibrary(name, optional)
            return resolveLibrary(name, optional)
        end
        setmetatable(libStubProxy, {
            __call = function(_, name, optional)
                return resolveLibrary(name, optional)
            end,
        })
        _G.LibStub = libStubProxy
    end

    it("loads, initializes, enables, and disables every active Lua module", function()
        helpers.ensureMockLoaded()
        installLifecycleLibraryMocks()

        local ns = {}
        local loaded = {}
        for rawLine in io.lines("addon/RotaAssist.toc") do
            local line = rawLine:match("^%s*(.-)%s*$")
            if line ~= "" and line:sub(1, 1) ~= "#"
               and line:lower():match("%.lua$") then
                local path = "addon/" .. line:gsub("\\", "/")
                local ok, err = helpers.loadAddonFile(path, "RotaAssist", ns)
                if not ok then
                    error(string.format("TOC load failed for %s: %s", path, tostring(err)))
                end
                loaded[#loaded + 1] = path
            end
        end

        assert.is_true(#loaded > 20)
        local RA = ns.RA
        assert.is_not_nil(RA)

        local lifecycleErrors = {}
        RA.PrintError = function(_, message)
            lifecycleErrors[#lifecycleErrors + 1] = tostring(message)
        end

        RA:OnInitialize()
        RA:OnEnable()

        for name, module in pairs(RA.modules) do
            if module.OnInitialize then
                assert.is_nil(module._initializationFailed,
                    name .. " initialization failed: " .. tostring(module._initializationFailed))
            end
            if module.OnEnable then
                assert.is_nil(module._enableFailed,
                    name .. " enable failed: " .. tostring(module._enableFailed))
            end
        end
        assert.equals(0, #lifecycleErrors,
            lifecycleErrors[1] or "unexpected lifecycle error")
        assert.has_no.errors(function() RA:OnDisable() end)
    end)
end)
