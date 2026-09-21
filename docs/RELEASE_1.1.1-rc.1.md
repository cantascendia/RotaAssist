# RotaAssist 1.1.1-rc.1 本地交付

这是安装候选版，目标客户端为 WoW Midnight Interface `120100`。
本轮按用户选择交付本地安装包，没有发布 CurseForge/Wago/GitLab Release。

## 安装

1. 完全退出 WoW。保留旧版 `RotaAssist` 文件夹作为备份。
2. 解压 `RotaAssist-1.1.1-rc.1.zip` 到正式服的 `Interface/AddOns/`。
3. 确认路径为 `Interface/AddOns/RotaAssist/RotaAssist.toc`，不能再套一层目录。
4. 在角色选择页启用插件，进入游戏后输入 `/ra version` 核对版本。
5. `/ra config` 打开设置，`/ra toggle` 显示或隐藏界面。

如果没有主技能图标，先确认已选择专精、选中可攻击目标，并且该客户端/角色能获得
Blizzard Assisted Combat 建议。未知或不可用状态下的空队列不等于“建议按上一次技能”。
`/ra aplcheck` 只能诊断规则语法和技能解析情况，不能验证实际 DPS。

玩家不需要安装 Python、Lua、Ace3 或开发工具；运行依赖随 ZIP 提供。
保留 `WTF` 中的 SavedVariables 即可保留已有设置。回退时退出游戏，将本版
插件目录移到 AddOns 以外，再把旧版备份放回 `AddOns/RotaAssist`。

## 推荐行为

当前有效的 Blizzard 建议作为主动作；有可用 APL 的专精提供估算的后续动作。
未核实的 Devourer 预测数据停用，使用 Blizzard-only 模式。其他未提供 APL
的专精也不承诺多步前瞻。没有有效建议时不应继续展示上一次的技能。

未经独立校准的决策树和个人施法习惯不用于填充动作队列。“准确率”是对显示
建议的跟随程度，不代表达到理论最大 DPS。

已知限制：Havoc 英雄天赋配置仍按英文名称匹配，中文/日文客户端可能退回默认
APL 配置。界面翻译已提供，但这不等于对应天赋配置已完成客户端适配。

## 验证边界

本地检查覆盖 Lua 回归、语法、打包依赖与安装过程。客户端真实加载、视觉效果、
进战后的受限值、木桩输出和副本行为不能由这些离线检查替代。

本轮已验证：Windows PowerShell 5.1 新装和覆盖安装；覆盖安装保留旧目录；
损坏文件、缺少嵌套依赖、路径越界和 XML 循环引用的包均在修改目标目录前拒绝。
四项定向引擎故障注入均被回归测试检出；这不是全项目 mutation coverage。

本机检查发现 `_retail_` 下没有 `Wow.exe`，只有旧插件等残留文件，因此本轮
没有进行真实客户端验收，也没有建立独立 SimulationCraft DPS 基准。
不得把本候选版描述为“已达到理论最优”或“已经超越 Hekili”。

详细依据见 [推荐质量标准](QUALITY_BASELINE.md)。已有
[客户端冒烟步骤](SMOKE_TEST_12.1.md) 仍可作为测试清单；其中旧版 Devourer
实验预测的预期应以本页的 Blizzard-only 行为为准。
