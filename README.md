# RotaAssist

[![WoW Version](https://img.shields.io/badge/WoW-12.1_Midnight-blueviolet)](https://worldofwarcraft.blizzard.com)
[![Interface](https://img.shields.io/badge/Interface-120100-informational)](https://warcraft.wiki.gg/wiki/Interface_number)
[![Version](https://img.shields.io/badge/version-1.1.1--rc.16-orange)](docs/QUALITY_BASELINE.md)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

**RotaAssist** — WoW Midnight 12.1 的循环**教练**插件。
*A rotation **coach** for WoW Midnight 12.1 — not another "next spell" icon.*

> **当前交付：1.1.1-rc.16 本地安装候选包，优先完善浩劫。** 自动识别当前玩家已学主动技能，接入角色 build 快照、公开事实与可选独立决策，
> 尚无插件真机战斗或 DPS 验收，不宣称理论最优或超越 Hekili。目标为 Interface `120100`；
> 客户端兼容性需要实测。推荐评分和“准确率”不是 DPS 百分比。
> 详见 [推荐质量与验收标准](docs/QUALITY_BASELINE.md)。

游戏内自动识别无需个人导出或外部模拟：切换专精、天赋和目标后刷新技能与距离观测，
明确超距的技能会从推荐中移除。不同技能分别记录可选敌人数下界；该数量不等于 AoE 命中数。
这套采集与过滤面向各专精，但全专精独立伤害模型尚未完成。详见 [rc.10 说明](docs/RELEASE_1.1.1-rc.10.md)。

rc.16 加入策略分歧的区间见证，并提供独立的精确收益上界验证器。证明范围明确区分
策略一致性、给定模型最优与真实游戏验收；没有新增最高 DPS 宣称。详见
[推导与证据报告](research/optimality-evidence/README.md) 和 [rc.16 说明](docs/RELEASE_1.1.1-rc.16.md)。

rc.15 加入公共冷却末尾的下一动作规划，受玩家队列窗口和 400 毫秒上限约束；
技能冷却、充能、Buff 与恶魔涌动过期时间均参与判断。独立主提示需 `/ra independent on`
启用，尚无实战 DPS 验收。详见 [rc.15 说明](docs/RELEASE_1.1.1-rc.15.md)。

rc.14 补齐深渊凝视与眼棱的技能识别、冷却和天赋状态转移；多目标优先级试验未证明
超过旧策略，因此保持现有策略。详见 [rc.14 说明](docs/RELEASE_1.1.1-rc.14.md)。

rc.13 修复玩家周围范围技能因没有原生目标射程结果而无法确定的问题，使用当前目标的
公开近战证据，转火后重新判断。移动和增援模拟揭示现有策略仍有明显差距，尚未通过
实战大米、团本最高输出验收。详见 [rc.13 说明](docs/RELEASE_1.1.1-rc.13.md)。

rc.12 新增奥达奇独立策略，按完整英雄天赋证据自动选择；修复掠夺者战刃被误当作未学会、
变身后的歼灭导致近战探针失效的问题。六个独立模拟场景达到参考循环的 96.35%–97.27%，
仍未达到最高输出；独立主提示维持实验选项，默认关闭。
详见 [rc.12 说明](docs/RELEASE_1.1.1-rc.12.md)。

rc.11 为浩劫魔痕加入恶魔涌动强化追踪：根据已选天赋、成功施法和公开变身状态，
区分歼灭、死亡横扫和献祭光环的强化是否已消耗。独立策略可使用这些带有效期的模型值，
证据不足时保留未知。四场 SimC 轨迹已回放核对，尚无实战 DPS 验收。
详见 [rc.11 说明](docs/RELEASE_1.1.1-rc.11.md)。

[本地角色模拟工具 0.1](docs/PERSONAL_CALIBRATION_README.md) 是可选的离线研究工具，
不作为安装、自动识别或使用插件的前提，也不自动采用未经实战验证的候选策略。

> RotaAssist 显示 Assisted Combat 的建议，并提供估算的后续动作、
> 建议跟随率、战斗阶段提示与开怪前检查。后续动作会随状态改变，不是固定连招。
>
> *Assisted Combat recommendations, estimated lookahead, adherence feedback,
> combat context and pre-pull checks.*

---

## ✨ Features / 功能亮点

| Feature | Description |
|---------|-------------|
| 🔭 **Multi-Step Lookahead** | 支持的 APL 提供后续动作估算；实际可用步数取决于数据和状态 |
| 📊 **Accuracy Tracking** | 实时 + 历史建议跟随率，按战斗阶段拆分；不代表 DPS 最优程度 |
| 🎯 **Combat Phase Context** | 12 种阶段自动识别（爆发 / AoE / 斩杀 / 紧急 …），只用非 secret 信号 |
| 🧪 **Pre-Pull Checklist** | 开怪前检查合剂、食物、符文，进战前就提醒 |
| 🧠 **Prediction Research** | 保留决策树与马尔可夫研究模块；未校准的学习结果不进入动作队列 |
| ⚡ **Recommendations** | Blizzard 当前建议 + 支持专精的 APL 前瞻；防御和冷却另外提示 |
| 🔔 **Interrupt & Defensive Alerts** | 12.x 合规的打断提醒与防御建议（声音 + 视觉闪烁） |
| 🧩 **CooldownViewer Coexistence** | 可选钩子（CDMHook），避免与 12.x 原生 CD 查看器双份显示 |
| 🌏 **Trilingual** | 英文 / 简体中文 / 日本語，全 UI 本地化 |

## 🛡️ Midnight 12.x Compliance / 合规说明

RotaAssist 的设计约束是只使用官方 API，不使用 secret value 做条件判断。
离线回归覆盖已知边界；完整客户端行为仍待实测。

- 默认建议链路使用 `C_AssistedCombat`；显式实验模式可采用独立首位
- 可能返回 secret 的读取（`UnitPower` / `GetSpellCooldown` / `UnitHealth` …）
  应遵循 `pcall → issecretvalue → 类型检查 → 兜底` 模板
- APL 是**前向模拟器**，读的是模拟状态而非实时受限 API
- 预测特征来自允许访问的技能历史、铭牌数量、战斗时长与专精；未知状态需降级
- 无内存读取、无自动化、无按键注入

## 🎮 Supported Classes / 支持职业

本轮只对 Demon Hunter 数据进行发布候选验证，其他专精不承诺多步预测。

| Class | Specialization | specID | Status |
|-------|---------------|--------|--------|
| Demon Hunter | Havoc | 577 | Candidate：待客户端与 DPS 验收 |
| Demon Hunter | Vengeance | 581 | Candidate：待客户端与 DPS 验收 |
| Demon Hunter | Devourer | 1480 | Blizzard-only；未核实的 APL 预测停用 |

Havoc 英雄天赋配置改用数字天赋技能 ID 识别，避免依赖英文名称；离线语言测试
不能替代实际客户端验收。默认主动作仍以有效的 Blizzard 建议为准。
`/ra independent on` 可开启 Havoc Fel-Scarred 实验独立首位；`/ra independent off`
关闭。实验首位显示“实验”标记，未知状态回退。该策略尚未通过 DPS 性能验收，
`/ra build` 查看天赋、装备与属性读取情况。详见 [rc.8 说明](docs/RELEASE_1.1.1-rc.8.md)。

> ⚠️ **Devourer 说明**：该专精的部分 spellID 基于早期资料整理，尚未在 12.1 真机逐个核验。
> spellID 存在性检查无法证明技能身份正确，也不能替代真实客户端验证。
> 用 `/ra aplcheck` 可以查看 APL 条件校验诊断。
> 反馈时请附上客户端版本和实际 spellID。
>
> *Devourer spellIDs come from early data and are not yet verified on live 12.1.
> ID existence alone does not establish ability identity or rotation quality.*

**其余 17 个专精的数据文件仍在仓库中孵化，已从 TOC 加载列表移除，运行时不加载。**
未加载的数据不构成支持承诺。已加载的数据仍需按专精分别验证。

*The other 17 specs remain in the tree as incubating data but are commented out of the
TOC load order. Loaded data still requires per-specialization validation.*

## 📦 Installation / 安装

本轮按用户选择交付本地 ZIP。尚未提供经验证的 CurseForge/Wago 公共下载入口，
也不承诺自动更新。

### Manual / 手动安装
1. 获取本次交付的 `RotaAssist-1.1.1-rc.16.zip`；源码 ZIP 不能替代带依赖的安装包
2. 解压到
   `World of Warcraft/_retail_/Interface/AddOns/`
   解压后应存在 `Interface/AddOns/RotaAssist/RotaAssist.toc`
3. 重启 WoW，在角色选择页启用 RotaAssist；后续更新可在游戏内 `/reload`
4. 首次进游戏后建议跑一遍 [`docs/SMOKE_TEST_12.1.md`](docs/SMOKE_TEST_12.1.md)

> 依赖：无强制依赖。Ace3 已内嵌（`OptionalDeps`），单独装了也不冲突。

## 🖥️ Screenshots

> Screenshots will be added after the first public release.
> 截图将在首次公开发布后补充。

<!-- ![Main Display](docs/screenshots/main_display.png) -->
<!-- ![Phase Indicator](docs/screenshots/phase_indicator.png) -->
<!-- ![Accuracy Meter](docs/screenshots/accuracy_meter.png) -->
<!-- ![Pre-Pull Panel](docs/screenshots/prepull_panel.png) -->

## ⌨️ Slash Commands

| Command | Description |
|---------|-------------|
| `/ra` / `/ra help` | 打印命令列表 / Print the command list |
| `/ra toggle` | 显示 / 隐藏主界面 |
| `/ra config` | 打开设置面板 |
| `/ra build` | 查看角色配置、装备完整性、属性与天赋导入字符串 |
| `/ra independent on\|off` | 开关实验独立首位；默认关闭，尚未通过 DPS 验收 |
| `/ra lock` | 锁定 / 解锁显示位置 |
| `/ra accuracy` | 打印准确率历史 |
| `/ra aplcheck` | **APL 条件校验诊断** — 列出使用了不受支持 token、永远不会触发的规则 |
| `/ra debug` | 切换调试模式 |
| `/ra reset` | 重置所有设置为默认值 |
| `/ra version` | 显示版本信息 |

> `/ra aplcheck` 是 v1.1.0 新增的诚实性工具：以前未识别的 APL 条件会**静默失效**，
> 现在它们在加载期就被记录下来并可查。DH 三专精的预期输出是 **0 条**。

## ⚙️ Configuration

右键主界面可以快速调整 / Right-click the main display for quick settings:
- **Lock/Unlock** position
- **Combat-only** mode
- **Phase Indicator** toggle
- **Accuracy Meter** toggle
- **Scale** adjustment (75% – 150%)

完整选项在 `/ra config`，含冷却面板、打断提醒、防御建议、开怪前检查的独立开关。

## 🐞 Bug Reports & Feedback / 反馈

当前通过交付渠道回报问题，请附上：

- WoW 客户端版本（`/dump GetBuildInfo()`）
- 专精与英雄天赋
- Lua 错误全文（建议装 **BugSack + BugGrabber**）
- 复现步骤

*Please report issues through the delivery channel. Include client version,
spec, the full Lua error (BugSack recommended), and repro steps.*

## 🔬 Training Pipeline (Developer Only)

`training/` 目录包含生成决策树与马尔可夫矩阵数据文件的 Python 脚本。
**玩家永远不需要运行 Python。**

See [`training/README.md`](training/README.md) for full instructions.

```bash
pip install -r training/requirements.txt
python training/simc_apl_to_dataset.py --spec havoc --output data/havoc.csv
python training/train_decision_tree.py --input data/havoc.csv \
  --output-lua addon/Data/DecisionTrees/DH_Havoc_DT.lua \
  --output-markov addon/Data/TransitionMatrix/DH_Havoc_TM.lua --spec-id 577
```

## 📦 Packaging a Release / 打包发布

```powershell
# Windows / PowerShell 5.1+
powershell -ExecutionPolicy Bypass -File scripts\package_release.ps1
```

```bash
# POSIX (requires `zip`)
./scripts/package.sh
```

`package_release.ps1` 需要开发机安装 Python 3 和 Lua 5.1，并准备好内嵌依赖
（来源与限制见 [DEPENDENCIES.md](docs/DEPENDENCIES.md)）。它递归校验 TOC/XML、
执行离线加载检查、写入逐文件 SHA-256 清单，并输出
`dist/<version>/RotaAssist-<version>.zip` 和 `.sha256`。检查失败时以非零码退出。

## 📚 Docs

| 文档 | 内容 |
|---|---|
| [`docs/SMOKE_TEST_12.1.md`](docs/SMOKE_TEST_12.1.md) | 10 分钟真机冒烟清单（12.1 客户端） |
| [`docs/TEST_CHECKLIST.md`](docs/TEST_CHECKLIST.md) | 完整功能测试清单 |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | 架构说明 |
| [`docs/API_REFERENCE.md`](docs/API_REFERENCE.md) | 模块 API 参考 |
| [`CHANGELOG.md`](CHANGELOG.md) | 版本变更记录 |

## 📜 License

[MIT License](LICENSE)

## 🙏 Acknowledgments

- **Blizzard Entertainment** — C_AssistedCombat API
- **SimulationCraft** — APL reference data
- **Ace3 Libraries** — AceAddon, AceDB, AceEvent, AceLocale, AceTimer
- 以及每一个愿意在评论区回报 Devourer spellID 的玩家
