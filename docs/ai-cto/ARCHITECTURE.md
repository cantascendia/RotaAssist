# RotaAssist — 架构文档

> 最后更新: Round 16 | 日期: 2026-09-01
> 本文件记录**实际架构**（含已知缺陷），不是理想架构。理想演进见 VISION.md。

---

## 规模

| 层 | 文件 | 行数 |
|---|---|---|
| Core | 5 | 1,430 |
| Engine | 14 | 5,896 |
| UI | 13 | 2,369 |
| Data | 60+ | APL 20 / DT 19 / TM 19 / SpecEnhancements 12 |
| Locales | 3 | enUS 183 / zhCN 182 / jaJP 182 键 |
| Tests | 25+ | ~344 用例 |
| Training (Python) | 5 | 1,082 |

---

## Core 层（1,430 行）

| 文件 | 行 | 职责 | 状态 |
|---|---|---|---|
| `Init.lua` | 486 | AceAddon bootstrap + MODULE_ORDER + slash + **secret-safe API 门面** | 职责过载，应拆 |
| `EventHandler.lua` | 276 | 订阅/节流/中央派发 | ✅ 全项目最干净 |
| `SavedVars.lua` | 150 | AceDB defaults + profile 回调 | 无版本迁移（注释声称有） |
| `AssistCapture.lua` | 256 | hook `ActionButton_ShowOverlayGlow` | ⚠️ 死链（见下） |
| `CooldownTracker.lua` | 262 | 全 whitelist CD 轮询 10Hz | ⚠️ 死链，且 1310 次 API/秒 |

### secret-safe API 门面（Init.lua）

| 函数 | 行 | 评价 |
|---|---|---|
| `RA:GetSpellCooldownSafe` | 137-201 | ✅ **模板级**：先 `issecretvalue` 再算术，充电分支逐字段校验 |
| `RA:GetPlayerHealthPercentSafe` | 338-351 | ✅ 正确 |
| `RA:IsSpellPassive` | 208-229 | 三级 fallback，但热路径每次可能分配空表 |
| `RA:ResolveSpellOverride` | 236-256 | ✅ 正确 |
| `RA:IsSpellRecommendable` | 268-296 | 5 层过滤，最多 6 次 pcall，每帧对全候选调用 |
| `RA:GetBaseSpellID` / `SharesCooldown` | 315-333 | ❌ 死代码，零调用 |

---

## Engine 层（5,896 行）

| 文件 | 行 | 复杂度 | 关键问题 |
|---|---|---|---|
| `SmartQueueManager.lua` | **1030** | **极高** | `AssembleQueue` 单函数 578 行；中文注释全文 mojibake |
| `APLEngine.lua` | 760 | 高 | `PredictNext` 218 行 6 层嵌套；条件词汇缺失导致 20% 规则死 |
| `AIInference.lua` | 613 | 高 | 与 PatternDetector 功能重叠 ~600 行 |
| `NeuralPredictor.lua` | 463 | 中-高 | 特征集合规 ✅ |
| `RecommendationManager.lua` | 457 | 中 | ❌ **已废弃**，TOC 已注释 |
| `PatternDetector.lua` | 427 | 中 | 与 AIInference 重复；写入 Data 层共享配置 |
| `CooldownOverlay.lua` | 386 | 中 | 5Hz |
| `CastHistoryRecorder.lua` | 323 | 低 | ✅ 环形缓冲零分配实现良好 |
| `DefensiveAdvisor.lua` | 311 | 中 | 🔴 HP=secret 时静默失效 |
| `InterruptAdvisor.lua` | 292 | 中 | ⚠️ **不在 MODULE_ORDER** |
| `AccuracyTracker.lua` | 291 | 低 | `IsGCDSpell` 空实现 |
| `AssistedCombatBridge.lua` | 235 | 低 | ✅ 最干净的 Engine 模块 |
| `SpecDetector.lua` | 167 | 低 | ✅ |
| `PrePullChecker.lua` | 141 | 低 | 含重复分支 + 未验证 spellID |

---

## 关键数据流

```
C_AssistedCombat ──→ AssistedCombatBridge ─┐
                                            │
CastHistoryRecorder ──→ NeuralPredictor ───┤
   (DT + Markov)                            ├──→ SmartQueueManager ──→ UI
APLEngine (前向模拟) ──────────────────────┤        (加权融合)
                                            │
AIInference (阶段/AoE/爆发) ───────────────┤
CooldownOverlay ───────────────────────────┤
DefensiveAdvisor ──────────────────────────┘

CastHistoryRecorder ──→ AccuracyTracker ──→ SavedVars
PatternDetector ──────→ AccuracyTracker   (独立的第二套阶段检测)
```

### 融合评分公式（`SmartQueueManager.lua:213-265`）

```
score = [blizz命中] × 1.0 × blizzardWeight(1.0)
      + [APL命中i]  × conf × aplWeight(0.6) × TIER[i]   TIER={1.0,0.5,0.3}
      + [盲区候选]  × 1.2                                ← 绝对加法，不乘权重
      + [CD就绪∧爆发准备] × 0.5 × cdWeight(0.5)
      + [防御推荐]  × urgency × defWeight(0.8)

confidence = min(1.0, score / 1.5)
```

**已知缺陷**：理论最大分 ≈3.85，归一化分母固定 1.5 → confidence 长期饱和在 1.0，无信息量。
`aiWeight(0.4)` 声明了但**代码中从未使用**（`L248-251` 分支体只有一行注释）。
5 个权重持久化到 SavedVariables，但 ConfigPanel 中**无任何编辑入口**。

---

## 初始化顺序（`Init.lua:36-61`）

```
Core:   SavedVars → EventHandler → AssistCapture → CooldownTracker
Engine: SpecDetector → AssistedCombatBridge → AccuracyTracker → AIInference →
        CastHistoryRecorder → PatternDetector → NeuralPredictor → APLEngine →
        SmartQueueManager → CooldownOverlay → DefensiveAdvisor → PrePullChecker
UI:     Widgets → MainDisplay → CooldownPanel → MinimapButton → ConfigPanel
```

未列出的模块被追加到**最后**。`InterruptAdvisor` 因此排在所有 UI 之后初始化。
MODULE_ORDER 21 项 vs TOC 实际加载 22 个模块，**无启动校验机制**。

### Registry 加载顺序脆弱性

`Init.lua:307` 的 `RA.KNOWN_OVERRIDE_PAIRS = RA.Registry.OVERRIDE_PAIRS` **恒为 nil**
（Init.lua 在 TOC 中先于 Data/Registry.lua 加载）。真正生效的是 `Data/Registry.lua:26` 的重新赋值。
同类无保护的加载期索引：`SmartQueueManager.lua:29`、`APLEngine.lua:17`、`NeuralPredictor.lua:28`。

---

## UI 层（2,369 行）

| 文件 | 行 | 职责 |
|---|---|---|
| `MainDisplay.lua` | 681 | T 型主框 + 180 槽位键位扫描 + 更新循环 + 拖拽/右键菜单 |
| `CooldownPanel.lua` | 290 | 独立可拖拽 CD 条（≤12 图标） |
| `ConfigPanel.lua` | 233 | AceConfig 选项表 |
| `IconWidget.lua` | 181 | 核心图标类 |
| `PhaseIndicator.lua` | 146 | 阶段徽章（12 色 + 11 图标） |
| `PrePullPanel.lua` | 144 | 开怪前检查 |
| `AccuracyMeter.lua` / `ResourceBar.lua` | 130 each | 准确率条 / 资源条 |
| `CooldownBar.lua` | 120 | 水平 CD 排 |
| `MinimapButton.lua` | 115 | LDB + LibDBIcon |
| `GlowWidget.lua` | 103 | 高亮 fallback |
| `DefensiveAlert.lua` | 73 | 防御弹窗 |
| `Widgets.lua` | 23 | 空壳聚合模块 |

**无 theme / design token 文件。** 45 处手工 `SetPoint`，零布局抽象。
动画混用 AnimationGroup / UIFrameFadeIn / C_Timer 三套机制，6 种不同时长。

---

## 死代码链（975 行）

```
RecommendationManager.lua (457行, TOC已注释)
        ↑ 唯一消费者
        ├── CooldownTracker.lua (262行) — GetAllCooldowns 无其他调用方
        └── AssistCapture.lua (256行)  — GetCurrentRecommendation 无其他调用方
```

删除 RecommendationManager 后，另两个模块的全部公开方法变为零调用，
但 CooldownTracker 仍以 10Hz × 131 技能持续消耗 CPU。**三者应一并处理。**

---

## 跨模块耦合违规

| # | 位置 | 问题 |
|---|---|---|
| 1 | `MainDisplay.lua:229-238` | UI 对 `GetFinalQueue()` 返回的**活引用**执行 `table.remove` — 破坏 Engine 内部状态与防抖基线 |
| 2 | `SmartQueueManager.lua:459` | 往 CooldownOverlay 的私有 `cdStates` 表注入字段 |
| 3 | `PatternDetector.lua:383-388` | 写入 `RA.SpecEnhancements[id].inferenceRules` — **污染 Data 层静态共享配置**，AIInference 读同一个表 |
| 4 | `SmartQueueManager.lua:357/410` | `softBlocked` / `windows` 传引用，APL 模拟会写回 AIInference 实时状态 |
| 5 | `SmartQueueManager.lua:1025` | OnDisable 只清 1/6 个模块引用，其余 5 个泄漏 |

---

## 训练管线（Python，1,082 行）

```
simc_apl_to_dataset.py (415) → CSV → train_decision_tree.py (115) → sklearn
                                   → sklearn2lua.py (146)      → DecisionTrees/*.lua
                                   → markov_builder.py (164)   → TransitionMatrix/*.lua
```

**特征集**（`data/*.csv`，27,005 行合成数据）：
`lastSpellID, secondLastSpellID, thirdLastSpellID, timeSinceLastCast, nameplateCount,
secondaryResource, secondaryResourceMax, blizzardRecommendation, combatDuration, specID`

✅ 全部为非 secret 数据 — 该层是合规的。
⚠️ 但训练数据由同一份 APL 合成，DT 本质是 APL 的有损再编码。
