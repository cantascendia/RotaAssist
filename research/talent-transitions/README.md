# 天赋驱动的施法后状态 — rc.9

这一版将 rc.8 的天赋识别接入浩劫 APL 状态转移。相同的当前技能和冷却，
会因为是否选择相关天赋而得到不同的后续动作；不是只改变 build 标签。

## 固定来源

SimulationCraft commit `774babde5ddc7c5fc9f1abb129b473f8a076df70`，
游戏数据 `12.1.0.69875`。本地 SHA-256 已核对：

- [职业实现](https://github.com/simulationcraft/simc/blob/774babde5ddc7c5fc9f1abb129b473f8a076df70/engine/class_modules/sc_demon_hunter.cpp)：
  `1a6483f99714e99d6bde7c073dc62e43fa7caf4ee82e411f3fe737b77b6979cc`。
  5008–5012 行按混乱变身重置眼棱/刃舞；4057–4062 行额外延长眼棱引导时长；
  9162–9182 行追加魔化时长；12643–12648 行要求已选魔化天赋。
- [天赋表](https://github.com/simulationcraft/simc/blob/774babde5ddc7c5fc9f1abb129b473f8a076df70/engine/dbc/generated/trait_data.inc)：
  `2796785843aa83468a85ba2bd8ab2ab4624e56c8255d0c5a02a067eb91b95c62`。
  Demonic 213410、Chaotic Transformation 388112。
- [技能数据](https://github.com/simulationcraft/simc/blob/774babde5ddc7c5fc9f1abb129b473f8a076df70/engine/dbc/generated/sc_spell_data.inc)：
  `08e0d4f057fd83c02fa200a851497ed6a529104580082ffd3942a273429e21b7`。
  44664 行效果 316557 为 5000 毫秒；5568 行光环 162264 基础时长 20000 毫秒。

## 实现和边界

已选魔化：模拟眼棱至少增加 5 秒变身，已有窗口相加。额外引导时长尚未模拟，
所以最低时长到期后变为未知，不假定已回到普通形态。明确未选魔化时不制造变身。
主动变身采用 20 秒基础时长；原有时长不可知时，合计时长仍按下界处理。

已选混乱变身：主动变身在模拟状态中重置眼棱、刃舞和死亡横扫的共享冷却。
未选时保留冷却；天赋未知时，非就绪的冷却变为未知，已经确定就绪的技能仍就绪。
不改真实游戏冷却，不推断秘密值。其他专精维持原有行为。

模拟用时长与冷却更新已进入真实 `APLEngine:PredictNext`，测试证明其改变下一动作，
并且不修改传入的当前状态。角色配置变化会清除旧的施法计时变身估计。
当前光环观测仍优先于计时估计；后者不是秘密光环的替代读取。

## 验证

- 全量 677 项 Lua、80 项 Python（包括训练解析器）通过。
- 新增 11 项 Lua 行为用例和 50 组生成式冷却/时长不变量。
- 7 个行为变异全部被测试拒绝；166 个插件 Lua 文件通过语法检查。
- 变异原始输出位于 `dist/research/talent-transitions/mutations/`。

本轮没有新增 DPS 实测，也没有采集用户实际角色或验证游戏客户端。
暴力变身、碎裂命运、随机触发、完整伤害系数和全量天赋联动仍未完整建模。
独立首位策略保持原样、默认关闭；本次结果不证明最高 DPS 或超越 Hekili。
