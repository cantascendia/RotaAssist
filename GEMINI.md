# GEMINI.md — Antigravity Workspace Rules

这份规则在 **Google Antigravity IDE**（Agent-First IDE）中激活。Antigravity 负责浏览器验证、Stitch UI 设计、AI 图像生成等场景。

## 角色

你是本项目的 **UI / UX / 验证执行者**（委派层）。CTO 规划来自 Claude Code，你的职责是用浏览器自动化和 UI 设计工具完成验证与视觉任务。

## 完整手册

CTO 操作手册（§1-§29）：
`C:/projects/ai-playbook/playbook/handbook.md`

项目记忆：`docs/ai-cto/`（新会话必读）
项目专属规则：`CLAUDE.md`（技术栈、设计系统、铁律）

## 通用代码质量

- **读取优先，再改动**：修改任何文件前先读完整文件
- **最小变更原则**：PR diff 越小越易审
- **不过度抽象**：三次重复再抽象
- **不写多余注释**：只写 WHY 层注释
- **不加空异常处理**：捕获必有处理
- **不写 mock / 占位数据交付**：按钮不可点击 = 未完成
- **错误处理区分系统边界**：外部输入必校验

## 安全回退（铁律）

- **先创建 Git 分支**再改代码
- **禁止破坏性命令**：`git reset --hard`、`rm -rf`
- **每逻辑单元 commit 一次**
- **禁止跳过 hooks**
- **禁止删除重建替代精确修复**
- **禁止硬编码 secret**
- **UI 文本必须走 i18n**
- **环境配置必须分离**

## 委派场景（Antigravity 擅长的）

### 浏览器验证（Claude in Chrome）
用 AG 自带的浏览器自动化验证关键页面的**五态**：
- 空状态（无数据）
- 加载中
- 成功（有数据）
- 错误（API 失败、权限不足）
- 部分（下拉加载、分页）

### Stitch UI 设计
- 新页面草图、设计系统组件、响应式布局
- 输出 HTML/CSS 原型（注意：Stitch 产物是 Tailwind，若项目禁用 Tailwind 需转写为项目自有的设计 tokens）

### AI 图像生成
- 营销物料、README 截图、文档插画、空状态插图

### 八维审核中的 UX 面
专注 **UX 可用性**维度：信息架构、交互流、状态反馈、空态处理、错误提示、移动端适配、无障碍

## 参考 Skills

`.agents/skills/` 下的跨平台 Skills（三平台共读）：
- `ux-quality-checklist` — UI 提交前 UX 质量检查
- `i18n-enforcement` — 国际化合规检查
- `design-system-enforcement` — 设计系统合规检查
- `accessibility-checklist` — WCAG 2.1 AA 无障碍
- `release-readiness` — 发布就绪检查

---

## ⚠️ 本项目的特殊性：这不是 Web 项目

RotaAssist 是 **WoW 插件**（Lua 5.1 + Ace3），UI 跑在暴雪自己的框架系统里。
上面通用规则里关于 Tailwind / 响应式断点 / 移动端触控目标的部分**不适用**。
以下是本项目 UI 工作的真实约束（Round 16 审计得出）。

### 浏览器验证在这里是做不到的

**不要尝试用浏览器自动化验证本项目的 UI。** WoW 插件只能在游戏客户端里渲染。
可以做的替代验证：
- 读 Lua 源码检查布局逻辑（`SetPoint` 锚点是否自洽、尺寸计算是否与实际内容匹配）
- 检查 widget 生命周期（`Show()` / `Hide()` 是否配对 —— Round 16 就抓到
  `PrePullPanel` 全链路无一处 `Show()` 的 bug）
- 检查跨模块封装泄漏（UI 是否直接改了 Engine 返回的 table）
- 用 `busted` 跑 `tests/test_main_display.lua` 之类的 UI 逻辑测试

### 设计系统现状：欠债严重

**目前没有 theme / token 文件，100% 硬编码。** 实测问题：
- 同一界面 **3 种不同的绿**（`0.2,0.9,0.2` / `0.2,0.8,0.2` / `0.0,1.0,0.0`）
- **3 种不同的红**、**4 种黑底不透明度**（0.5 / 0.6 / 0.7 / 0.8）
- fallback 图标 ID `134400` 硬编码 **8 次**
- 淡入淡出时长散落 **6 种值**（0.1 / 0.15 / 0.2 / 0.3 / 0.4 / 0.5）
- `ResourceBar.lua` 用魔法数字 `17/0/1/3/8/11/4` 而非 `Enum.PowerType.*`

**规则**：不要新增任何硬编码颜色/字号/时长。
`addon/UI/Theme.lua` 建立后（D-016），全部引用它。

### 与 Midnight 12.1 原生 UI 的契合度：约 3/10

当前 UI 停留在 Legion/BfA 视觉。要补的差距：

| 缺口 | 现状 | 目标 |
|---|---|---|
| EditMode | **0 处引用**，用自建拖拽 + 两套互不相干的坐标保存 | 接入 EditMode 统一编辑 |
| CooldownViewer 共存 | **0 处引用**，与原生 `EssentialCooldownViewer` 双份显示同样的 CD | 合 `feat/t2-cdm-hook-a53e` |
| 视觉皮肤 | `BackdropTemplate` + `Interface\Tooltips\UI-Tooltip-Background` | `NineSliceUtil` / atlas（`SetAtlas` 当前 0 处调用） |
| 法术高亮 | 依赖 DF 10.1 后已被取代的 `ActionButton_ShowOverlayGlow` | `ActionButtonSpellAlertManager` |
| 布局 | 45 处手工 `SetPoint`，零抽象 | 暴雪自带 `AnchorUtil` / `GridLayoutMixin` / `LayoutMixin`（当前 0 处使用） |

### 无障碍：按 WoW 玩家场景而非 WCAG 移动端标准

不适用的：48×48 触控目标、响应式断点、屏幕阅读器。
**适用且当前不合格的**：
- `ResourceBar.lua:43` 用 **9pt** 字体（可读性下限以下）
- CD 剩余秒数用 10pt —— **战斗中最需要读的数字用了最小的字号**
- 字号全部写死，用户只能整框 `SetScale`，无法单独调字体
- 脱战淡出下限 `0.1` —— 整框 α=0.1 时所有文字实际不可读
- `CooldownPanel` 的「就绪」状态**仅靠绿色边框**表达（色盲不友好）；
  对比 `PhaseIndicator` 用 色+图标+文字 三重编码，那是正确做法
- `DefensiveAlert.lua:54` **无条件**播放 `PlaySoundFile(..., "Master")`，
  走 Master 声道无视游戏音效设置，且 ConfigPanel 里没有对应开关
- 循环脉冲动画不可关闭，对光敏感用户不友好

### 国际化：三语但有硬伤

`Locales/` 有 enUS / zhCN / jaJP 三份（183+ 键），覆盖率不错，
`PhaseIndicator` 的 12 个阶段名三语齐全（`enUS.lua:235-246`）。

新增用户可见字符串**必须同步补三份**。翻译要用 WoW 玩家熟悉的术语
（AOE→"群体"/"範囲"，EXECUTE→"斩杀"/"処刑"），不要直译。
校验命令：对每个新键 grep 三份 locale 文件，缺一份即不通过。
