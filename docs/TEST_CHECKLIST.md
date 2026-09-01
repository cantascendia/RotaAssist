# RotaAssist v1.1.0 测试清单 / Test Checklist

> 🚀 **首次真机测试请先跑 [`SMOKE_TEST_12.1.md`](SMOKE_TEST_12.1.md)** —— 10 分钟版，
> 覆盖发布阻塞项。本文件是**完整回归清单**，在冒烟通过之后使用。
>
> *First live run? Start with [`SMOKE_TEST_12.1.md`](SMOKE_TEST_12.1.md) (10 minutes,
> release blockers only). This file is the full regression pass, for after smoke passes.*

**范围 / Scope**：v1.1.0 只加载 Demon Hunter 三专精（D-014）。
非 DH 专精的数据文件仍在仓库中但已从 TOC 注释掉，**不在本清单范围内**。

**目标客户端 / Target**：World of Warcraft: Midnight 12.1（Interface `120100`）

---

## 基础加载 / Basic Loading
- [ ] `/reload` 无 Lua 错误
- [ ] 插件列表中**无「已过期 / Out of date」**标记（Interface 120100）
- [ ] `/ra` 打印命令列表（9 条）
- [ ] `/ra toggle` 显示 / 隐藏主界面
- [ ] `/ra config` 打开设置面板，各分页无错
- [ ] `/ra accuracy` 输出准确率历史
- [ ] `/ra aplcheck` 输出 **0 条**（三个 DH 专精均应为 0）
- [ ] `/ra debug` 切换调试模式；**关闭时聊天框无事件调试刷屏**
- [ ] `/ra reset` 重置设置与位置
- [ ] `/ra version` 打印 `v1.1.0`

## 合规 / Secret-Value Compliance
- [ ] M+ / PvP 场景（HP、能量可能为 secret）下**无 Lua 错误**
- [ ] 资源条在 secret 场景下优雅降级（空白或占位，不报错）
- [ ] 大量铭牌场景（AoE 拉怪）下阶段检测不报错
- [ ] 冷却面板在 secret 冷却场景下不报错

## Havoc DH (specID 577)
- [ ] 主图标显示 Blizzard 推荐技能
- [ ] 主图标与 Blizzard 技能条高亮**基本一致**
- [ ] 阶段检测正常（BURST_ACTIVE / AOE / NORMAL）
- [ ] 前瞻队列图标正确滚动更新
- [ ] 准确率计数器工作并显示百分比
- [ ] Metamorphosis 触发后 PhaseIndicator 变色
- [ ] 右键菜单全部选项可用

## Vengeance DH (specID 581)
- [ ] Demon Spikes 在冷却面板正确显示
- [ ] 防御建议在低血量时显示
- [ ] Spirit Bomb 优先于 Soul Cleave（灵魂碎片充足时）
- [ ] 资源条显示正确

## Devourer DH (specID 1480) — ⚠️ experimental
- [ ] 切入该专精**无 Lua 错误**
- [ ] 无效 spellID **只是不显示建议，不报错**（spellID 存在性防御）
- [ ] `/dump C_Spell.GetSpellInfo(442501)` 等占位 ID 验证结果已记录
      （详见 [`SMOKE_TEST_12.1.md`](SMOKE_TEST_12.1.md) 第 4 节）
- [ ] 决策树 / 转移矩阵加载无报错
- [ ] Void Metamorphosis 阶段检测

## 引擎模块 / Engine Modules
> 当前模块清单（v1.1.0）。`RecommendationManager` / `CooldownTracker` /
> `AssistCapture` 已于 v1.1.0 物理删除（D-013），**不应**再出现在任何测试中。

- [ ] `SpecDetector` — 专精切换时正确上报 specID
- [ ] `AssistedCombatBridge` — `C_AssistedCombat.GetNextCastSpell` 返回值被正确消费
- [ ] `APLEngine` — 加载期条件校验跑过一次（见 `/ra aplcheck`）
- [ ] `SmartQueueManager` — 多源融合输出单一建议，无闪烁
- [ ] `NeuralPredictor` — 个人马尔可夫矩阵按专精独立持久化
- [ ] `AIInference` — 阶段推断随战斗变化
- [ ] `PatternDetector` — 铭牌 / 节奏采样不报错
- [ ] `AccuracyTracker` — 实时与历史准确率均有数据
- [ ] `CastHistoryRecorder` — 施法环形缓冲写入 SavedVariables
- [ ] `CooldownOverlay` — 按当前专精追踪 CD（CD 面板的数据源）
- [ ] `InterruptAdvisor` — 已在 MODULE_ORDER 中，随引擎初始化
- [ ] `DefensiveAdvisor` — 低血量时给出防御建议
- [ ] `PrePullChecker` — 战斗外检查合剂 / 食物 / 符文
- [ ] `CDMHook` — **默认禁用**；启用后与原生 CooldownViewer 不重复显示

## UI
- [ ] `MainDisplay` — 拖拽 & 锁定（右键菜单）
- [ ] `MainDisplay` — **置信度星标方向正确**（高置信度显示更多星，不是更少）
- [ ] `MainDisplay` — **图标交叉淡入无残影**（快速切换推荐时不留半透明重叠图标）
- [ ] `MainDisplay` — 辅助战斗的助手图标**不泄漏进主显示**
- [ ] `PrePullPanel` — **战斗外确实会显示**（v1.1.0 前从不显示）
- [ ] `CooldownBar` — **冷却转圈会动，不恒为 0**
- [ ] `CooldownBar` — **键位文本与倒计时可同时显示**（不再互斥）
- [ ] `CooldownPanel` — **脱战后倒计时逐秒递减，不冻结**
- [ ] `CooldownPanel` — 用户自定义追踪技能（`trackedSpells`）覆盖生效
- [ ] `AccuracyMeter` — 颜色随准确率变化（红 / 黄 / 绿）
- [ ] `PhaseIndicator` — 阶段图标切换
- [ ] `ResourceBar` — 资源显示正确且 secret-safe
- [ ] `DefensiveAlert` — 防御提示可见
- [ ] `MinimapButton` — 小地图按钮可点击 / 可拖动
- [ ] `ConfigPanel` — 所有选项可改且即时生效
- [ ] 缩放（75% / 100% / 125% / 150%）
- [ ] 战斗结束后 fade out（combatOnly 模式）
- [ ] 打断警报音效 + 红色闪光（urgency ≥ 0.8）
- [ ] 多分辨率：1920×1080、2560×1440

## 性能 / Performance
> v1.1.0 引入战斗感知降频 + 充能扫描收窄（~95%）+ 删除 10Hz×131 技能轮询。
> 脱战 CPU 应显著低于 1.0.0。

- [ ] **站城脱战 5 分钟无可感 CPU 占用**（对比：关闭插件时的帧数）
- [ ] 5 分钟副本测试无卡顿
- [ ] 内存增长 < 1MB/小时
- [ ] `/dump GetAddOnMemoryUsage("RotaAssist")` < 2MB 初始
- [ ] 大 AoE 拉怪（10+ 铭牌）时无帧数骤降

## 本地化 / Localization
- [ ] 切换客户端语言至 zhCN → 所有 UI 文字中文
- [ ] 切换客户端语言至 jaJP → 所有 UI 文字日文
- [ ] enUS 默认完整
- [ ] 12 个战斗阶段名在三种语言下均已翻译（非英文枚举）

## 专精切换 / Spec Switching
- [ ] Havoc → Vengeance：决策树 / 矩阵重新加载，无错
- [ ] Vengeance → Devourer：无错（无效 spellID 静默跳过）
- [ ] Devourer → Havoc：恢复正常推荐
- [ ] 个人马尔可夫矩阵在切换后保持按专精独立
- [ ] 每次切换后 `/ra aplcheck` 仍为 0 条

## 持久化 / Persistence
- [ ] `/reload` 后主界面位置保留
- [ ] `/reload` 后设置（缩放 / 各开关）保留
- [ ] **完全退出游戏再进**后位置与设置仍保留
- [ ] 施法历史与准确率历史跨会话保留

## 打包 / Packaging
- [ ] `powershell -File scripts\package_release.ps1` 退出码为 0
- [ ] 产出 `RotaAssist-1.1.0.zip`，根目录为 `RotaAssist/`
- [ ] zip 内无 `.git` / `tests` / `training` / 脚本等开发残留
- [ ] 解压到 `Interface/AddOns/` 后游戏可直接识别
