------------------------------------------------------------------------
-- RotaAssist - CooldownBar Widget
-- Horizontal bar containing multiple IconWidgets for major cooldown tracking.
------------------------------------------------------------------------

local _, NS = ...
local RA = NS.RA

RA.UI = RA.UI or {}
RA.UI.CooldownBar = {}
local CooldownBar = RA.UI.CooldownBar
CooldownBar.__index = CooldownBar

---Create a new CooldownBar.
---@param parent table
---@param maxIcons number (e.g. 5)
---@return table widget
function CooldownBar:Create(parent, maxIcons)
    local obj = setmetatable({}, self)
    
    obj.frame = CreateFrame("Frame", nil, parent)
    -- Initial placeholder size
    obj.frame:SetSize(1, 28)
    
    obj.maxIcons = maxIcons or 5
    obj.iconSize = 28
    obj.spacing = 4
    
    obj.icons = {}
    for i = 1, obj.maxIcons do
        local icon = RA.UI.IconWidget:Create(obj.frame, obj.iconSize)
        if i == 1 then
            icon.frame:SetPoint("LEFT", obj.frame, "LEFT", 0, 0)
        else
            icon.frame:SetPoint("LEFT", obj.icons[i-1].frame, "RIGHT", obj.spacing, 0)
        end
        icon.frame:Hide()
        obj.icons[i] = icon
    end
    
    return obj
end

---Update the cooldowns shown in the bar.
---Entries originate from CooldownOverlay:GetCooldownStates() and reach this
---widget via SmartQueueManager's finalQueue.cooldowns array.
---数据源为 CooldownOverlay:GetCooldownStates()，经 SmartQueueManager 的
---finalQueue.cooldowns 数组传入本控件。
---@param cooldownStates table[] Array of { spellID, texture, ready, remaining, startTime, duration }
function CooldownBar:Update(cooldownStates)
    if not cooldownStates or #cooldownStates == 0 then
        for i = 1, self.maxIcons do self.icons[i].frame:Hide() end
        self.frame:SetWidth(1)
        return
    end
    
    local numVisible = 0
    
    for i = 1, self.maxIcons do
        local icon = self.icons[i]
        local state = cooldownStates[i]
        
        if state then
            icon:SetSpell(state.spellID, state.texture)
            
            if state.ready then
                icon:SetCooldown(nil, nil)
                icon:SetDesaturated(false)
                icon:SetAlert(false)
                -- 就绪时显示"就绪"标记表示大招可用（走 i18n，不再硬编码 "OK"）
                -- Show a localized ready badge when the cooldown is available.
                -- FIX (Bug4): 写入独立的 CD 计时文本，不再占用 keybind 字段
                -- FIX (Bug4): write to the dedicated CD timer text instead of the keybind field.
                icon:SetCooldownTimer(RA.L and RA.L["CD_READY_SHORT"] or "OK")
            else
                icon:SetDesaturated(true)

                -- FIX (Bug3): 用 CooldownOverlay 提供的真实 startTime/duration 驱动转圈。
                -- 旧代码的回退分支算的是 `GetTime() - (approxDur - state.remaining)`，
                -- 而 approxDur 就等于 state.remaining，括号内恒为 0 → start 永远是"此刻"，
                -- 转圈每帧都从满圈重新开始，完全不反映真实进度。
                -- FIX (Bug3): drive the sweep with the real startTime/duration supplied by
                -- CooldownOverlay:GetCooldownStates(). The old fallback computed
                -- `approxDur - state.remaining`, which is always 0 because approxDur *is*
                -- state.remaining, so the sweep restarted from full on every frame.
                if state.startTime and state.duration
                   and state.startTime > 0 and state.duration > 1.5 then
                    icon:SetCooldown(state.startTime, state.duration)
                else
                    -- 只有 remaining 而无 startTime/duration（CooldownOverlay 的 secret value
                    -- 估算路径不写这两个字段）时，无法还原真实进度。宁可不画转圈，也不要画一个
                    -- 恒定错误的转圈；剩余时间仍由下方的计时文本传达。
                    -- Without a real start/duration (CooldownOverlay's secret-value estimation
                    -- path leaves both fields untouched) progress cannot be reconstructed.
                    -- Clear the sweep rather than render a permanently wrong one — the
                    -- remaining time is still conveyed by the timer text below.
                    icon:SetCooldown(nil, nil)
                end

                -- 显示冷却剩余秒数文字
                -- Display remaining cooldown time text
                local remaining = state.remaining or 0
                if remaining > 0 then
                    if remaining >= 60 then
                        local minutesFmt = RA.L and RA.L["CD_MINUTES_SHORT"] or "%dm"
                        icon:SetCooldownTimer(string.format(minutesFmt, math.floor(remaining / 60)))
                    else
                        icon:SetCooldownTimer(string.format("%d", math.ceil(remaining)))
                    end
                else
                    icon:SetCooldownTimer("")
                end

                if state.remaining > 0 and state.remaining <= 5 then
                    icon:SetAlert(true)
                else
                    icon:SetAlert(false)
                end
            end
            
            icon.frame:Show()
            numVisible = numVisible + 1
        else
            icon.frame:Hide()
        end
    end
    
    -- Center align by setting dynamic width
    if numVisible > 0 then
        local totalWidth = (numVisible * self.iconSize) + ((numVisible - 1) * self.spacing)
        self.frame:SetWidth(totalWidth)
    else
        self.frame:SetWidth(1)
    end
end
