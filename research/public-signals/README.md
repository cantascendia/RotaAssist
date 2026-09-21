# 公开信号与独立首位：rc.6

2026-09-22，Astra 实现。目标是减少对不可读战斗数据和单一官方建议的依赖。
本轮没有恢复 secret 数值，也没有把推测伪装成精确资源。

## 已落地的路径

`C_Spell.IsSpellUsable` 的公开可用性与 `GetSpellPowerCost` 的公开 **minCost**
共同提供资源不等式。例如某个最低费用 40 的技能明确报告资源不足，可以证明
当前资源小于 40；可用则提供资源下界。只接受单一、平坦、适用性明确的费用。
可选额外消耗、免费施法、多资源、百分比费用、持续消耗、secret、错误和冲突
观测均保守处理。每次重建边界；预测不会把这些边界当成精确已知资源。

公开玩家光环补入先发制人 Initiative（391215）、Inertia Trigger（1215159）
与恶魔变形（162264）。缺失返回 nil 时，只有全局和技能级秘密谓词均明确
不受限，且玩家存在、可见，才证明光环不存在。SimC 的三种 Demonsurge
内部标志并非三个独立真实光环，本轮继续保留未知。

`/ra independent on` 开启默认关闭的实验独立首位。规则在当前公开事实下
得出确定结果、动作可用且没有引导时，可以替换官方首位；后续预测从实际
选中的技能推进。主图标显示“实验 / EXP / 実験”，诊断保留原官方建议。
未知、引导状态不明、关闭实验模式时走原队列。`/ra independent off` 关闭。

## 来源及适用边界

API 来源为 Blizzard 客户端生成文档的 Gethe 镜像；本轮检查 live 分支最新提交
`78282522143e25c3540583734fd192c3d69be910`（2026-09-18），各文件哈希见
[sources.json](sources.json)。固定链接：

- [技能 API](https://github.com/Gethe/wow-ui-source/blob/78282522143e25c3540583734fd192c3d69be910/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellDocumentation.lua)
- [费用结构](https://github.com/Gethe/wow-ui-source/blob/78282522143e25c3540583734fd192c3d69be910/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellSharedDocumentation.lua)
- [秘密状态谓词](https://github.com/Gethe/wow-ui-source/blob/78282522143e25c3540583734fd192c3d69be910/Interface/AddOns/Blizzard_APIDocumentationGenerated/SecretPredicateAPIDocumentation.lua)
- [光环 API](https://github.com/Gethe/wow-ui-source/blob/78282522143e25c3540583734fd192c3d69be910/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitAuraDocumentation.lua)
- [SimC 恶魔猎手来源](https://github.com/simulationcraft/simc/blob/774babde5ddc7c5fc9f1abb129b473f8a076df70/engine/class_modules/sc_demon_hunter.cpp)

不等式是依据接口语义形成的推断；这些公开信号在当前玩家、具体技能、战斗中
是否可读仍需要客户端验证。被限制时返回未知，不能用离线 mock 证明实际覆盖率。
这不是精确敌人几何、全战况理解，也不是完整天赋/装备建模。

实验策略仍是 rc.5 冻结的 Havoc Fel-Scarred 策略；该策略没有敌人数分支。
现有附近敌人数下界并不等于任意 AoE 的实际命中数。固定配置留出测试仍比
完整信息的 SimC 参考低 1.42%–2.68%；本轮没有新的 DPS 提升结论。
英雄天赋配置匹配不代表同系所有天赋组合均经过验证。

## 验证

646 项 Lua、39 项 Python 测试通过；163 个 addon Lua 文件通过 Lua 5.1 语法检查
（包括内嵌库及未加载数据）。新增 6 个、原独立决策 5 个故障注入均被行为测试
检出。Hypothesis 生成费用/真实资源组合，验证推断边界始终包含真实资源。
端到端用例覆盖独立动作与官方建议不同、后续预测重定基点、未知回退、引导、
切换目标、实验开关和标记。详见 [verification.json](verification.json)。
尚无真实客户端战斗、帧耗时或视觉验收。
