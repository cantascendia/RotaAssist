# RotaAssist — CTO 项目状态

> 最后更新: **Round 19（进行中）** | 日期: 2026-09-01 | 目标：**v1.1.0 可发布**
> R16 = 第零轮重启（审计+P0+7 分支合并）；R17 = 死代码/降频（main=`604cb2e` 时点）；
> R18 = 发布准备 ✅（DH-only 收窄 D-014、Devourer 运行时防御 D-015、发布材料全套、
> `RotaAssist-1.1.0.zip` 出包验证 183 文件、523/523 测试）；
> R19 = 🔄 UI 融合（round15 水平图标条骨架 + main 差异化 widget + Theme.lua D-016）。
> 发布定义：R19 合入 + Workflow 多维发布审查通过 + zip 重打 + 用户真机冒烟
> （SMOKE_TEST_12.1.md，唯一需要用户做的步骤）。
> 下方 P0/P1 清单保留 Round 16 审计原文作为底账，✅ 标记表示已修复。

## 项目一句话
WoW Midnight (12.1) 循环**教练**插件 —— 在 Blizzard Assisted Combat 之上叠加多步前瞻、
准确率反馈与战斗阶段情境，定位从「告诉你按什么」转向「让你变强」。

## 质量评分: **5.5 / 10**
（上一版自评 8.5 —— 基于测试数量与功能清单。本版按**可交付性**重评：
代码成熟度确实不低，但从未发布、从未真机验证、发布通道断裂 4 个月。）

| 维度 | 分 | 说明 |
|---|---|---|
| 架构 | 7 | 为 secret-value 世界设计，方向正确；但有 god object 与双系统重复 |
| 代码质量 | 5 | 975 行死代码、6 处 P0 secret 违规、1030 行文件注释全 mojibake |
| 性能 | 4 | 4 个常驻 OnUpdate 帧战斗外全速运转，~2200 次 API/秒 |
| 安全/合规 | 5 | 方向对，但 6 处 secret 值参与比较/算术 |
| 测试 | 6 | 25 文件 344 用例，但 mock 从未与真机校准，没抓到 20% 死规则 |
| DX | 3 | 🔴 GitHub 账号封禁，无法 push/PR/CI/发版 |
| 功能完整性 | 4 | 5 个 UI 功能性 bug；20% APL 规则永久失效；151 处占位符 |
| UX | 4 | 无设计系统、无 EditMode、12 个阶段名各语言均显示英文枚举 |

---

## 🔴 P0 阻塞项

### 1. ~~GitHub 账号被封禁~~ → 用户已裁定放弃 GitHub（2026-09-01）
「不管 github，被彻底封了」。**本地 main 即真相源**，不再视为阻塞：
- 备份：`git bundle` 每轮末重建（`C:\projects\RotaAssist-backup-*.bundle`）
- 验证：本地 Lua 5.1 `luac -p`（`C:\Program Files (x86)\Lua\5.1\`）
- CI/新远端：留待选定 GitLab/Codeberg 时一并迁移
- 发布：CurseForge/Wago 手动上传，不依赖 GitHub
- 完整处置：DECISIONS.md D-010

### 2. ✅ TOC 落后 3 个补丁 — Round 16 已修（`120100`，commit 3ced3c6）

### 3. ✅ 六处 secret-value 硬违规 — Round 16 已全修（commit 3ced3c6，统一为
pcall → issecretvalue → 类型检查 → 兜底；RecommendationManager 随 Round 17 删除）
底账：
| 位置 | 问题 |
|---|---|
| `PatternDetector.lua:117-119` | `mx > 0` 比较发生在 `issecretvalue` 守卫**之前** |
| `NeuralPredictor.lua:261-263` | 同上，逐字重复 |
| `SmartQueueManager.lua:388-395` | `currentCharges` 完全无 `issecretvalue` 校验 |
| `APLEngine.lua:287-291` | 消费上述污染值做 `compareNumber` — **端到端可复现违规链** |
| `SmartQueueManager.lua:373` | 全项目唯一裸调用 `UnitPower`（无 pcall） |
| `RecommendationManager.lua:158-167` | 比较+除法双违规（死代码，但应随文件删除） |

---

## 🟠 P1 主要问题

| # | 问题 | 位置 | 量化 |
|---|---|---|---|
| 1 | APL 条件词汇未实现导致规则静默失效 | `APLEngine.lua:310` | **70/352 = 19.9%** |
| 2 | 防御建议在 HP=secret 时静默失效 | `DefensiveAdvisor.lua:141-143` | M+/PvP 全场景失效 |
| 3 | PrePullPanel 永不显示 | `PrePullPanel.lua` | 全链路无一处 `Show()` |
| 4 | confidence 星标语义倒置 | `MainDisplay.lua:262,289` | 传 0–1 浮点，函数期望整数 1/2/3 |
| 5 | CooldownBar CD 转圈恒为 0 | `CooldownBar.lua:82-83` | 括号内恒等于 0 |
| 6 | 死代码链 | RecommendationManager + CooldownTracker + AssistCapture | **975 行** |
| 7 | InterruptAdvisor 不在 MODULE_ORDER | `Init.lua:36-61` | 排在所有 UI 之后初始化 |
| 8 | 4 个常驻 OnUpdate 帧无战斗开关 | SmartQueue/CDTracker/CDOverlay/DefAdvisor | 站城全速运转 |
| 9 | 每帧扫描 131 技能充能 | `SmartQueueManager.lua:388-395` | ~873 pcall+API/秒 |
| 10 | CooldownTracker 全表轮询 | `CooldownTracker.lua:100-128` | 1310 次 API/秒，**消费者已死** |
| 11 | ~~12 个阶段 i18n 键全缺失~~ **误报已撤销** | `enUS.lua:235-246` | Round 16 git 仲裁：36/36 键在 HEAD 即存在。单 critic 幻觉案例，同 `.claude/rules/learned/2026-05-11` 模式 |
| 12 | 零 EditMode / 零 CooldownViewer 集成 | 全项目 | 12.0 用户基本期望 |
| 13 | 双阶段检测系统并存 | AIInference vs PatternDetector | ~600 行重复 + 双份采样 |
| 14 | 151 处占位符 | Devourer 数据 44 处 | 铁律 #9 违规 |
| 15 | SmartQueueManager 中文注释全文 mojibake | 全文件 1030 行 | UTF-8 被按 Shift-JIS 解读 |

---

## 分支状态（Round 16 末：main = `701a3ca`）

✅ **已全部合入 main（2026-09-01）**，经 `integrate/round16` 集成分支 + `--ff-only`：
codex/fix-event-debug-spam → t5（.gitignore append 冲突已解）→ t1 → t3 → t4 →
t2-cdm-hook（CDMHook 已进 MODULE_ORDER + TOC）→ improve/round16-compliance-and-bugs。
合并后 112 个非库 Lua 文件 `luac -p` 全部通过。

**仍未合并**：
| 分支 | 状态 |
|---|---|
| `improve/round15-ui-overhaul` | 🔴 需 **rebase**（禁 merge）。MainDisplay 水平图标条重写，比 main 老 1.5 月；现又叠加 round16 的 MainDisplay 改动，冲突进一步加深 |
| `improve/round17-dead-code-and-perf` | 🔄 执行中：D-013 死代码删除 + InterruptAdvisor MODULE_ORDER + 常驻帧降频 + 充能扫描收窄 |

📌 本地工作流备忘：合并 main 用集成分支 + `--ff-only`（branch-guard 拦 main 上的直接 Edit，
合并冲突也要在集成分支解）。每轮末重建 `git bundle` 备份。

---

## 竞品格局（2026-09 实测）

| 插件 | 下载 | 做的事 |
|---|---|---|
| Simple Assisted Combat Icon | 201.6K | 显示 1 个图标 |
| HekiLight | 33.2K | 5 图标条 + proc 金边 + 键位 |
| Blizzkili / BetterAssistant / Synaptic / Knickili / NextGCD | 1.8K–28.6K | 图标条 |

**Hekili 已死，WeakAuras 自 12.0 起从未发布可用版本。**
无任何竞品做：多步前瞻 / 准确率反馈 / 阶段识别 / 开怪前检查 / 战后复盘。

---

## 待办队列（按对最终产品的影响排序）

| # | 任务 | 类型 | 状态 |
|---|---|---|---|
| ~~1~~ | ~~恢复发布通道~~ | — | ✅ 用户裁定放弃 GitHub，本地 main 即真相源（D-010） |
| ~~2~~ | ~~TOC 120100 + 6 处 P0 secret 违规~~ | — | ✅ Round 16 完成（commit 3ced3c6） |
| ~~3~~ | ~~APL 条件词汇加载期校验~~ | — | ✅ Round 16 完成，`/ra aplcheck` 可查 55 条问题规则 |
| ~~4~~ | ~~删除 975 行死代码链~~ | — | 🔄 Round 17 执行中 |
| ~~5~~ | ~~5 个 UI 功能性 bug~~ | — | ✅ Round 16 完成 |
| ~~6~~ | ~~合并 6 个干净分支~~ | — | ✅ Round 16 完成（main = 701a3ca） |
| ~~10~~ | ~~常驻帧战斗开关~~ | — | 🔄 Round 17 执行中（降频而非停摆）+ 充能扫描收窄 |
| 7 | 收窄至 3 专精 + Devourer spellID 验证 | 产品关键路径 | 🟠 下一轮 |
| 8 | Theme.lua 设计系统 + EditMode | UX | 🟡 |
| 9 | 真机冒烟测试 | 验证 | 🔴 **需用户在 12.1 客户端执行** |
| 11 | 双阶段检测系统合并（AIInference vs PatternDetector） | 架构 | 🟡 |
| 12 | round15-ui-overhaul rebase（水平图标条） | UX | 🟡 |
| 13 | SmartQueueManager mojibake 注释修复 + AssembleQueue 拆分 | 技术债 | 🟡 |
| 14 | 本地测试运行器（lua.exe + busted shim，恢复 344 用例可跑） | 工程 | 🟠 |
| 15 | Tauri 伴侣（护城河） | 创新 | 🔵 P6 |

---

## 风险登记

| 风险 | 严重度 | 状态 |
|---|---|---|
| ~~GitHub 账号封禁~~ | — | ✅ 已裁定放弃；bundle 备份每轮末重建 |
| **本地单点：仓库只存在于这台 PC** | 🔴 高 | bundle 已建；建议尽快选定新远端或把 bundle 纳入 OneDrive 备份任务 |
| 真机从未验证 → 全部 secret 处理是纸上推演 | 🔴 高 | 需用户在 12.1 客户端执行 |
| 测试不可跑（无 busted，CI 无）→ 回归盲区 | 🟠 中 | 待办 #14；当前靠 luac -p + agent 内嵌 stub harness |
| Devourer 44 个 spellID 编造 | 🟠 中 | 网页抓取不可靠，待真机 `/dump` 验证 |
| mock 与真机行为偏离 | 🟠 中 | 真机验证后回灌校准 |
| round15 分支冲突加深（round16 又改了 MainDisplay） | 🟡 低 | rebase 时一并处理 |
| 审计误报（单 critic 幻觉）：本轮 1 例（阶段 i18n 键） | 🟡 低 | 重大发现须双源验证（git 仲裁先例） |
