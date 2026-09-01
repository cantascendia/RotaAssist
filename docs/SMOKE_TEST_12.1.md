# RotaAssist v1.1.0 — 12.1 真机冒烟测试 / Live Smoke Test

> **约 10 分钟 / ~10 minutes** · 目标客户端：**World of Warcraft: Midnight 12.1**（Interface `120100`）
>
> 这是 RotaAssist **第一次**在真实客户端上运行。此前所有 secret-value 处理、
> mock 行为与 Devourer 数据都是纸上推演。这份清单的目的不是证明插件是好的，
> 而是**尽快找出它在哪里不好**。
>
> *This is RotaAssist's first run on a live client. Every secret-value guard, every mock
> behaviour, and all Devourer data has so far only been reasoned about on paper. The goal
> of this checklist is not to prove the addon works — it is to find out where it doesn't,
> fast.*

**请在做每一步时把「实际结果」写下来**，即使它和预期一致。
不一致的地方，请按每一节的「失败请记录」逐项抓取，那是唯一能让 v1.1.1 修对的输入。
文末有一份可直接填写的记录模板。

---

## 0. 准备 / Preparation（约 2 分钟）

- [ ] **装 BugSack + BugGrabber**（强烈建议 / strongly recommended）
      没有它，Lua 错误只会一闪而过；有它，错误会存下来可复制全文。
      *Without an error catcher, Lua errors flash by unreadable.*
- [ ] 把 `RotaAssist-1.1.0.zip` 解压到
      `World of Warcraft/_retail_/Interface/AddOns/`
      确认存在 `Interface/AddOns/RotaAssist/RotaAssist.toc`
- [ ] **只保留 RotaAssist + BugSack + BugGrabber**，其他插件全部禁用
      （首轮冒烟要排除插件冲突这个变量 / isolate addon conflicts on the first pass）
- [ ] 角色：**恶魔猎手**。先用 **Havoc（浩劫，577）** 跑一遍，再切 **Devourer（1480）**
- [ ] 记录客户端版本：`/dump GetBuildInfo()`

  **写下 / record:** `______________________`

---

## 1. 加载无错 / Clean Load（1 分钟）

**操作 / Do**

1. 进入游戏，角色进入世界
2. 打开 AddOns 列表，确认 RotaAssist **没有**被标记为 `Out of date`
3. 输入 `/reload`
4. 看 BugSack 图标

**预期结果 / Expected**

- ✅ RotaAssist 在插件列表中显示为已启用，**无「已过期 / Out of date」标记**
- ✅ 聊天框出现 RotaAssist 的载入信息，**无红色 Lua 错误**
- ✅ BugSack 图标为绿色 / 无新错误计数

**如果失败请记录 / If it fails, record**

- BugSack 里**每一条**错误的**完整文本**（含 `Stack:` 与 `Locals:` 段，不要只截第一行）
- 错误出现的时机：登录时 / `/reload` 时 / 进战斗时
- AddOns 列表里 RotaAssist 显示的 Interface 号
- 是否勾选了「载入过期插件 / Load out of date AddOns」

> ⚠️ 如果这一步就报错，**先不要继续往下走**。把错误全文贴回来，其余测试的结果都不可信。

---

## 2. 主面板与命令 / Main Panel & Commands（1 分钟）

**操作 / Do**

1. 输入 `/ra` — 这会**打印命令列表**（不是开面板）
2. 输入 `/ra toggle` — 显示 / 隐藏主界面
3. 输入 `/ra config` — 打开设置面板
4. 输入 `/ra version`

**预期结果 / Expected**

- ✅ `/ra` 打印 9 条命令，含 `/ra aplcheck`
- ✅ `/ra toggle` 切换主界面的显示与隐藏（脱战时如果开了 combat-only 模式，可能需要先在 `/ra config` 里关掉才看得见）
- ✅ `/ra config` 打开 Ace3 设置窗口，各分页可点开且不报错
- ✅ `/ra version` 打印 `RotaAssist v1.1.0`

**如果失败请记录 / If it fails, record**

- 哪一条命令没反应 / 报什么错
- `/ra version` 打印的版本号（如果不是 1.1.0，说明装到了旧包）
- `/ra toggle` 无反应时：`/ra config` → 是否开着 combat-only？主界面是否被拖到屏幕外？
  （可用 `/ra reset` 重置位置后重试）
- `/ra config` 报错时：是哪个分页触发的

---

## 3. APL 条件校验 / `/ra aplcheck`（1 分钟）⭐

这是 v1.1.0 的**核心诚实性检查**。以前未识别的循环条件会静默失效；
现在它们在加载期就被记录下来。

**操作 / Do**

1. 以 **Havoc** 专精，输入 `/ra aplcheck`，**把输出完整抄下来**
2. 切到 **Vengeance**，等专精切换完成，再次 `/ra aplcheck`
3. 切到 **Devourer**，等专精切换完成，再次 `/ra aplcheck`

**预期结果 / Expected**

- ✅ **Havoc：条件 token 0 条问题**，且无 unknown-spell 记录
- ✅ **Vengeance：同上**
- ⚠️ **Devourer：条件 token 0 条问题，但预计出现 unknown spells 列表** ——
  报告会列出客户端不认识的 spellID（它们已在加载期被剪出循环）。
  **这不是失败，这正是防御机制在工作**；请把整段列表抄下来，
  它就是修正 Devourer 数据所需的全部信息。
  Expect an "unknown spells" section for Devourer — that is the guard
  working, not a failure. Copy the whole list; it is exactly what we
  need to fix the data.

  DH 三专精是全项目唯一 APL 条件词汇 100% 受引擎支持的专精 —— 这正是 v1.1.0
  只发布它们的原因。**任何非零输出都是真实发现，请完整记录。**

> 📌 **注意范围**：`/ra aplcheck` 报告两类问题——**条件 token**（`cd_ready` /
> `in_meta` 等是否受引擎支持）与 **unknown spells**（加载期 `C_Spell.GetSpellInfo`
> 查不到的 spellID，规则已被剪除）。第 4 节的 `/dump` 是对后者的**独立复核**：
> 两边结果应当互相印证（aplcheck 列出的 ID，`/dump` 应返回 nil）。

**如果失败请记录 / If it fails, record**

- 每一行输出的**原文**，格式为
  `[spec <id>] <list>  spell <id>  token=<token>  cond="<condition>"`
- 当时的专精与英雄天赋
- 载入时聊天框是否出现过
  `APLEngine: specID NNN has N rule(s) with unsupported conditions`

---

## 4. Devourer spellID 真伪验证 / Verify Devourer IDs（2 分钟）⭐⭐

Devourer 数据中的部分 spellID 来自早期资料，**很可能是错的**。
这一节是整份清单里**信息价值最高**的部分。

**操作 / Do** — 逐条输入并记录完整输出：

```
/dump C_Spell.GetSpellInfo(442501)
/dump C_Spell.GetSpellInfo(442510)
/dump C_Spell.GetSpellInfo(442525)
```

再输入两个**对照组**（这两个是 12.x 确实存在的恶魔猎手技能，用来确认命令本身没打错）：

```
/dump C_Spell.GetSpellInfo(198793)
/dump C_Spell.GetSpellInfo(370965)
```

| spellID | 我们数据里的名字 / Our label | 类型 |
|---|---|---|
| `442501` | Consume — filler | 待验证 unverified |
| `442510` | Collapsing Star — 30 Soul AoE nuke | 待验证 unverified |
| `442525` | Soul Immolation — resource gen | 待验证 unverified |
| `198793` | Vengeful Retreat | **对照组 control** |
| `370965` | The Hunt | **对照组 control** |

**预期结果 / Expected**

- ✅ 两个**对照组**必须返回一个含 `name = "..."` 的表（`Vengeful Retreat` / `The Hunt`
  或对应语言的译名）。**如果对照组也是 nil，说明命令输错了或客户端语言不同 ——
  先修这个再看上面三个。**
- ❓ 三个 `4425xx` 是**开放问题**，两种结果都是有效发现：
  - 返回表 → 记下 `name` 字段，看它是否与我们的标注一致
  - 返回 `nil` / 空 → 这个 ID 是编的，需要替换

**如果失败请记录 / If it fails, record**

- **每个 ID 的完整 `/dump` 输出**（返回 nil 也要记 "nil"）
- 客户端语言（技能名会跟着客户端语言变）
- 如果你**知道**正确的技能：在 Devourer 技能书里右键 → 或用鼠标悬停后
  `/dump C_Spell.GetSpellInfo("技能名")`，把**真实 ID** 记下来 —— 这直接能修好数据
- 你的英雄天赋（Annihilator / Void-Scarred），因为技能池会不同

> 这些结果请回报到 CurseForge 评论区或直接反馈给开发。**它们是 Devourer 从
> experimental 转正的唯一路径。**

---

## 5. C_AssistedCombat API 活性 / API Liveness（30 秒）

确认 Blizzard 的底层 API 在你的客户端上确实在返回数据 —— 整条推荐链都建在它上面。

**操作 / Do**

1. **选中一个训练木桩**（不要空目标）
2. 输入 `/dump C_AssistedCombat.GetNextCastSpell(true)`
3. 输入 `/dump C_AssistedCombat.IsAvailable()`

**预期结果 / Expected**

- ✅ `GetNextCastSpell(true)` 返回一个**数字 spellID**（不是 nil、不是 secret）
- ✅ `IsAvailable()` 返回 `true`

**如果失败请记录 / If it fails, record**

- 完整输出（`nil` / 报错文本 / 返回的第二个值 reason）
- 是否选中了目标、是否在战斗中
- 是否在游戏设置里关闭了「辅助战斗 / Assisted Combat」高亮
- 你的专精

> ⚠️ 如果 `IsAvailable()` 返回 false 并带 reason，**请把 reason 原文记下来** ——
> 那决定了插件在什么条件下应该优雅降级。

---

## 6. 木桩实战 2 分钟 / Target Dummy Run（2 分钟）⭐

**操作 / Do**

1. 找训练假人，**Havoc 专精**，正常输出 **2 分钟**（不用打得好，正常按就行）
2. 全程盯这三件事：
   - **主图标**与 Blizzard 自带的**技能条高亮**是否指向同一个技能
   - 推荐**跟手度**：你按完一个技能后，主图标多久换成下一个
   - **前瞻图标**是否在跟着变，还是卡住不动
3. 结束后 `/ra accuracy`

**预期结果 / Expected**

- ✅ 主图标与 Blizzard 高亮**绝大多数时候一致**。偶尔不同是**设计如此**
  （RotaAssist 会融合 APL 与 AI），但**不应该长时间指向一个正在冷却的技能**
- ✅ 推荐在你施法后**很快**更新（大约一个 GCD 内），没有肉眼可见的长时间冻结
- ✅ 前瞻图标随主图标一起滚动
- ✅ 画面流畅，无周期性卡顿
- ✅ `/ra accuracy` 打印出一段有数字的准确率历史（不是空的、不是全 0）

**如果失败请记录 / If it fails, record**

- **主图标和 Blizzard 高亮不一致时**：两边分别是什么技能、当时资源大概多少、
  是否在爆发中。**能截图最好。**
- **推荐卡住时**：卡了多久、卡在哪个技能、之后是自己恢复还是要 `/reload`
- **卡顿时**：`/dump GetAddOnMemoryUsage("RotaAssist")` 的值，以及是否用了大量铭牌
- **准确率为空 / 恒 0 时**：整段 `/ra accuracy` 输出原文

---

## 7. 进出战斗 · CD 面板倒计时 / Combat Transitions（1 分钟）⭐

v1.1.0 把冷却面板的数据源换掉了，并补了一个 1 秒 ticker 专门修
「**脱战后倒计时冻结**」这个 bug。这一节就是验证它。

**操作 / Do**

1. 确认 CD 面板可见（`/ra config` → Cooldowns）
2. 打木桩，**交掉一个长 CD**（例如 Havoc 的 Metamorphosis / The Hunt）
3. **脱离战斗**（停手等脱战，或走开）
4. **盯着 CD 面板的倒计时数字看 10 秒**
5. 再次进入战斗，再看 10 秒

**预期结果 / Expected**

- ✅ **脱战状态下，倒计时数字每秒都在减少** —— 这是本节的核心
- ✅ 冷却转圈（radial swipe）在动，**不是恒定满圈或空圈**
- ✅ 重新进战斗后倒计时继续正常走
- ✅ 技能 CD 好了以后，图标从面板消失或恢复高亮

**如果失败请记录 / If it fails, record**

- 冻结发生在**脱战瞬间**还是**脱战几秒后**
- 冻结时数字停在多少；重新进战斗后它是**跳到正确值**还是**从冻结值继续**
- 转圈和数字是**同时**冻结还是只冻一个
- 面板是否可见（不可见时 ticker 本来就不刷新，属预期行为）

---

## 8. `/reload` 持久化 / Persistence（30 秒）

**操作 / Do**

1. 把主界面**拖到一个明显的位置**（例如屏幕左上角）
2. 改一个设置（例如把缩放调到 125%，或关掉 Phase Indicator）
3. `/reload`
4. 完全**退出游戏再重进**，再看一次

**预期结果 / Expected**

- ✅ `/reload` 后主界面**还在你放的位置**，缩放 / 开关保持不变
- ✅ 完整重启客户端后同样保持
- ✅ 无 Lua 错误

**如果失败请记录 / If it fails, record**

- 是**位置**没存住，还是**设置**没存住，还是两者
- 位置是回到了屏幕正中（默认值）还是跑到了别处
- `/reload` 后能保持但**退出游戏后**丢失（说明是 SavedVariables 写盘问题）
- 中途是否用过 `/ra reset`

---

## 9. 专精切换 / Spec Switch（可选，1 分钟）

**操作 / Do**

Havoc → Vengeance → Devourer → 回 Havoc，每次切换后打几个技能。

**预期结果 / Expected**

- ✅ 每次切换都**无 Lua 错误**
- ✅ 主图标在新专精下给出该专精的技能（不是上一个专精的）
- ✅ Devourer 下即使部分 spellID 无效，也**只是少显示建议，不报错**
  （这正是 v1.1.0 的 spellID 存在性防御要保证的）

**如果失败请记录 / If it fails, record**

- 在哪个切换方向上出错、错误全文
- Devourer 下主图标是否长时间空白（空白多久）
- 切回 Havoc 后是否恢复正常

---

## 📋 结果记录模板 / Result Template

复制以下内容填写后回报：

```
客户端版本 GetBuildInfo(): ______
客户端语言: ______
角色专精 / 英雄天赋: ______
测试日期: ______

1. 加载无错          [ ] PASS  [ ] FAIL →
2. 主面板与命令      [ ] PASS  [ ] FAIL →
3. /ra aplcheck
     Havoc     : ______________________
     Vengeance : ______________________
     Devourer  : ______________________
4. Devourer spellID
     442501 → ______________________
     442510 → ______________________
     442525 → ______________________
     198793 (对照) → ______________________
     370965 (对照) → ______________________
5. C_AssistedCombat
     GetNextCastSpell(true) → ______
     IsAvailable()          → ______
6. 木桩 2 分钟       [ ] PASS  [ ] FAIL →
     主图标 vs Blizzard 高亮一致性: ______
     /ra accuracy 输出: ______
7. 进出战斗 CD 倒计时 [ ] PASS  [ ] FAIL →
8. /reload 持久化    [ ] PASS  [ ] FAIL →
9. 专精切换          [ ] PASS  [ ] FAIL  [ ] 跳过

BugSack 错误全文（如有）:
______________________________________
```

---

## 🚦 判定 / Verdict

| 结果 | 含义 |
|---|---|
| 第 1 节失败 | **停止发布。** 加载即报错，其余结果不可信 |
| 第 5 节失败 | **停止发布。** 底层 API 不可用，整个推荐链无意义 |
| 第 3 / 6 / 7 节失败 | **修完再发。** 这些是本版声称修好的东西 |
| 仅第 4 节返回 nil | **可以发布。** Devourer 已标注 experimental，运行时有防御 —— 但请把真实 ID 记下来，作为 v1.1.1 的首要修复 |
| 第 8 / 9 节失败 | **记录并评估。** 视严重程度决定是否阻塞 |

---

*相关文档：完整功能测试见 [`TEST_CHECKLIST.md`](TEST_CHECKLIST.md)；
版本变更见 [`../CHANGELOG.md`](../CHANGELOG.md)。*
