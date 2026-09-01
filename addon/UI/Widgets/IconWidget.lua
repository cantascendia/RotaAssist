------------------------------------------------------------------------
-- RotaAssist - Icon Widget
-- Encapsulates a single spell icon with cooldown, keybind, confidence,
-- and alert/glow overlay capabilities.
------------------------------------------------------------------------

local _, NS = ...
local RA = NS.RA

RA.UI = RA.UI or {}
RA.UI.IconWidget = {}
local IconWidget = RA.UI.IconWidget
IconWidget.__index = IconWidget

---Create a new Icon Widget.
---@param parent table   Parent frame
---@param size number    Width and height
---@param name string    Global name for the underlying frame (can be nil)
---@return table widget
function IconWidget:Create(parent, size, name)
    local obj = setmetatable({}, self)
    
    -- Base frame (Button so it can intercept clicks if needed, but not ActionButton)
    obj.frame = CreateFrame("Button", name, parent, "BackdropTemplate")
    obj.frame:SetSize(size, size)
    
    -- Icon Texture
    obj.icon = obj.frame:CreateTexture(nil, "ARTWORK")
    obj.icon:SetAllPoints(obj.frame)
    obj.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- Zoom in slightly to remove default borders
    obj.icon:SetTexture(134400) -- Question mark fallback
    
    -- Cooldown Frame
    obj.cooldown = CreateFrame("Cooldown", nil, obj.frame, "CooldownFrameTemplate")
    obj.cooldown:SetAllPoints(obj.frame)
    obj.cooldown:SetDrawEdge(false)
    
    -- Keybind Text (Bottom Right)
    obj.keybind = obj.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    obj.keybind:SetPoint("TOPRIGHT", obj.frame, "TOPRIGHT", -1, -1)
    obj.keybind:SetJustifyH("RIGHT")
    local fontSize = math.max(10, math.floor(size * 0.25))
    obj.keybind:SetFont(STANDARD_TEXT_FONT, fontSize, "OUTLINE")
    
    -- Confidence Text (Top Left)
    obj.confidence = obj.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    obj.confidence:SetPoint("BOTTOMLEFT", obj.frame, "BOTTOMLEFT", 2, 2)
    obj.confidence:SetJustifyH("LEFT")
    obj.confidence:SetFont(STANDARD_TEXT_FONT, math.max(10, math.floor(size * 0.22)), "OUTLINE")
    obj.confidence:SetTextColor(1, 0.8, 0) -- Gold

    -- Cooldown Timer Text (Bottom center)
    -- FIX (Bug4): 独立于 keybind 的 CD 计时文本。此前 CooldownBar 复用 keybind 字段写
    -- 剩余秒数，导致 CD 图标上永远无法同时显示按键和剩余时间。
    -- FIX (Bug4): dedicated cooldown-timer FontString. CooldownBar used to overwrite the
    -- keybind FontString with the remaining time, so an icon could never show both.
    -- 注意：与 confidence（BOTTOMLEFT）同处底部，但两者从不作用于同一个 widget
    -- Note: shares the bottom edge with `confidence` (BOTTOMLEFT), but no widget uses both.
    obj.cdTimer = obj.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    obj.cdTimer:SetPoint("BOTTOM", obj.frame, "BOTTOM", 0, 2)
    obj.cdTimer:SetJustifyH("CENTER")
    obj.cdTimer:SetFont(STANDARD_TEXT_FONT, fontSize, "OUTLINE")
    
    -- Alert Frame (Red pulsating border)
    obj.alertFrame = CreateFrame("Frame", nil, obj.frame, "BackdropTemplate")
    obj.alertFrame:SetAllPoints(obj.frame)
    obj.alertFrame:SetFrameLevel(obj.frame:GetFrameLevel() + 2)
    obj.alertFrame:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12 })
    obj.alertFrame:SetBackdropBorderColor(1, 0.1, 0.1, 1)
    obj.alertFrame:Hide()
    
    obj.alertAnim = obj.alertFrame:CreateAnimationGroup()
    obj.alertAnim:SetLooping("REPEAT")
    local a1 = obj.alertAnim:CreateAnimation("Alpha")
    a1:SetFromAlpha(0.3)
    a1:SetToAlpha(1.0)
    a1:SetDuration(0.5)
    a1:SetOrder(1)
    local a2 = obj.alertAnim:CreateAnimation("Alpha")
    a2:SetFromAlpha(1.0)
    a2:SetToAlpha(0.3)
    a2:SetDuration(0.5)
    a2:SetOrder(2)
    
    obj.currentSpellID = nil
    obj.fadeTimer = nil

    return obj
end

---Set the spell to display. Triggers crossfade if changed.
---@param spellID number
---@param texture number|nil
function IconWidget:SetSpell(spellID, texture)
    if self.currentSpellID == spellID then return end
    self.currentSpellID = spellID

    if not texture then
        local ok, info = pcall(C_Spell.GetSpellTexture, spellID)
        texture = (ok and info) and info or 134400
    end

    -- Crossfade / 交叉淡入淡出
    -- FIX (Bug5): 改用可取消的 C_Timer.NewTimer，并在新建前取消上一个。
    -- 旧代码用 C_Timer.After 且从不取消：快速连续换技能时旧回调仍会触发，
    -- 可能"后发先至"写入过期纹理；且每次调用都泄漏一个闭包 + 定时器。
    -- FIX (Bug5): use a cancellable NewTimer and cancel the pending one first.
    -- C_Timer.After callbacks could not be cancelled, so a stale callback could land
    -- after a newer one and apply the wrong texture; it also allocated a fresh closure
    -- and timer on every recommendation update.
    -- 同 DefensiveAlert:Dismiss() 的写法 / mirrors the pattern in DefensiveAlert:Dismiss().
    if self.fadeTimer then
        self.fadeTimer:Cancel()
        self.fadeTimer = nil
    end
    UIFrameFadeOut(self.frame, 0.1)
    self.fadeTimer = C_Timer.NewTimer(0.1, function()
        self.fadeTimer = nil
        self.icon:SetTexture(texture)
        UIFrameFadeIn(self.frame, 0.1)
    end)
end

---Update the cooldown sweep.
---@param start number|nil
---@param duration number|nil
function IconWidget:SetCooldown(start, duration)
    if start and duration and duration > 1.5 then
        self.cooldown:SetCooldown(start, duration)
    else
        self.cooldown:Clear()
    end
end

---Set confidence stars (★★★, ★★☆, ★☆☆) or clear.
---FIX (Bug2): 统一为 0–1 浮点语义。旧实现按整数 1/2/3 分档，但所有调用方传的都是
---0–1 浮点（数据源 predData.confidence 本就是 0–1），导致语义完全倒置：
---置信度 1.0（最高）落到 else 渲染 ★☆☆（最低星），0.9 则被当作 "< 1" 直接清空。
---FIX (Bug2): unified on 0–1 float semantics. The old integer 1/2/3 branches inverted the
---meaning for every caller: confidence 1.0 (highest) fell through to ★☆☆ (lowest), and
---0.9 was treated as "< 1" and cleared the text entirely.
---@param confidence number|nil  0.0–1.0; nil or <= 0 clears the stars
function IconWidget:SetConfidence(confidence)
    if not confidence or confidence <= 0 then
        self.confidence:SetText("")
    elseif confidence >= 0.8 then
        self.confidence:SetText("★★★")
    elseif confidence >= 0.5 then
        self.confidence:SetText("★★☆")
    else
        self.confidence:SetText("★☆☆")
    end
end

---Set the keybind text (top-right corner).
---设置按键绑定文本（右上角）。
---@param text string|nil
function IconWidget:SetKeybind(text)
    if text and text ~= "" then
        self.keybind:SetText(text)
    else
        self.keybind:SetText("")
    end
end

---Set the cooldown timer text (bottom centre).
---设置冷却计时文本（底部居中）。与 SetKeybind 相互独立，两者可同时显示。
---Independent from SetKeybind so keybind and remaining cooldown can coexist.
---@param text string|nil
function IconWidget:SetCooldownTimer(text)
    if text and text ~= "" then
        self.cdTimer:SetText(text)
    else
        self.cdTimer:SetText("")
    end
end

---Toggle the primary recommendation glow.
---@param enabled boolean
function IconWidget:SetGlow(enabled)
    local ActionButton_ShowOverlayGlow = _G.ActionButton_ShowOverlayGlow
    local ActionButton_HideOverlayGlow = _G.ActionButton_HideOverlayGlow
    
    if enabled then
        if ActionButton_ShowOverlayGlow then
            ActionButton_ShowOverlayGlow(self.frame)
        else
            RA.UI.GlowWidget:Start(self.frame)
        end
    else
        if ActionButton_HideOverlayGlow then
            ActionButton_HideOverlayGlow(self.frame)
        end
        RA.UI.GlowWidget:Stop(self.frame)
    end
end

---Toggle the red alert pulse (for defensives / approaching CDs).
---@param enabled boolean
function IconWidget:SetAlert(enabled)
    if enabled then
        self.alertFrame:Show()
        if not self.alertAnim:IsPlaying() then self.alertAnim:Play() end
    else
        self.alertAnim:Stop()
        self.alertFrame:Hide()
    end
end

---Apply desaturation (greyscale) to the icon.
---@param desaturated boolean
function IconWidget:SetDesaturated(desaturated)
    self.icon:SetDesaturated(desaturated)
end

---Clear the widget.
function IconWidget:Clear()
    -- FIX (Bug5): 取消未决的交叉淡入定时器，否则它会在 Clear() 之后把旧纹理写回来。
    -- FIX (Bug5): cancel any pending crossfade timer, which would otherwise restore the
    -- previous texture right after this Clear().
    if self.fadeTimer then
        self.fadeTimer:Cancel()
        self.fadeTimer = nil
    end
    self.currentSpellID = nil
    self.icon:SetTexture(134400)
    self.cooldown:Clear()
    self:SetKeybind("")
    self:SetCooldownTimer("")
    self:SetConfidence(nil)
    self:SetGlow(false)
    self:SetAlert(false)
    self:SetDesaturated(false)
end
