# RotaAssist 本地角色模拟工具 0.1

将自己的浩劫角色天赋、装备、宝石、附魔和物品修正参数带入实际 SimulationCraft，
比较固定参考循环与 5 个自主候选。按单体/5 目标、120/300 秒场景计算 DPS，
先筛选，再用独立随机种子复核。结果只代表这些测试配置，不代表理论最高输出。

## 在这台电脑使用

1. 游戏内使用 [SimulationCraft 插件](https://github.com/simulationcraft/simc-addon) 的 `/simc`，
   将当前角色导出内容保存为 UTF-8 文本文件 `character.simc`。
2. 解压本工具包，将文件拖到 `START.cmd`；也可以将文件放在 `START.cmd` 旁边再双击运行。
3. 打开 `results/<实验指纹>/report.md`，查看各场景 DPS、相对差异及复核结果。
   完整角色指纹、引擎警告、原始模拟 JSON、候选筛选证据保存在同一目录。

本机已存在所需 Python 和固定版 SimC，启动器会在附近目录查找。工具不读取游戏
进程、不上传角色数据、不自动执行游戏技能，也不会替换游戏内插件的推荐策略。
导入时去除名字、服务器和区域；装备、天赋等仍属于本地角色数据。

**目前需要等级 90 的浩劫专精和完整 16 个战斗装备槽。** 其他专精、缺失装备、
未知配置字段会报错；不把不支持的数据悄悄丢弃后继续声称是完整角色模拟。
支持的装备字段以 `scripts/personal_calibration.py` 中 `GEAR_KEYS` 为准。
仅识别常用数值物品修正；新补丁增加的导出字段可能需要适配。
消耗品只采用导出中明确提供的设置，不从示例角色补齐。

## 在其他目录或电脑使用

需要 Python 3.11+（无额外 pip 依赖）和固定版本 SimulationCraft：

- 官方归档：`simc-1210.01.774babd-win64.7z`，位于
  [SimulationCraft nightly downloads](http://downloads.simulationcraft.org/nightly/)。
- 归档 SHA-256：`2b04df41bdf505c59b9e41108efa858039fc40e378233172cd39a3edaaea5d44`。
- `simc.exe` SHA-256：`8c6df94966798cabf6864664c2648de9252e396a5ea90188c115c17c8b5339de`。
- 解压整套发行版并保留 `profiles/MID2/MID2_Demon_Hunter_Havoc.simc`。
  可放在工具包 `engine/` 下，或显式传递路径。工具会验证哈希，版本不匹配即停止。

```powershell
./scripts/run_personal_calibration.ps1 -Profile ./character.simc -Simc 'C:/path/to/simc.exe'
```

工具包不包含第三方模拟器二进制或参考 APL，遵循上游自己的获取和许可方式。
参考 APL 从经哈希核对的官方角色文件提取，参考角色的装备和天赋不会进入你的模拟。
可参考上游 [角色格式](https://github.com/simulationcraft/simc/wiki/Characters) 与
[装备格式](https://github.com/simulationcraft/simc/wiki/Equipment)。

## 如何解释结果

参考循环也是候选比较的基准。自主候选未在每个场景超过保守误差门槛时，报告明确说明
“没有可靠超过参考循环”。筛选依据为各场景相对表现中的最低值，避免只追求某一场景。
三倍双方标准误之和用于保守筛选，并非严格置信区间。

默认 24 次实际模拟：18 次筛选、6 次独立种子复核，均为 2 线程。
这些模拟使用完整内部状态、固定敌人数和固定时长；移动、目标进出范围、临时转火、
队友行为及受限 API 可观测性不在本轮验收范围。模拟器本身的警告也保留在结果中。
本版候选源于 Fel-Scarred 研究；不同英雄天赋仍可作对照实验，但没有跨 build 适用保证。
结果不得自动等同于游戏内可执行、可观测或最优的策略。

`selection.json` 在复核前写入；角色、候选、场景或种子改变会产生不同实验目录。
已有结果只有通过原始文件及角色身份复核后才会复用。首次或不同配置运行需要数分钟。
