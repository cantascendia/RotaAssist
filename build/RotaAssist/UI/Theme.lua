------------------------------------------------------------------------
-- RotaAssist - Theme (UI Design Tokens)
-- UI 设计令牌：颜色 / 字号 / 时长 / 纹理的唯一来源
-- UI デザイントークン：色・フォント・時間・テクスチャの単一情報源
--
-- D-016 (docs/ai-cto/DECISIONS.md): before this file the UI carried
--   3 different greens, 3 different reds, 4 different black-backdrop
--   alphas, the fallback icon id 134400 hardcoded 8 times, magic power
--   type numbers (17/0/1/3/8/11/4) and 6 scattered fade durations.
-- D-016：本文件之前，UI 层有 3 种绿、3 种红、4 种黑底不透明度、
--   8 处硬编码的 134400、7 个魔法 powerType 数字、6 种散落的淡入淡出时长。
--
-- RULE / 铁律: no UI file may introduce a literal colour, font size or
-- animation duration. Add a token here instead.
-- 规则：UI 文件不得新增字面量颜色 / 字号 / 时长，一律在此加令牌。
--
-- LOAD ORDER / 加载顺序: the .toc loads this file before every other UI
-- file (Widgets included), so `RA.Theme` is always present at runtime.
-- .toc 保证本文件先于所有 UI 文件（含 Widgets）加载，运行期 RA.Theme 恒存在。
------------------------------------------------------------------------

local _, NS = ...
local RA = NS.RA

local Theme = {}
RA.Theme = Theme

------------------------------------------------------------------------
-- Constants / 常量
------------------------------------------------------------------------

--- The "?" icon every widget falls back to when GetSpellInfo fails.
--- 技能信息获取失败时统一使用的问号图标（此前在 8 处硬编码）。
Theme.FALLBACK_ICON = 134400

------------------------------------------------------------------------
-- Colours / 颜色
-- Each entry is {r, g, b, a}. Use Theme.Unpack() to feed WoW setters.
-- 每项为 {r, g, b, a}，通过 Theme.Unpack() 传给 WoW 的设色 API。
------------------------------------------------------------------------

Theme.colors = {
    -- Backdrops: the four historical black alphas (0.5/0.6/0.7/0.8) collapse
    -- into two semantic tokens.
    -- 底色：历史上的 4 种黑底不透明度收敛为 2 个语义令牌。
    bg        = { 0.00, 0.00, 0.00, 0.70 },  -- panels, alerts / 面板与警报底
    bgLight   = { 0.10, 0.10, 0.10, 0.80 },  -- inset bars / 内嵌条底

    -- Borders / 边框
    border    = { 0.50, 0.50, 0.50, 0.80 },  -- 边框灰
    borderDim = { 0.20, 0.20, 0.20, 1.00 },  -- badge / meter frame

    -- Semantic states: one red, one green, one amber.
    -- 语义状态色：红 / 绿 / 琥珀各一种（此前各有 3 种）。
    alert     = { 1.00, 0.20, 0.20, 1.00 },  -- 警报红
    success   = { 0.20, 0.90, 0.20, 1.00 },  -- 成功绿
    warning   = { 1.00, 0.80, 0.20, 1.00 },  -- 警告琥珀

    -- Accents / 强调色
    gold      = { 1.00, 0.80, 0.00, 1.00 },  -- 金色
    neutral   = { 0.50, 0.50, 0.50, 1.00 },  -- 中性灰

    -- Text / 文本
    text      = { 1.00, 1.00, 1.00, 1.00 },
    textDim   = { 0.80, 0.80, 0.80, 1.00 },
}

-- Confidence stars are gold; kept as a named intent alias pointing at the
-- SAME table so there is literally one gold in the product.
-- 置信度星标用金色 —— 指向同一张表，保证全产品只有一种金。
Theme.colors.confidence = Theme.colors.gold

-- Out-of-range tint reuses the single alert red (round15 used 0.8/0.2/0.2).
-- 超距红色复用唯一的警报红（round15 曾另用 0.8/0.2/0.2）。
Theme.colors.outOfRange = Theme.colors.alert

------------------------------------------------------------------------
-- Combat phase palette / 战斗阶段色板
-- Moved out of PhaseIndicator.lua: this is a semantic palette, so it is a
-- theme concern. Keys mirror the phase enum produced by AIInference.
-- 从 PhaseIndicator.lua 迁入：它是语义色板，属于主题范畴。
------------------------------------------------------------------------

Theme.phases = {
    BURST_PREPARE    = { 1.00, 0.50, 0.00 }, -- Orange / 橙
    BURST_ACTIVE     = { 1.00, 0.40, 0.00 }, -- Darker orange / 深橙
    BURST_COOLDOWN   = { 0.40, 0.40, 0.40 }, -- Gray / 灰
    AOE              = { 0.60, 0.20, 0.80 }, -- Purple / 紫
    EMERGENCY        = { 0.80, 0.10, 0.10 }, -- Red / 红
    NORMAL           = { 0.50, 0.50, 0.50 }, -- Gray / 灰
    OPENER           = { 0.20, 0.60, 1.00 }, -- Blue / 蓝
    PREPULL          = { 0.10, 0.80, 0.80 }, -- Cyan / 青
    EXECUTE          = { 0.80, 0.00, 0.20 }, -- Dark red / 暗红
    RESOURCE_CAP     = { 1.00, 0.80, 0.20 }, -- Yellow / 黄
    RESOURCE_STARVED = { 0.80, 0.60, 0.00 }, -- Dark yellow / 暗黄
    UNKNOWN          = { 0.30, 0.30, 0.30 },
}

------------------------------------------------------------------------
-- Power type palette / 资源类型色板
-- D-016: ResourceBar used the raw numbers 17/0/1/3/8/11/4. Enum.PowerType
-- is preferred but is not guaranteed to exist at file-load time (and does
-- not exist in the test mock), so each key falls back to its literal id.
-- D-016：ResourceBar 曾用裸数字 17/0/1/3/8/11/4。优先用 Enum.PowerType，
-- 但它在加载期不保证存在（测试 mock 里也没有），故逐项回落到字面 id。
------------------------------------------------------------------------

local PowerType = (type(Enum) == "table" and Enum.PowerType) or {}

Theme.power = {
    [PowerType.Mana        or 0 ] = { 0.20, 0.40, 1.00 },
    [PowerType.Rage        or 1 ] = { 1.00, 0.20, 0.20 },
    [PowerType.Energy      or 3 ] = { 1.00, 0.90, 0.20 },
    [PowerType.ComboPoints or 4 ] = { 1.00, 0.60, 0.00 },
    [PowerType.LunarPower  or 8 ] = { 0.30, 0.50, 1.00 },
    [PowerType.Maelstrom   or 11] = { 0.00, 0.50, 1.00 },
    [PowerType.Fury        or 17] = { 0.60, 0.20, 0.80 },
}

------------------------------------------------------------------------
-- Typography / 字体
------------------------------------------------------------------------

Theme.fonts = {
    -- 10 is the floor: ResourceBar used to render at 9pt and was unreadable.
    -- 10 为下限：ResourceBar 此前用 9pt，实际难以辨识。
    sizes = {
        small  = 10,
        normal = 12,
        large  = 14,
    },
    outline = "OUTLINE",
}

---Resolve the addon-wide font face.
---解析全局字体（STANDARD_TEXT_FONT 在极早期加载时可能尚未就绪）。
---@return string fontPath
function Theme.Face()
    return STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
end

------------------------------------------------------------------------
-- Durations / 时长 (seconds)
-- D-016: six scattered values (0.1/0.15/0.2/0.3/0.4/0.5) collapse to four
-- named beats plus the alert hold time.
-- D-016：散落的 6 种时长收敛为 4 个语义节拍 + 警报驻留时长。
------------------------------------------------------------------------

Theme.durations = {
    crossfade = 0.10,  -- icon texture swap / 图标换纹理
    fadeIn    = 0.15,  -- widget appear / 挂件淡入
    fadeOut   = 0.30,  -- widget disappear / 挂件淡出
    pulse     = 0.50,  -- one half of an alert pulse cycle / 警报脉冲半周期
    hold      = 2.00,  -- how long an alert stays up before auto-dismiss / 警报驻留
}

------------------------------------------------------------------------
-- Textures / 纹理
------------------------------------------------------------------------

Theme.textures = {
    tooltipBg     = "Interface\\Tooltips\\UI-Tooltip-Background",
    tooltipBorder = "Interface\\Tooltips\\UI-Tooltip-Border",
    solidBg       = "Interface\\ChatFrame\\ChatFrameBackground",
    statusBar     = "Interface\\TargetingFrame\\UI-StatusBar",
    questionMark  = "Interface\\Icons\\INV_Misc_QuestionMark",
}

-- Backdrop tables are shared, immutable-by-convention singletons: WoW reads
-- them synchronously inside SetBackdrop, so reusing one table per style keeps
-- the hot paths allocation-free.
-- Backdrop 表按样式共享单例：SetBackdrop 内部同步读取，复用可避免热路径分配。
Theme.backdrops = {
    -- Main strip / floating panels / 主条与浮动面板
    panel = {
        bgFile   = Theme.textures.tooltipBg,
        edgeFile = Theme.textures.tooltipBorder,
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    },
    -- Checklist / tooltip-ish panels / 清单类面板
    tooltip = {
        bgFile   = Theme.textures.tooltipBg,
        edgeFile = Theme.textures.tooltipBorder,
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    },
    -- Small badges and meters / 徽章与仪表
    badge = {
        bgFile   = Theme.textures.solidBg,
        edgeFile = Theme.textures.tooltipBorder,
        tile = false, tileSize = 0, edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    },
    -- Border only (alert pulse ring) / 仅边框（警报脉冲环）
    outline = {
        edgeFile = Theme.textures.tooltipBorder,
        edgeSize = 12,
    },
    -- Flat fill (resource bar background) / 纯色填充（资源条底）
    solid = {
        bgFile = Theme.textures.solidBg,
    },
}

------------------------------------------------------------------------
-- Chat colour escapes / 聊天框颜色转义
------------------------------------------------------------------------

Theme.hex = {
    accent = "|cFF00CCFF",
    muted  = "|cFFCCCCCC",
    link   = "|cFF7FAFFF",
    reset  = "|r",
}

------------------------------------------------------------------------
-- Helpers / 辅助函数
-- All allocation-free: they return multiple values instead of tables.
-- 全部零分配：返回多值而非新表。
------------------------------------------------------------------------

---Expand a colour token into r, g, b, a.
---展开颜色令牌为 r, g, b, a。
---@param color table|nil  {r, g, b, a}
---@param alphaOverride number|nil  overrides the token's alpha / 覆盖令牌透明度
---@return number r, number g, number b, number a
function Theme.Unpack(color, alphaOverride)
    if not color then return 1, 1, 1, 1 end
    return color[1], color[2], color[3], alphaOverride or color[4] or 1
end

---Apply a backdrop style plus its background / border colours in one call.
---一次性套用 backdrop 样式与底色 / 边框色。
---@param frame table          BackdropTemplate frame
---@param style string         key in Theme.backdrops / Theme.backdrops 的键
---@param bgKey string|nil     key in Theme.colors for the fill / 底色令牌
---@param borderKey string|nil key in Theme.colors for the edge / 边框色令牌
---@param bgAlpha number|nil   overrides the fill alpha / 覆盖底色透明度
---@param borderAlpha number|nil overrides the edge alpha / 覆盖边框透明度
function Theme.ApplyBackdrop(frame, style, bgKey, borderKey, bgAlpha, borderAlpha)
    if not frame or not frame.SetBackdrop then return end
    frame:SetBackdrop(Theme.backdrops[style])
    if bgKey and frame.SetBackdropColor then
        frame:SetBackdropColor(Theme.Unpack(Theme.colors[bgKey], bgAlpha))
    end
    if borderKey and frame.SetBackdropBorderColor then
        frame:SetBackdropBorderColor(Theme.Unpack(Theme.colors[borderKey], borderAlpha))
    end
end

---Set a FontString's face + size + outline from the token table.
---按令牌设置 FontString 的字体 / 字号 / 描边。
---@param fontString table
---@param sizeKey string|number  "small"|"normal"|"large" or an explicit pt / 或显式磅值
function Theme.ApplyFont(fontString, sizeKey)
    if not fontString or not fontString.SetFont then return end
    local size = tonumber(sizeKey) or Theme.fonts.sizes[sizeKey] or Theme.fonts.sizes.normal
    fontString:SetFont(Theme.Face(), size, Theme.fonts.outline)
end

---Scale a font to an icon's size, never dropping below the small token.
---按图标尺寸缩放字号，但不低于 small 令牌。
---@param iconSize number
---@param ratio number
---@return number pt
function Theme.ScaledFontSize(iconSize, ratio)
    local pt = math.floor((iconSize or 0) * (ratio or 0.25))
    local floorPt = Theme.fonts.sizes.small
    if pt < floorPt then return floorPt end
    return pt
end

---Set a FontString's colour from a token key.
---按令牌键设置 FontString 颜色。
---@param fontString table
---@param colorKey string
---@param alphaOverride number|nil
function Theme.SetTextColor(fontString, colorKey, alphaOverride)
    if not fontString or not fontString.SetTextColor then return end
    fontString:SetTextColor(Theme.Unpack(Theme.colors[colorKey], alphaOverride))
end

---Look up a phase colour, falling back to UNKNOWN.
---查阶段色，缺失时回落到 UNKNOWN。
---@param phase string|nil
---@return table color
function Theme.PhaseColor(phase)
    return (phase and Theme.phases[phase]) or Theme.phases.UNKNOWN
end

---Look up a power-type colour, falling back to neutral grey.
---查资源类型色，缺失时回落到中性灰。
---@param powerType number|nil
---@return number r, number g, number b
function Theme.PowerColor(powerType)
    local c = powerType and Theme.power[powerType] or Theme.colors.neutral
    return c[1], c[2], c[3]
end
