-- test: new coverage (Test-Lock scenario 3), current native buttons, not guessed slots.
local helpers = require("tests.helpers")
describe("native keybind resolver", function()
    local RA, ns, resolver, reads, secret, bindings, actions, slot
    before_each(function()
        RA, ns = helpers.loadAddon()
        secret = {}; issecretvalue = function(v) return rawequal(v, secret) end
        reads, bindings, actions, slot = 0, {}, {}, 1
        for _, prefix in ipairs({"ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
            "MultiBarRightButton", "MultiBarLeftButton", "MultiBar5Button", "MultiBar6Button", "MultiBar7Button"}) do
            for i = 1, 12 do _G[prefix .. i] = nil end
        end
        OverrideActionBar = nil
        GetActionInfo = function(n) reads = reads + 1; local a = actions[n]; if a then return unpack(a) end end
        GetBindingKey = function(command) return bindings[command] end
        GetBindingText = nil
        RA.ResolveSpellOverride = function(_, id) return id == 198013 and 452497 or id end
        ActionButton1 = { action = 1, bindingAction = "ACTIONBUTTON1", CalculateAction = function() return slot end }
        bindings.ACTIONBUTTON1 = "SHIFT-F"
        helpers.loadAddonFile("addon/UI/KeybindResolver.lua", "RotaAssist", ns)
        resolver = RA.UI.KeybindResolver
    end)
    it("follows the active page instead of stale action or slot arithmetic", function()
        slot = 73; actions[73] = {"spell", 100}; actions[1] = {"spell", 200}
        assert.equals("S-F", resolver:Get(100)); assert.is_nil(resolver:Get(200))
    end)
    it("uses the actual extra-bar command including slots 145 through 180", function()
        MultiBar7Button12 = { action = 180, bindingAction = "MULTIACTIONBAR7BUTTON12" }
        actions[180] = {"spell", 100}; bindings.MULTIACTIONBAR7BUTTON12 = "CTRL-9"
        assert.equals("C-9", resolver:Get(100))
    end)
    it("matches the current override but never guesses a conditional macro", function()
        actions[1] = {"spell", 198013}; assert.equals("S-F", resolver:Get(452497))
        actions[1] = {"macro", 198013}; resolver:Invalidate(); assert.is_nil(resolver:Get(452497))
    end)
    it("supports click bindings and native localized binding labels", function()
        actions[1] = {"spell", 100}; bindings.ACTIONBUTTON1 = nil
        bindings["CLICK ActionButton1:LeftButton"] = "PAD1"
        GetBindingText = function(key) return key == "PAD1" and "A" end
        assert.equals("A", resolver:Get(100))
    end)
    it("caches both positive and negative results until invalidated", function()
        actions[1] = {"spell", 100}; assert.equals("S-F", resolver:Get(100))
        local n = reads; resolver:Get(100); assert.equals(n, reads)
        resolver:Get(200); n = reads; resolver:Get(200); assert.equals(n, reads)
        actions[1] = {"spell", 200}; resolver:Invalidate(); assert.equals("S-F", resolver:Get(200))
        assert.is_nil(resolver:Get(100))
    end)
    it("rejects secret or failing API results before inspecting them", function()
        actions[1] = {"spell", secret}; assert.is_nil(resolver:Get(100))
        actions[1] = {secret, 100}; resolver:Invalidate(); assert.is_nil(resolver:Get(100))
        actions[1] = {"spell", 100}; bindings.ACTIONBUTTON1 = secret
        resolver:Invalidate(); assert.is_nil(resolver:Get(100))
        GetActionInfo = function() error("restricted") end
        resolver:Invalidate(); assert.is_nil(resolver:Get(100)); assert.is_nil(resolver:Get(secret))
    end)
    it("does not reuse a stale action after CalculateAction fails", function()
        actions[1] = {"spell", 100}; ActionButton1.CalculateAction = function() error("restricted") end
        assert.is_nil(resolver:Get(100))
    end)
    it("suppresses standard bindings while an override bar owns them", function()
        actions[1] = {"spell", 100}; OverrideActionBar = { IsShown = function() return true end }
        assert.is_nil(resolver:Get(100))
    end)
    it("property: page changes always remove the previous spell binding", function()
        for page = 1, 15 do
            slot = (page - 1) * 12 + 1; actions[slot] = {"spell", 1000 + page}
            resolver:Invalidate(); assert.equals("S-F", resolver:Get(1000 + page))
            for previous = 1, page - 1 do assert.is_nil(resolver:Get(1000 + previous)) end
        end
    end)
end)
