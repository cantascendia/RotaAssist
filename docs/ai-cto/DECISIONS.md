# RotaAssist — 技术决策记录

> 最后更新: Round 16 | 日期: 2026-09-01

---

## 历史决策（D-001 ~ D-009，Round 1-14）

## D-001: 测试框架 — busted + mock_wow_api.lua
- Round 4 | 决策：busted (Lua BDD) + 手写 mock
- 理由：WoW 插件无法在真实环境外运行；busted 是 Lua 生态最成熟框架
- 结果：25 测试文件、~344 用例
- **Round 16 补充风险**：mock 行为是**开发时假设**，从未与真机校准。
  测试全绿不等于真机可用（20% 死 APL 规则就是测试没抓到的例子）。

## D-002: Registry 作为单一真相源
- Round 2 | PASSIVE_BLACKLIST / OVERRIDE_PAIRS / FALLBACK_TEXTURE 统一在 Registry.lua
- **Round 16 发现缺陷**：`Init.lua:307` 的别名赋值恒为 nil（TOC 加载顺序），
  实际生效的是 `Data/Registry.lua:26` 的反向赋值。属误导性死代码。

## D-003: SpecEnhancements schema 统一
- Round 3 | interruptSpell 改嵌套表；resource.powerType 统一为数字

## D-004: RecommendationManager 废弃
- Round 1 | 标记 DEPRECATED，从 TOC 注释掉
- **Round 16 修订 → 见 D-013**：仅注释不够，应物理删除（含连带死链 975 行）

## D-005: SendMessage mock 双表分发
- Round 9 | mock 同时检查 `_messageCallbacks` 和 `_eventCallbacks`

## D-006: CI 三 job 策略
- Round 4 | lua-check + python-training + lua-tests
- **Round 16 状态**：CI 无法运行 — GitHub 账号封禁（见 D-010）

## D-007: 多职业扩展策略
- Round 11 | 按 "APL → SpecEnhancements → DT/TM → TOC 注册" 逐职业扩展
- **Round 16 推翻 → 见 D-014**：该策略产出了 20 个专精，其中 7 个 APL
  规则 ≥40% 永久失效。宽度优先是错误的产品目标。

## D-008: Sticky Blizzard fallback CD 验证
- Round 14 | `lastKnownBlizzSpell` 作 fallback 前必须过 `IsSpellOnCooldown`

## D-009: CD 安全网 API fallback
- Round 14 | `cdStates[sid]` 缺失时调 `IsSpellOnCooldown` 兜底

---

# Round 16 新决策

## D-010: 🔴 迁移 Git 远端 — GitHub 账号已封禁
- **日期**: 2026-09-01
- **证据**:
  ```
  $ gh api user
  {"message": "Sorry. Your account was suspended", "status": "403"}
  $ git ls-remote origin HEAD
  remote: Your account is suspended.
  fatal: unable to access '...': error 403
  ```
  最后一次成功 fetch：`.git/FETCH_HEAD` mtime = 2026-04-28。
- **影响**：无法 push / PR / CI / 发版 / CurseForge 自动发布。
  **这是当前唯一的绝对阻塞项**，其他所有工作的产出都无法交付。
- **数据安全**：所有分支均存在于本地（`git branch -a` 确认 30+ 分支），
  2 个本地提交未推送。**无数据丢失风险**。
- **决策**：不等待申诉结果。并行推进两条路：
  (a) 用户向 GitHub Support 申诉（只有账号所有者能做）
  (b) 立即建立备用远端（GitLab / Codeberg / 自托管），保证工程流程不中断
- **不做**：不在受影响账号下创建新账号规避封禁（违反 GitHub ToS，会连坐封禁）
- **2026-09-01 用户裁定**：「不管 github，被彻底封了」——放弃申诉与 GitHub 路线。
  **本地 main 即真相源**，工程流程全部本地化：
  - 备份：`git bundle`（已建 `C:\projects\RotaAssist-backup-20260901.bundle`，
    每轮结束后重新生成）
  - 验证：本地 Lua 5.1（`C:\Program Files (x86)\Lua\5.1\`）`luac -p` 语法检查；
    luacheck/busted 因缺 C 编译器暂不可装，用结构检查 + agent 内嵌 stub harness 替代
  - CI：暂无。后续选定新远端（GitLab/Codeberg）时一并迁移 ci.yml
  - 发布：CurseForge/Wago 上传不依赖 GitHub，可手动 `scripts/package.sh` 出包

## D-011: 🔴 APL 条件词汇必须显式校验，禁止静默失效
- **日期**: 2026-09-01
- **根因**: `APLEngine.lua:310-311`
  ```lua
  else
      pass = false   -- ← 任何未识别的条件恒为 false
  end
  ```
  加上 `splitConditions`（`APLEngine.lua:60-67`）只切大写 ` AND `，
  不支持 `OR`、不支持小写 `and`。
- **实测影响**：**70 / 352 条 APL 规则（19.9%）永久失效**。
  按专精：Rogue Sub 64% / DK Unholy 62% / Warlock Demo 62% / Mage Frost 56% /
  Mage Arcane 50% / Shaman Enh 42% / Priest Shadow 41% 的规则是死的。
  DH 三系 0% — 因为它们最早写，用的正是引擎实现的词汇。
- **未实现的词汇**：`buff:*` `debuff:*` `debuff_missing:*` `debuff_remains:*`
  `cp>=N` `resource>=N` `resource_pct<N` `resource_deficit<N` `target_hp<N`
  `target_health_pct>N` `proc:*` `stacks:*` `charges:<name>>=N` `cd_not_ready:ID`
  `not_in_dance` `secondary_resource>=N` `resource_above_60`
- **决策**：在 `APLEngine:SetAPL()` 加载期校验每条规则的条件词汇，
  遇未知 token **立即报错并跳过该规则**，同时记入 `/ra debug` 可查的诊断列表。
- **理由**: 铁律 #9「硬编码占位 = 未完成」的同构问题 —
  静默失效比明确报错危险得多，它让 CI 绿灯、测试通过、产品坏掉。
- **不做**: 不为了让规则「跑起来」而实现依赖 secret 数据的词汇。
  模拟器里的估算值会产生看似合理实则错误的建议，比不建议更糟。

## D-012: 引入 C_Secrets 运行时自适应层
- **日期**: 2026-09-01
- **现状**: 全代码库 **0 处** `C_Secrets` 调用。对「什么是 secret」的判断
  是写在 ROADMAP.md 表格里的**静态开发时假设**。
- **12.0 提供的运行时 API**:
  `C_Secrets.ShouldUnitPowerBeSecret` / `ShouldSpellCooldownBeSecret` /
  `ShouldUnitAuraSlotBeSecret` / `ShouldUnitHealthMaxBeSecret` / `ShouldUnitStatsBeSecret`
- **决策**: 封装 `RA:IsDataAvailable(kind)`，功能按**运行时**可用性降级，
  而非按开发时猜测。
- **收益**: 这是让 DefensiveAdvisor 在 M+/PvP（HP 为 secret，正是最需要防御提示的场景）
  恢复工作的唯一路径。当前 `DefensiveAdvisor.lua:141-143` 把 probe frame 的 alpha
  读回来做比较，破坏了 curve 机制，导致整条防御链路静默失效。

## D-013: 物理删除死代码链（975 行），而非注释保留
- **日期**: 2026-09-01
- **范围**:
  | 文件 | 行 | 理由 |
  |---|---|---|
  | `Engine/RecommendationManager.lua` | 457 | TOC 已注释，零调用，且含 2 处 secret 违规反面样板 |
  | `Core/CooldownTracker.lua` | 262 | 唯一消费者是 RecommendationManager；仍在 10Hz×131 技能空转 |
  | `Core/AssistCapture.lua` | 256 | 唯一消费者是 RecommendationManager |
- **理由**: 铁律 #11 是「禁止删除重建替代精确修复」，指的是**不许用重写掩盖不会修**。
  这里是删除**确认无调用方的死代码**，语义相反，不冲突。
  保留注释状态的代价：修 secret 合规时它们是绊脚石，且 CooldownTracker 在真实消耗 CPU。
- **前置条件**: 删除前用 grep 二次确认零调用方，并在同一 commit 中删除对应测试。

## D-014: 产品面收窄 — 20 专精 → 3 专精
- **日期**: 2026-09-01
- **决策**: TOC 只注册 DH Havoc(577) / Vengeance(581) / Devourer(1480)。
  其余 17 个专精的 APL/DT/TM/SpecEnhancements 移入 `addon/Data/_incubating/`，不进 TOC。
- **依据**: 这 3 个是 APL 规则 100% 有效的仅有专精（0/30、0/17、0/37 死规则）。
  其余专精平均 30% 规则失效，且 DT 文件中 4 个是 14–30 行的存根
  （ROG_Subtlety 14 行 / DK_Frost 22 / Paladin_Ret 27 / Mage_Frost 30）。
- **反对意见与回应**: 「看起来功能变少」— 那 17 个专精目前就是坏的，
  只是没有用户发现。发布一个诚实的 3 专精产品，好过发布一个声称支持 20 专精
  但一半规则不工作的产品。宽度可以后补，信誉不能。
- **例外**: Devourer 保留但**必须先验证 44 个占位 spellID**（见 D-015）。

## D-015: Devourer 数据必须真机/权威源验证后才能发布
- **日期**: 2026-09-01
- **现状**: `Data/APL/DemonHunter_Devourer.lua` 有 **44 处**
  `⚠ UNVERIFIED: Placeholder spellID`，`DH_Devourer_TM.lua` 同样。
  全项目共 151 处 placeholder 标记。
- **好消息**: Devourer 已于 2026-03 随 Midnight 正式上线，
  spellID 现在是**可验证的公开数据**（Wowhead / Icy Veins 12.1 指南已存在）。
  且项目猜测的技能名（Consume / Reap / Void Metamorphosis）与官方描述**吻合** —
  设计方向正确，只是 ID 是编的。
- **决策**: 发布前必须用权威源逐个替换 spellID，并在 TOC 注册前
  跑一次「所有 spellID 经 `C_Spell.GetSpellInfo` 返回非 nil」的校验测试。
- **铁律依据**: #9 硬编码占位 = 未完成。

## D-016: 建立 UI 设计系统（Theme.lua）
- **日期**: 2026-09-01
- **现状**: 无任何 theme/token 文件。审计实测：
  - 同一界面 **3 种不同的绿**（`0.2,0.9,0.2` / `0.2,0.8,0.2` / `0.0,1.0,0.0`）
  - **3 种不同的红**、**4 种黑底不透明度**（0.5/0.6/0.7/0.8）
  - fallback 图标 ID `134400` 硬编码 **8 次**
  - `ResourceBar.lua` 的 powerType 用魔法数字 `17/0/1/3/8/11/4` 而非 `Enum.PowerType.*`
  - 淡入淡出时长散落 6 种值（0.1/0.15/0.2/0.3/0.4/0.5）
- **决策**: 新建 `addon/UI/Theme.lua` 作为颜色/字号/间距/时长/纹理的唯一来源。
- **配套**: 引入 `.agents/skills/design-system-enforcement` 在 UI 改动时强制检查。

## D-017: 接入 EditMode 与 CooldownViewer 共存
- **日期**: 2026-09-01
- **现状**: 全项目 **0 处** `EditMode` 引用、**0 处** `CooldownViewer` 引用。
  当前用自建拖拽 + 两套互不相干的坐标保存
  （`MainDisplay.lua:507-513` 与 `CooldownPanel.lua:145-153`）。
- **问题**: 12.0 用户期望所有 UI 进 EditMode 统一编辑；
  且 12.0 原生 `EssentialCooldownViewer` 与本插件 CD 面板功能重叠，会双份显示。
- **决策**: 合并 `feat/t2-cdm-hook-a53e` 分支（510 行，`Engine/CDMHook.lua` 259 行 +
  193 行测试，与 main 零冲突），随后补 EditMode 集成。

## D-018: 桌面伴侣从「远期」提升为战略护城河
- **日期**: 2026-09-01
- **依据**:
  1. Blizzard 政策明确：游戏内插件只能显示，不能计算战斗决策。
     7 个竞品全部退化为 C_AssistedCombat 薄封装，同质化严重。
  2. 该政策**不适用于读 `WoWCombatLog.txt` 的外部程序**。
     该文件在 Midnight 仍正常写入；Warcraft Logs 生态十余年合法运行。
  3. 因此外部程序是**唯一还能做真实战斗分析的地方**。
- **决策**: Tauri 伴侣 + 战后 AI 复盘不再是 Phase 3 的锦上添花，
  而是竞品**结构性无法跟进**的差异化。架构上现在就要为它预留：
  施法历史导出格式、准确率数据 schema 保持与外部解析器兼容。
- **合规红线**: 只读游戏自己写入磁盘的日志文件。
  **绝不**修改游戏客户端、注入进程、读内存、发送按键 — 那些是明确的封号行为。
