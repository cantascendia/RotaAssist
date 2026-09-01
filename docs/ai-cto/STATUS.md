# RotaAssist — CTO 项目状态

> 最后更新: **Round 16（第零轮重启）** | 日期: 2026-09-01
> ⚠️ 上一版 STATUS.md 停留在 Round 12，与仓库实际状态（Round 15 + T1-T5）严重脱节。本版按实测重写。

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

### 2. TOC 落后 3 个补丁
`## Interface: 120000`（12.0.0）— 当前游戏为 **12.1.0，需 120100**。
游戏会标记为「已过期插件」，默认不加载。

### 3. 六处 secret-value 硬违规
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

## 分支状态（origin/main = `2c0d990`，HEAD = `35f89ab` on `codex/fix-event-debug-spam`）

| 分支 | 领先 | 冲突 | 内容 |
|---|---|---|---|
| `codex/fix-event-debug-spam` (HEAD) | 3+2 | ✅ 干净 | 事件刷屏修复 + 图标泄漏修复 + CI 修复 |
| `feat/t5-repo-hygiene` | 1 | ⚠️ 琐碎 | .gitignore +6 行，纯 append 冲突 |
| `feat/t1-mage-fire-data` | 1 | ✅ 干净 | 火法 DT+TM+测试 **+968/−0** |
| `feat/t3-paladin-ret-audit-tests` | 1 | ✅ 干净 | 惩戒骑测试 +271 |
| `feat/t4-deathknight-audit-tests` | 1 | ✅ 干净 | DK 测试 +455/−38 |
| `feat/t2-cdm-hook-a53e` | 1 | ✅ 干净 | **CooldownViewer 共存** +510，补 12.0 最大缺口 |
| `improve/round15-ui-overhaul` | 13 | 🔴 **冲突** | MainDisplay 重写为水平图标条；比 main 老 1.5 月，落后 3 提交 |

**合并建议顺序**：HEAD → t5 → t1/t3/t4（批量）→ t2 → round15（**必须 rebase 不能 merge**）

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

| # | 任务 | 类型 | 优先级 |
|---|---|---|---|
| 1 | 恢复发布通道（新远端 + CI 绿灯） | 阻塞解除 | 🔴 最高 |
| 2 | TOC → 120100 + 6 处 P0 secret 违规 | 技术债 | 🔴 |
| 3 | APL 条件词汇加载期校验（D-011） | 技术债 | 🟠 |
| 4 | 删除 975 行死代码链（D-013） | 技术债 | 🟠 |
| 5 | 5 个 UI 功能性 bug | 功能完整性 | 🟠 |
| 6 | 合并 6 个干净分支 | 工程 | 🟠 |
| 7 | 收窄至 3 专精 + Devourer spellID 验证 | 产品关键路径 | 🟠 |
| 8 | Theme.lua 设计系统 + EditMode | UX | 🟡 |
| 9 | 真机冒烟测试 | 验证 | 🔴 但需用户执行 |
| 10 | 性能：4 个常驻帧加战斗开关 | 性能 | 🟡 |
| 11 | 双阶段检测系统合并 | 架构 | 🟡 |
| 12 | Tauri 伴侣（护城河） | 创新 | 🔵 P6 |

---

## 风险登记

| 风险 | 严重度 | 状态 |
|---|---|---|
| GitHub 账号封禁 → 无法交付 | 🔴 极高 | 需用户申诉；并行建备用远端 |
| 真机从未验证 → 全部 secret 处理是纸上推演 | 🔴 高 | 需用户在 12.1 客户端执行 |
| Devourer 44 个 spellID 编造 | 🟠 中 | 可用权威源验证（已上线 6 个月） |
| 市场同质化，领先者靠极简拿 201.6K | 🟠 中 | 差异化在前瞻/反馈/复盘 |
| mock 与真机行为偏离 | 🟠 中 | 真机验证后需回灌校准 mock |
| round15 分支冲突加深（3 条线改同一 681 行文件） | 🟡 低 | 尽快 rebase |
