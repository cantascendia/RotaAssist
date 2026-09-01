# RotaAssist

[![WoW Version](https://img.shields.io/badge/WoW-12.1_Midnight-blueviolet)](https://worldofwarcraft.blizzard.com)
[![Interface](https://img.shields.io/badge/Interface-120100-informational)](https://warcraft.wiki.gg/wiki/Interface_number)
[![Version](https://img.shields.io/badge/version-1.1.0-blue)](CHANGELOG.md)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

**RotaAssist** — WoW Midnight 12.1 的循环**教练**插件。
*A rotation **coach** for WoW Midnight 12.1 — not another "next spell" icon.*

> Blizzard 的 Assisted Combat 已经免费告诉你「下一个按什么」。
> RotaAssist 做 Blizzard **不做**的那部分：**接下来 3–5 个**、**你打得准不准**、
> **现在是什么战斗阶段**、**开怪前你少了什么**。
>
> *Blizzard already tells you the next button. RotaAssist tells you the next **five**,
> how accurate you actually were, and what phase the fight is in.*

---

## ✨ Features / 功能亮点

| Feature | Description |
|---------|-------------|
| 🔭 **Multi-Step Lookahead** | 不只是下一个技能——前瞻 3–5 步，让你能规划而非反应 |
| 📊 **Accuracy Tracking** | 实时 + 历史准确率，按战斗阶段拆分，告诉你哪里偏了 |
| 🎯 **Combat Phase Context** | 12 种阶段自动识别（爆发 / AoE / 斩杀 / 紧急 …），只用非 secret 信号 |
| 🧪 **Pre-Pull Checklist** | 开怪前检查合剂、食物、符文，进战前就提醒 |
| 🧠 **AI Prediction** | 决策树 + 马尔可夫链，按**你自己**的施法历史个性化学习 |
| ⚡ **Multi-Source Fusion** | 融合 Blizzard C_AssistedCombat + APL 模拟 + AI，加权成一条建议 |
| 🔔 **Interrupt & Defensive Alerts** | 12.x 合规的打断提醒与防御建议（声音 + 视觉闪烁） |
| 🧩 **CooldownViewer Coexistence** | 可选钩子（CDMHook），避免与 12.x 原生 CD 查看器双份显示 |
| 🌏 **Trilingual** | 英文 / 简体中文 / 日本語，全 UI 本地化 |

## 🛡️ Midnight 12.x Compliance / 合规说明

RotaAssist 只使用 Blizzard 官方 API，**不读取 secret value 做战斗决策**。

- 建议链路建立在官方 `C_AssistedCombat` 之上
- 全部可能返回 secret 的读取（`UnitPower` / `GetSpellCooldown` / `UnitHealth` …）
  统一走 `pcall → issecretvalue → 类型检查 → 兜底` 模板
- APL 是**前向模拟器**，读的是模拟状态而非实时受限 API
- ML 特征集 100% 由非 secret 数据组成（技能历史 / 铭牌数量 / 战斗时长 / 专精）
- 无内存读取、无自动化、无按键注入

## 🎮 Supported Classes / 支持职业

v1.1.0 **只发布 Demon Hunter 三专精**，且只发布真正可用的部分。

| Class | Specialization | specID | Status |
|-------|---------------|--------|--------|
| Demon Hunter | Havoc | 577 | ✅ Supported |
| Demon Hunter | Vengeance | 581 | ✅ Supported |
| Demon Hunter | Devourer | 1480 | ⚠️ **Experimental** |

> ⚠️ **Devourer 说明**：该专精的部分 spellID 基于早期资料整理，尚未在 12.1 真机逐个核验。
> 插件在运行时对不存在的 spellID 有存在性防御（不会报错，只是该建议不显示）。
> 用 `/ra aplcheck` 可以查看 APL 条件校验诊断。
> 欢迎在 CurseForge 评论区回报实际 spellID。
>
> *Devourer spellIDs come from early data and are not yet verified on live 12.1.
> Runtime guards keep unknown IDs from erroring. Reports welcome in the CurseForge comments.*

**其余 17 个专精的数据文件仍在仓库中孵化，已从 TOC 加载列表移除，运行时不加载。**
诚实版本：与其声称支持 20 个专精而其中一半的规则是死的，不如把 3 个专精做到无可挑剔。
宽度可以后补，信誉不能。

*The other 17 specs remain in the tree as incubating data but are commented out of the
TOC load order, so nothing loads them at runtime. Three specs done right beats twenty
specs half-broken.*

## 📦 Installation / 安装

### CurseForge App (Recommended / 推荐)
1. 在 CurseForge App 中搜索 **RotaAssist** 并安装
2. 完成，插件会自动更新

### Manual / 手动安装
1. 从 CurseForge 或 Wago 的 **Files** 页下载 `RotaAssist-1.1.0.zip`
2. 解压到
   `World of Warcraft/_retail_/Interface/AddOns/`
   解压后应存在 `Interface/AddOns/RotaAssist/RotaAssist.toc`
3. 重启 WoW，或在游戏内 `/reload`
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

请在 **CurseForge 的插件评论区**（Comments 标签页）回报问题。
回报时请附上：

- WoW 客户端版本（`/dump GetBuildInfo()`）
- 专精与英雄天赋
- Lua 错误全文（建议装 **BugSack + BugGrabber**）
- 复现步骤

*Please report issues in the CurseForge comment section. Include client version,
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

`package_release.ps1` 会做发布前检查（TOC 存在、`## Interface: 120100`、无开发残留），
并输出 `RotaAssist-<version>.zip` 及大小 / 文件数摘要。检查失败时以非零码退出。

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
