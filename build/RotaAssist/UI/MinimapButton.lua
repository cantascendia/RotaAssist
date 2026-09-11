------------------------------------------------------------------------
-- RotaAssist - Minimap Button
-- LibDBIcon-based minimap toggle button.
-- Left-click: open config.  Right-click: toggle display.
------------------------------------------------------------------------

local _, NS = ...
local RA = NS.RA
local MinimapButton = {}
RA:RegisterModule("MinimapButton", MinimapButton)

------------------------------------------------------------------------
-- Internal State
------------------------------------------------------------------------

--- Whether we successfully registered with LibDBIcon
local registered = false

--- Data broker object (used by LibDBIcon)
local dataBroker = nil

------------------------------------------------------------------------
-- Module Lifecycle
------------------------------------------------------------------------

function MinimapButton:OnInitialize()
    -- Nothing to do until enable
end

function MinimapButton:OnEnable()
    -- Check for required libraries
    local LibStub = _G.LibStub
    if not LibStub then
        RA:PrintDebug("MinimapButton: LibStub not found — skipping minimap icon")
        return
    end

    local LDB = LibStub:GetLibrary("LibDataBroker-1.1", true)
    local LDBIcon = LibStub:GetLibrary("LibDBIcon-1.0", true)

    if not LDB or not LDBIcon then
        RA:PrintDebug("MinimapButton: LibDataBroker or LibDBIcon not found — skipping")
        return
    end

    -- Check setting
    if RA.db and RA.db.profile.general and RA.db.profile.general.minimapButton == false then
        return
    end

    -- Create data broker object
    -- RA.L 兜底为空表，避免 RA.L 尚未初始化时闭包内索引 nil
    -- Fall back to an empty table so the closures below never index a nil RA.L
    local L = RA.L or {}
    dataBroker = LDB:NewDataObject("RotaAssist", {
        type = "launcher",
        text = "RotaAssist",
        icon = "Interface\\Icons\\Ability_Mage_BrainFreeze",
        OnClick = function(_, button)
            if button == "LeftButton" then
                local configPanel = RA:GetModule("ConfigPanel")
                if configPanel and configPanel.Toggle then
                    configPanel:Toggle()
                end
            elseif button == "RightButton" then
                local mainDisplay = RA:GetModule("MainDisplay")
                if mainDisplay and mainDisplay.Toggle then
                    mainDisplay:Toggle()
                end
            end
        end,
        OnTooltipShow = function(tooltip)
            -- 与同文件首行保持一致的 `or` 兜底 / same `or` fallback style as the title line above
            tooltip:AddLine(L["MINIMAP_TOOLTIP_TITLE"] or "RotaAssist", 0, 0.8, 1)
            tooltip:AddLine(L["TOOLTIP_MINIMAP_LEFT"] or "Left-click: Open settings", 0.8, 0.8, 0.8)
            tooltip:AddLine(L["TOOLTIP_MINIMAP_RIGHT"] or "Right-click: Toggle display", 0.8, 0.8, 0.8)
        end,
    })

    -- Initialize saved minimap position data
    if RA.db then
        if not RA.db.profile.minimapIcon then
            RA.db.profile.minimapIcon = { hide = false }
        end
        LDBIcon:Register("RotaAssist", dataBroker, RA.db.profile.minimapIcon)
        registered = true
        RA:PrintDebug("MinimapButton registered with LibDBIcon")
    end
end

------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------

---Show or hide the minimap button.
---@param show boolean
function MinimapButton:SetShown(show)
    if not registered then return end

    local LDBIcon = _G.LibStub and _G.LibStub:GetLibrary("LibDBIcon-1.0", true)
    if not LDBIcon then return end

    if show then
        LDBIcon:Show("RotaAssist")
    else
        LDBIcon:Hide("RotaAssist")
    end

    if RA.db and RA.db.profile.minimapIcon then
        RA.db.profile.minimapIcon.hide = not show
    end
end

---Check whether the minimap button is registered.
---@return boolean
function MinimapButton:IsRegistered()
    return registered
end
