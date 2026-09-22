<p align="center">
  <img src="docs/assets/hero.svg" alt="RotaAssist — 看懂战况，把握下一步。浩劫优先的 WoW 循环教练；图片为概念示意。" width="100%" />
</p>

<p align="center">
  <strong>少一点盯技能栏，多一点掌控战斗。</strong><br />
  为 WoW Midnight 打造的循环教练：下一步技能、动态前瞻、战斗提醒，在你需要的位置。
</p>

<p align="center">
  <a href="https://github.com/cantascendia/RotaAssist/releases/download/1.1.1-rc.17/RotaAssist-1.1.1-rc.17.zip"><img alt="下载测试版 1.1.1-rc.17" src="https://img.shields.io/badge/下载测试版-1.1.1--rc.17-b8ff83?style=for-the-badge&amp;labelColor=171321" /></a>
  <img alt="目标客户端 Midnight 12.1" src="https://img.shields.io/badge/Midnight-12.1-a777ed?style=for-the-badge&amp;labelColor=171321" />
  <a href="LICENSE"><img alt="MIT License" src="https://img.shields.io/badge/License-MIT-ccc4da?style=for-the-badge&amp;labelColor=171321" /></a>
</p>

<p align="center">
  简体中文 · <a href="README.en.md">English</a><br />
  <a href="#三步开始">快速安装</a> · <a href="https://github.com/cantascendia/RotaAssist/releases/tag/1.1.1-rc.17">版本说明</a> · <a href="https://github.com/cantascendia/RotaAssist/issues">反馈问题</a>
</p>

> **抢先体验 · 浩劫优先。** 当前是可安装的测试版本。默认结合 Blizzard Assisted Combat 与插件前瞻；独立推荐需主动开启。真实大米／团本验收尚未完成，不保证最高 DPS。界面图均为示意，不是真机截图。

## 战况会变，下一步也应该跟着变

转火了，爆发窗口到了，目标跑出近战范围了——你需要的是清楚的下一步提示。

RotaAssist 将**当前角色配置、可公开读取的战斗状态和技能历史**带进推荐流程。大图标告诉你下一步，小图标展示可能的后续动作；状态变化时，预测会随之更新。

| 你在意的事 | RotaAssist 怎么帮忙 |
| :--- | :--- |
| **换天赋后，提示能不能跟上？** | 按事件刷新天赋、装备、属性和已学技能；浩劫实验策略识别魔痕／奥达奇英雄天赋。 |
| **转火或目标跑远了呢？** | 更新当前目标、公开距离信息及附近敌人数下界；无法确认的状态保留为未知。 |
| **想提前准备下一次按键。** | 支持的 APL 提供多步前瞻，默认显示两个预测位置；它们是会变化的预测，不是固定连招。 |
| **打本时不想满屏都是提示。** | 一键“实战专注”，保留推荐、资源和安全提醒，收起学习面板。 |
| **我也想知道自己有没有跟上节奏。** | “学习视图”补充阶段提示、开怪前检查、冷却面板和建议跟随率。 |

**玩家无需运行 Python、训练模型或导出角色数据，便可安装并使用插件。** 研究工具与日常使用分开。

## 两种视图，适合不同的战斗节奏

<p align="center"><img src="docs/assets/experience.svg" alt="实战专注保留核心提示；学习视图增加阶段、开怪检查和跟随反馈。图为布局示意。" width="100%" /></p>

### ⚔️ 实战专注

把目光留给场上。下一步技能更醒目，默认即时切换纹理；超距同时有文字与颜色提示。原生动作栏的翻页、扩展栏和技能替换会触发按键提示重新解析。

### 🔮 学习视图

练习循环时展开更多信息：观察战斗阶段、检查开怪准备、查看冷却和建议跟随率。**跟随率衡量是否遵循推荐，不是 DPS 成绩。** 两种视图都可以继续自定义位置、大小、音效与显示项。

界面支持 **English · 简体中文 · 日本語**。详细变化见 [体验审计](docs/ux-readiness.md)；[交互式布局示意](docs/ux-preview.html) 下载后用浏览器打开。

## 三步开始

### 1 · 下载安装包

**[下载 RotaAssist 1.1.1-rc.17 ZIP →](https://github.com/cantascendia/RotaAssist/releases/download/1.1.1-rc.17/RotaAssist-1.1.1-rc.17.zip)**

选择 Release 中的 **RotaAssist-1.1.1-rc.17.zip**，不是 GitHub 自动生成的 Source code。依赖库已内置，无需额外安装。

### 2 · 放进正式服插件目录

退出游戏，将 ZIP 内整个 **RotaAssist** 文件夹解压到：

<pre>World of Warcraft/
└── _retail_/Interface/AddOns/
    └── RotaAssist/
        └── RotaAssist.toc</pre>

升级前可把旧版目录备份到 AddOns 之外，保留角色设置。目标客户端为 **Midnight 12.1 / Interface 120100**。

### 3 · 选好视图，先打一轮假人

在角色选择页启用插件。进入游戏后输入 <code>/ra config</code>，选择 **实战专注** 或 **学习视图**。用 <code>/ra lock</code> 切换拖动锁定，把主条移到舒服的位置。

先检查按键、目标切换与天赋替换，再带进副本。完整步骤见 [安装与首次使用](docs/USER_QUICK_START.md)。

## 浩劫先做好，再走得更远

| 专精 | 当前范围 |
| :--- | :--- |
| **浩劫 Havoc** | 主要研发与验证对象；角色配置、公开战况、多步前瞻；魔痕和奥达奇有可选实验独立策略。 |
| 复仇 Vengeance | 已加载候选数据，仍需专项实战验证。 |
| Devourer | 仅 Blizzard 建议路径；未核实的 APL 预测停用。 |
| 其他专精 | 仓库中的研究数据不代表已提供完整支持。 |

想参与独立策略测试，可用 <code>/ra independent on</code> 开启、<code>/ra independent off</code> 关闭。实验首位会显示“实验”标记；证据不足时回退。**建议初次体验保持默认模式。**

<details>
<summary><strong>推荐依据与测试范围：我们验证了什么？</strong></summary>

这版通过了 **787 条 Lua、131 条 Python 测试**，完成 **172 个 Lua 文件语法检查**；**19 个故意损坏行为的变异**全部被测试拒绝。安装包还经过加载顺序、目录结构与逐文件 SHA-256 校验。这些都是离线工程验证。

实战最高输出还需要完整伤害／状态转移模型、动态搜索与真实副本对照，当前尚未完成。现有固定 build 的独立策略离线对照仍落后于完整参考循环。

- 附近敌人数是公开观测下界，不等于全场精确数量，也不保证每个 AoE 的实际命中数。
- 受限信息保留为未知；插件不读取游戏内存、不注入按键、不自动施法。
- 条件宏、第三方动作栏、全部天赋组合与实战帧率仍需要进一步兼容性验证。

[验证记录](research/combat-ux/verification.json) · [推荐质量标准](docs/QUALITY_BASELINE.md) · [最优性推导与证据](research/optimality-evidence/README.md)

</details>

## 常用命令

| 命令 | 用途 |
| :--- | :--- |
| <code>/ra config</code> | 打开设置，切换显示方案 |
| <code>/ra lock</code> | 锁定／解锁位置 |
| <code>/ra toggle</code> | 显示／隐藏主界面 |
| <code>/ra build</code> | 查看角色配置读取情况 |
| <code>/ra capture on</code> · <code>/ra capture off</code> | 开始／停止本地公开决策采样，帮助定位问题 |
| <code>/ra version</code> | 确认版本 |

采样默认关闭，最多保留最近 1200 个事件；停止后 <code>/reload</code> 或正常退出以保存。开始新采样会覆盖上一份。它不是完整战斗日志或 DPS 测量。[更多使用说明](docs/USER_QUICK_START.md)

## 一起把它打磨成你愿意常驻的插件

出现错误按键、提示跳变或漏推荐？**[提交一个 Issue →](https://github.com/cantascendia/RotaAssist/issues/new)** 附上版本、专精／英雄天赋、复现步骤和 Lua 错误。真实场景反馈比“感觉变强了”更能帮助改进。

如果这正是你想要的循环教练，欢迎 **Star** 收藏，并在 [Releases](https://github.com/cantascendia/RotaAssist/releases) 关注后续版本。

<details>
<summary><strong>开发者入口</strong></summary>

Lua 5.1 插件 + Python 研究工具。普通玩家不需要开发环境。

<pre>&amp; 'C:\Program Files (x86)\Lua\5.1\lua.exe' scripts/run_tests.lua
python -m pytest tests training/test_apl_parser.py -q
&amp; scripts/package_release.ps1</pre>

[架构](docs/ARCHITECTURE.md) · [API](docs/API_REFERENCE.md) · [依赖来源](docs/DEPENDENCIES.md) · [训练工具](training/README.md) · [更新日志](CHANGELOG.md)

</details>

---

<p align="center">开源 · <a href="LICENSE">MIT</a> · 感谢 Blizzard 的公开 API、SimulationCraft 与 Ace3。<br /><sub>独立社区项目，与 Blizzard Entertainment 无隶属或背书关系。World of Warcraft 为其所属权利人的商标。</sub></p>
