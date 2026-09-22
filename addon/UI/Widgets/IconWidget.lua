------------------------------------------------------------------------
-- RotaAssist - Icon Widget
-- Encapsulates a single spell icon with cooldown, keybind, confidence,
-- out-of-range and alert/glow overlay capabilities.
-- 单个技能图标：冷却 / 按键 / 置信度 / 超距 / 警报与高亮。
------------------------------------------------------------------------

local _, NS = ...
local RA = NS.RA

-- Design tokens (D-016). The .toc loads UI\Theme.lua before every widget.
-- 设计令牌（D-016）。.toc 保证 UI\Theme.lua 先于所有 widget 加载。
local Theme = RA.Theme

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
    -- This is a hint, not a cast button. Let the strip receive drag/right-click.
    -- 图标是提示，不是施法按钮；拖动和右键由主条接收。
    obj.frame:EnableMouse(false)

    -- Icon Texture
    obj.icon = obj.frame:CreateTexture(nil, "ARTWORK")
    obj.icon:SetAllPoints(obj.frame)
    obj.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- Zoom in slightly to remove default borders
    obj.icon:SetTexture(Theme.FALLBACK_ICON)     -- Question mark fallback / 问号占位

    -- Cooldown Frame
    obj.cooldown = CreateFrame("Cooldown", nil, obj.frame, "CooldownFrameTemplate")
    obj.cooldown:SetAllPoints(obj.frame)
    obj.cooldown:SetDrawEdge(false)

    -- Keybind Text (Top Right)
    obj.keybind = obj.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    obj.keybind:SetPoint("TOPRIGHT", obj.frame, "TOPRIGHT", -1, -1)
    obj.keybind:SetJustifyH("RIGHT")
    obj.keybind:SetWidth(size - 4)
    obj.keybind:SetWordWrap(false)
    local fontSize = Theme.ScaledFontSize(size, 0.25)
    obj.keybindFontSize = fontSize
    Theme.ApplyFont(obj.keybind, fontSize)

    -- Confidence Text (Bottom Left)
    obj.confidence = obj.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    obj.confidence:SetPoint("BOTTOMLEFT", obj.frame, "BOTTOMLEFT", 2, 2)
    obj.confidence:SetJustifyH("LEFT")
    obj.confidence:SetWidth(size - 4)
    obj.confidence:SetWordWrap(false)
    Theme.ApplyFont(obj.confidence, Theme.ScaledFontSize(size, 0.22))
    Theme.SetTextColor(obj.confidence, "confidence")

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
    Theme.ApplyFont(obj.cdTimer, fontSize)

    -- Text plus colour: range is readable without distinguishing red.
    -- 超距同时使用文字与颜色，避免只依赖辨色。
    obj.rangeText = obj.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    obj.rangeText:SetPoint("CENTER", obj.frame, "CENTER", 0, 0)
    obj.rangeText:SetWidth(size - 4)
    obj.rangeText:SetWordWrap(false)
    Theme.ApplyFont(obj.rangeText, Theme.fonts.sizes.small)
    Theme.SetTextColor(obj.rangeText, "text")

    obj.focusFrame = CreateFrame("Frame", nil, obj.frame, "BackdropTemplate")
    obj.focusFrame:SetAllPoints(obj.frame)
    Theme.ApplyBackdrop(obj.focusFrame, "outline", nil, "gold")
    obj.focusFrame:Hide()

    -- Alert Frame (Red pulsating border) / 红色脉冲边框
    obj.alertFrame = CreateFrame("Frame", nil, obj.frame, "BackdropTemplate")
    obj.alertFrame:SetAllPoints(obj.frame)
    obj.alertFrame:SetFrameLevel(obj.frame:GetFrameLevel() + 2)
    Theme.ApplyBackdrop(obj.alertFrame, "outline", nil, "alert")
    obj.alertFrame:Hide()

    obj.alertAnim = obj.alertFrame:CreateAnimationGroup()
    obj.alertAnim:SetLooping("REPEAT")
    local a1 = obj.alertAnim:CreateAnimation("Alpha")
    a1:SetFromAlpha(0.3)
    a1:SetToAlpha(1.0)
    a1:SetDuration(Theme.durations.pulse)
    a1:SetOrder(1)
    local a2 = obj.alertAnim:CreateAnimation("Alpha")
    a2:SetFromAlpha(1.0)
    a2:SetToAlpha(0.3)
    a2:SetDuration(Theme.durations.pulse)
    a2:SetOrder(2)

    -- Out-of-Range pulse (from round15) / 超距脉冲（来自 round15）
    -- Red tint + a slow alpha throb so the player sees "you cannot cast this yet".
    -- 红色着色 + 缓慢的透明度呼吸，提示"当前距离打不到"。
    obj.oorAnim = obj.frame:CreateAnimationGroup()
    obj.oorAnim:SetLooping("REPEAT")
    local o1 = obj.oorAnim:CreateAnimation("Alpha")
    o1:SetFromAlpha(0.4)
    o1:SetToAlpha(0.8)
    o1:SetDuration(Theme.durations.pulse)
    o1:SetOrder(1)
    local o2 = obj.oorAnim:CreateAnimation("Alpha")
    o2:SetFromAlpha(0.8)
    o2:SetToAlpha(0.4)
    o2:SetDuration(Theme.durations.pulse)
    o2:SetOrder(2)

    obj.currentSpellID = nil
    obj.fadeTimer = nil
    obj.outOfRange = false

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
        texture = (ok and info) and info or Theme.FALLBACK_ICON
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
    if UIFrameFadeRemoveFrame then
        UIFrameFadeRemoveFrame(self.frame)
    end
    self.currentTexture = texture
    if self.reducedMotion then
        self.icon:SetTexture(texture)
        self.frame:SetAlpha(1.0)
        return
    end
    local crossfade = Theme.durations.crossfade
    UIFrameFadeOut(self.frame, crossfade)
    self.fadeTimer = C_Timer.NewTimer(crossfade, function()
        self.fadeTimer = nil
        self.icon:SetTexture(texture)
        UIFrameFadeIn(self.frame, crossfade)
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
    if self.currentKeybind == text then return end
    self.currentKeybind = text
    if text and text ~= "" then
        self.keybind:SetText(text)
        Theme.ApplyFont(self.keybind, self.keybindFontSize)
        -- Do not show a truncated modifier combination as a different key.
        -- 组合键不能截断成另一个按键；允许缩到主题最小字号，仍不够则留空。
        if self.keybind.GetStringWidth then
            local ok, width = pcall(self.keybind.GetStringWidth, self.keybind)
            if ok and not issecretvalue(width) and type(width) == "number" and width > self.keybind:GetWidth() then
                Theme.ApplyFont(self.keybind, Theme.fonts.sizes.small)
                local fits, smaller = pcall(self.keybind.GetStringWidth, self.keybind)
                if not fits or issecretvalue(smaller) or type(smaller) ~= "number" or smaller > self.keybind:GetWidth() then
                    self.keybind:SetText("")
                end
            end
        end
    else
        self.keybind:SetText("")
    end
end

---Reuse the existing badge area without implying confidence stars.
---复用现有标记位置，不把实验来源显示成高置信星级。
function IconWidget:SetSourceLabel(text)
    self.confidence:SetText(text or "")
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
    self.glowEnabled = enabled and true or false
    if self.reducedMotion and enabled then self.focusFrame:Show() else self.focusFrame:Hide() end
    enabled = enabled and not self.reducedMotion
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
    self.alertEnabled = enabled and true or false
    if enabled then
        self.alertFrame:Show()
        if self.reducedMotion then
            self.alertAnim:Stop()
            self.alertFrame:SetAlpha(1.0)
        elseif not self.alertAnim:IsPlaying() then self.alertAnim:Play() end
    else
        self.alertAnim:Stop()
        self.alertFrame:Hide()
    end
end

---Toggle the out-of-range state (red tint + slow pulse).
---切换超距状态（红色着色 + 缓慢脉冲）。
---From round15; the tint now comes from Theme.colors.outOfRange.
---来自 round15；着色改由 Theme.colors.outOfRange 提供。
---@param outOfRange boolean
function IconWidget:SetOutOfRange(outOfRange)
    outOfRange = outOfRange and true or false
    -- Guard against re-triggering the animation every UpdateDisplay tick.
    -- 防止每次 UpdateDisplay 都重启动画（热路径每 0.15–0.6s 跑一次）。
    if self.outOfRange == outOfRange then return end
    self.outOfRange = outOfRange

    if outOfRange then
        self.rangeText:SetText(RA.L and RA.L["RANGE_BADGE"] or "")
        self.icon:SetVertexColor(Theme.Unpack(Theme.colors.outOfRange))
        if not self.reducedMotion and not self.oorAnim:IsPlaying() then self.oorAnim:Play() end
    else
        self.rangeText:SetText("")
        -- Identity tint (1,1,1) = "no tint", a maths constant rather than a
        -- palette choice, so it is deliberately not a theme token.
        -- 单位着色 (1,1,1) 表示"不着色"，是数学恒等量而非配色选择，故不设令牌。
        self.icon:SetVertexColor(1, 1, 1)
        if self.oorAnim:IsPlaying() then
            self.oorAnim:Stop()
            self.frame:SetAlpha(1.0)
        end
    end
end

---Switch motion without leaving a pending old texture or pulse behind.
---切换动态效果时，同时清理旧纹理回调和脉冲。
function IconWidget:SetReducedMotion(enabled)
    enabled = enabled and true or false
    if self.reducedMotion == enabled then return end
    self.reducedMotion = enabled
    if enabled then
        if self.fadeTimer then self.fadeTimer:Cancel(); self.fadeTimer = nil end
        if UIFrameFadeRemoveFrame then UIFrameFadeRemoveFrame(self.frame) end
        if self.currentTexture then self.icon:SetTexture(self.currentTexture) end
        self.oorAnim:Stop()
        self.frame:SetAlpha(1.0)
    elseif self.outOfRange then
        self.oorAnim:Play()
    end
    self:SetGlow(self.glowEnabled)
    self:SetAlert(self.alertEnabled)
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
    if UIFrameFadeRemoveFrame then
        UIFrameFadeRemoveFrame(self.frame)
    end
    -- Cancelling a crossfade while the frame is faded out must not leave the
    -- widget permanently transparent when it is reused after module re-enable.
    -- 在淡出阶段取消交叉淡入时恢复透明度，避免模块重新启用后图标永久透明。
    self.frame:SetAlpha(1.0)
    self.currentSpellID = nil
    self.currentTexture = nil
    self.icon:SetTexture(Theme.FALLBACK_ICON)
    self.cooldown:Clear()
    self:SetKeybind("")
    self:SetCooldownTimer("")
    self:SetConfidence(nil)
    self:SetGlow(false)
    self:SetAlert(false)
    self:SetOutOfRange(false)
    self:SetDesaturated(false)
end
