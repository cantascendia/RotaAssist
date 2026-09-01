# RotaAssist — 产品愿景与技术愿景

> 最后更新: Round 16（第零轮重启） | 日期: 2026-09-01
> ⚠️ 本文件在 Round 16 被**大幅重写**。Round 11 版本基于 2026-03 的市场假设，
> 该假设已被 12.0/12.1 的 Blizzard 插件政策与市场格局推翻。

---

## 一、市场现实（2026-09-01 核实）

| 事实 | 证据 |
|---|---|
| 当前版本 **12.1.0「Curse of Ula'tek」**（2026-08 上线） | Wowhead / Icy Veins 12.1 指南 |
| TOC Interface = **120100**（12.0.0=120000, 12.0.5=120005） | Warcraft Wiki Patch 12.1.0/API changes |
| **Hekili 已死** — Midnight 前夕移除其依赖的 API 后停止工作 | Blizzard《Combat Philosophy and Addon Disarmament》 |
| **WeakAuras 自 12.0 起从未发布可用的 Midnight 版本** | 多个 12.1 插件指南 |
| Blizzard 政策：插件**只能显示，不能计算战斗决策** | 官方 news 24246290 |
| `C_Secrets.*` 运行时查询 API 存在（Should*BeSecret） | Patch 12.0.0 / 12.0.5 API changes |
| `COMBAT_LOG_EVENT_UNFILTERED` 注册即报错 → `_INTERNAL_` | Patch 12.0.0 API changes |
| 12.0.5 / 12.1 的「放宽」只针对**光环显示**，从未恢复战斗计算 | Icy Veins 两篇 relaxing 报道 |
| Devourer DH 专精真实存在，2026-03 随 Midnight 上线 | Blizzard news 24262570 |

### 竞品格局（全部是 C_AssistedCombat 薄封装）

| 插件 | 下载量 | 做的事 |
|---|---|---|
| Simple Assisted Combat Icon | **201.6K** | 显示 1 个推荐图标 |
| HekiLight | 33.2K | 5 图标条 + proc 金边 + 键位 + CD 转圈 + 20 slash 命令 |
| Blizzkili | 28.6K | 图标条 |
| BetterAssistant | 19.7K | 可移动图标 |
| Synaptic | 15.2K | 图标条 |
| Knickili | 13.2K | 致敬 Hekili 的图标条 |
| NextGCD | 1.8K | 图标条 |
| TrueShot (GitHub) | — | **唯一在 Blizzard 推荐之上叠加优先级修正的** |

**结论**：这是一片红海，但**红得很浅**。市场领导者做的是「把一个图标搬到屏幕中央」。
没有任何竞品做：多步前瞻、准确率反馈、战斗阶段识别、开怪前检查、战后复盘。

---

## 二、产品愿景

### 📦 最终产品形态

面向 WoW Midnight PvE 玩家（M+/Raid）的**循环教练**，而非循环代打。

关键定位转变：Blizzard 已经用 Assisted Highlight 免费提供了「下一个该按什么」。
在这个前提下，**复述 Blizzard 的答案没有价值**（7 个竞品在做同一件事）。
RotaAssist 的价值必须来自 Blizzard **不提供**的东西：

1. **前瞻** — 不只是下一个，而是接下来 3–5 个，让玩家能规划而非反应
2. **反馈** — 你打得对不对，哪里偏了，趋势如何
3. **情境** — 现在是爆发窗口/AoE/斩杀/危险，而不只是一个图标
4. **复盘** — 战斗结束后告诉你为什么低于预期

一句话：**竞品告诉你按什么；RotaAssist 让你变强。**

### 🧩 核心功能全景

| 模块 | 状态 | 说明 |
|---|---|---|
| C_AssistedCombat 桥接 | ✅ 已实现 | `AssistedCombatBridge.lua`，全项目最干净的模块 |
| 多源加权融合 | ✅ 已实现 | `SmartQueueManager.lua`，但评分公式无归一化上界 |
| APL 前瞻模拟 | 🔄 **20% 规则永久失效** | 70/352 条规则因条件词汇未实现而恒 false |
| 决策树 + Markov 预测 | ✅ 已实现 | **特征集 100% 合规**（见技术愿景） |
| 战斗阶段识别 | ⚠️ **双系统并存** | AIInference 与 PatternDetector 各算各的，~600 行重复 |
| 准确率追踪 | ✅ 已实现 | 但 `IsGCDSpell` 是空实现 |
| 打断提醒 | ⚠️ 未进 MODULE_ORDER | 初始化排在所有 UI 之后 |
| 防御建议 | 🔴 **HP 为 secret 时静默失效** | 正是 M+/PvP 最需要的场景 |
| 开怪前检查 | 🔴 **面板永不显示** | 全链路无一处 `Show()` |
| CD 面板 | ⚠️ 转圈计算恒为 0 | 且与 12.0 原生 CooldownViewer 重复显示 |
| 国际化 | ✅ 三语 183/182/182 键 | 阶段名 36/36 键齐全（Round 16 曾误报缺失，git 仲裁撤销） |
| EditMode 集成 | ❌ **零实现** | 12.0 用户的基本期望 |
| 训练管线 | ✅ 已实现 | Python，27K 行合成数据 |
| 桌面伴侣 (Tauri) | ⬜ 未开始 | 见「护城河」 |

### 🏁 当前状态 vs 最终目标

**代码量**：Core+Engine 7,326 行 / UI 2,369 行 / 测试 25+ 文件 / 训练管线 1,082 行 Python。
**这不是一个原型，是一个成熟度不低的中型项目。**

但它**从未上线，从未在真机跑过一次**。

三个致命的「从未」：
1. 从未在 12.x 真实客户端验证过（所有 secret-value 处理都是纸上推演）
2. 从未发布（TOC 停在 120000，落后 3 个补丁；CurseForge/Wago ID 是占位符）
3. 从未有过用户（GitHub 账号被封，远端 2026-04-28 起不可达）

### 🚧 关键差距

差距**不在功能，在交付**。功能面 RotaAssist 是市场上最强的（竞品都只做 1/10）。
但一个跑不起来的强产品，输给一个跑得起来的弱产品。

排序后的差距：
1. **发布通道断了** — GitHub 账号封禁，无法 push/PR/CI/发版
2. **真机零验证** — 6 处 P0 secret 违规都是静态分析发现的，真机行为未知
3. **版本过时 3 个补丁** — 120000 vs 120100，游戏会标记为「已过期」
4. **数据可信度** — 151 处占位符，Devourer 全部 spellID 是编造的
5. **20 个专精半残** — 铺得太宽，7 个专精 APL 规则 ≥40% 失效

### ⚠️ 对既有产品规划的挑战

**挑战 1：ROADMAP.md 的竞品表已完全过时。**
表中列的 SACI / JAC / MaxDPS / RotationAnalyzer 已不是当前对手。
真实对手是 7 个 C_AssistedCombat 封装，且领先者靠**极简**拿到 201.6K 下载。

**挑战 2：「支持 20 个专精」是错误的产品目标。**
当前 20 个专精中，只有 DH 3 系的 APL 规则 100% 有效（因为它们是最早写的，
用的是引擎真正实现的条件词汇）。后加的专精用了 SimC 风格词汇，从未被引擎支持。
**宽度是负资产**：它稀释了质量，制造了「支持很多职业」的假象。
正确目标是 **3–5 个专精做到无可挑剔**，而不是 20 个专精各有 40% 规则是死的。

**挑战 3：Phase 3 的桌面伴侣不是「远期」，它是唯一的护城河。**
见下方技术愿景。

---

## 三、技术愿景

### 📐 架构评判

**好消息，且是重要的好消息**：这套架构是**为 secret-value 世界设计的**，方向正确。

验证依据（Round 16 实测）：
- ML 特征集 = `lastSpellID / secondLastSpellID / thirdLastSpellID / timeSinceLastCast /
  nameplateCount / secondaryResource / blizzardRecommendation / combatDuration / specID`
  → **全部是非 secret 数据**。决策树/Markov 层完全合规。
- `APLEngine` 是**前向模拟器**，不是实时状态求值器：`cd_ready` 读的是
  `simState.cooldowns`（由 `SimulateSpellCast` 填充），不是实时 API。**这是合法且聪明的设计。**
- `GetSpellCooldownSafe`（`Init.lua:137-201`）先 `issecretvalue` 再算术，写法是全项目模板级。
- `PrePullChecker` 只在战斗外读光环 — 正确。
- `ResourceBar.lua:110-114` 是标准的 UnitPower 处理写法。

**所以架构不需要推翻。** 需要的是：补漏、收窄、验证。

**真正的架构问题**（按严重度）：
1. `SmartQueueManager` 是 god object — 1030 行，`AssembleQueue` 单函数 578 行
2. 双阶段检测系统并存（AIInference vs PatternDetector），~600 行重复 + 双份采样开销
3. 跨模块内部状态突变 — UI 直接 `table.remove` Engine 的活队列；
   PatternDetector 写入 Data 层静态共享配置
4. 死代码链 975 行（RecommendationManager 及其独占消费的
   CooldownTracker / AssistCapture），其中 CooldownTracker 仍在 10Hz × 131 技能空转
5. 无 UI 设计系统 — 100% 硬编码颜色，同一界面 3 种绿、3 种红、4 种黑底不透明度

### 🔄 应做的根本性改变

**R1. 收窄产品面：20 专精 → 3 专精。**
保留 DH Havoc / Vengeance / Devourer（唯一 APL 100% 有效的三个）。
其余 17 个专精的数据文件移入 `addon/Data/_incubating/`，不进 TOC。
收益：可发布、可承诺、可测试。成本：一次 TOC 编辑。
风险：看起来功能变少 — 但目前那 17 个本来就是坏的，只是没人知道。

**R2. APL 条件词汇：实现 or 删除，不留静默失效。**
`APLEngine.lua:310` 的 `else pass = false` 是罪魁。两条路：
(a) 实现缺失词汇（`buff:` `debuff_missing:` 等）— 但它们依赖 secret 数据，
    在模拟器里只能用估算，可信度存疑；
(b) **推荐**：在 APL 加载时**校验条件词汇**，未知 token 直接报错并跳过该规则，
    同时在 `/ra debug` 中列出。让失效可见，而不是静默。
另需修 `splitConditions`（`APLEngine.lua:60-67`）：目前只切大写 ` AND `，
不支持 `OR`、不支持小写 `and`。

**R3. 建立 UI 设计系统 + EditMode 集成。**
新建 `addon/UI/Theme.lua` 作为唯一颜色/字号/间距/纹理来源，
把 A2 审计列出的全部硬编码值收敛进去。
同时接入 EditMode（当前 0 处引用）与 CooldownViewer 共存
（`feat/t2-cdm-hook-a53e` 分支已实现，510 行，可干净合并）。

**R4. 引入 `C_Secrets.*` 运行时自适应。**
当前项目对「什么是 secret」的判断是**静态硬编码假设**（写在 ROADMAP 表里）。
12.0 提供了 `C_Secrets.ShouldUnitPowerBeSecret` / `ShouldSpellCooldownBeSecret` /
`ShouldUnitAuraSlotBeSecret` / `ShouldUnitHealthMaxBeSecret` / `ShouldUnitStatsBeSecret`。
应封装为 `RA:IsDataAvailable(kind)`，让功能按运行时可用性优雅降级，
而不是按开发时的猜测。这也是唯一能让防御建议在 M+ 中恢复工作的路径。

**R5. 合并双阶段检测系统。**
AIInference 与 PatternDetector 二选一（建议保留 AIInference，
它已被 SmartQueueManager 消费），另一个的独有信号并入。

### 💡 创新机会

**I1. 多步前瞻是唯一没人做的事。** 7 个竞品全在显示「下一个」。
RotaAssist 已有 `PredictNext(depth)`。把它做成产品的**主视觉**，
而不是主图标旁边的小图标。

**I2. 战后复盘 = 真正的护城河。**
Blizzard 的限制只管游戏内插件，**管不到读 `WoWCombatLog.txt` 的外部程序**。
该文件在 Midnight 仍正常写入，Warcraft Logs 生态十余年合法运行。
在插件被削成「只能显示」的时代，**外部程序是唯一能做真分析的地方**。
Tauri 伴侣不是 Phase 3 的锦上添花，它是**竞品结构性无法跟进的差异化**。

**I3. 教练模式而非代打模式。**
Blizzard 明确反对「插件提供竞争优势」。把产品定位成
「事后告诉你哪里打错了」比「事中替你决定」在政策上更安全、
在价值上更持久，也避开了与 Assisted Highlight 的正面同质竞争。

### 🛠️ 技术选型挑战

- **Ace3** — 保留。成熟、免费、12.x 仍可用，无替换理由。
- **busted + 手写 mock** — 保留。但 mock 需按真机行为校准（当前全是假设）。
- **sklearn → Lua 决策树** — 保留，但训练数据是从同一份 APL 合成的，
  DT 本质是 APL 的有损再编码，信息增益存疑。真机施法日志才是有价值的训练源。
- **GitHub** — 🔴 **必须换**。账号 `Loveil381` 已被封禁，
  远端 403，2026-04-28 起完全不可达。这是当前唯一的绝对阻塞项。

### ⚡ 被忽视的性能金矿

按每秒开销排序（战斗外**也在跑**）：

| 热点 | 开销 | 位置 |
|---|---|---|
| CooldownTracker 全表轮询 | **1310 次 pcall+API/秒** | 131 技能 × 10Hz，且**消费者已死** |
| SmartQueue 充能扫描 | **~873 次 pcall+API/秒** | `SmartQueueManager.lua:388-395`，遍历全部 131 技能 |
| 三套独立铭牌扫描 | ~360 次 Unit* 调用/秒 | AIInference 5Hz + PatternDetector 2Hz + InterruptAdvisor 2Hz |
| 4 个常驻 OnUpdate 帧 | 持续 | SmartQueue/CooldownTracker/CooldownOverlay/DefensiveAdvisor 无战斗内外开关 |
| 热路径 table 分配 | 每帧 10+ 次 | 与文件自称的 "zero-allocation recycle" 直接矛盾 |

**挂机站城时这套东西全速运转。** 这是插件被卸载的经典原因。

### 🗺️ 架构演进路线图

| 阶段 | 目标 | 架构铺垫 |
|---|---|---|
| **P0 解封** | 恢复可发布状态 | 新远端 + CI 绿灯 + TOC 120100 |
| **P1 正确性** | 修 6 处 P0 secret 违规 + 5 个 UI bug | `C_Secrets` 封装层 |
| **P2 收窄** | 20 专精 → 3 专精，删 975 行死代码 | `_incubating/` 隔离区 |
| **P3 真机** | 首次真实客户端验证 | mock 按真机行为校准 |
| **P4 打磨** | Theme.lua + EditMode + CooldownViewer | 设计系统 |
| **P5 发布** | CurseForge/Wago 首发 | 真实 project ID |
| **P6 护城河** | Tauri 伴侣 + 战后复盘 | 日志解析 + ONNX |

### 🎯 如果只能做三件事

1. **恢复发布通道**（新 Git 远端 + CI）— 其他一切都堵在这后面。
   代码写得再好，推不出去等于不存在。
2. **真机验证 + TOC 120100** — 6 处 P0 secret 违规、全部 mock 假设、
   Devourer 的 44 个编造 spellID，都只能靠真机证伪。
   4 个月的纸上推演需要一次现实检验。
3. **收窄到 3 个专精并修到无可挑剔** — 用 DH 三系换取一个真正能发布、
   能被评价、能积累用户反馈的产品。宽度可以后补，信誉不能。
