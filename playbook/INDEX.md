# Handbook 章节索引（v3.8 起，handbook-search skill 入口）

> 给 Claude 用的查询索引：handbook.md 3986 行不可全读，按本表定位章节后用
> `Read(playbook/handbook.md, offset=L起, limit=N)` 精准读。
>
> 给人用的目录：找文档时直接看本表 → 跳到对应行号。

## 按场景查（最常用）

| 场景 | 该读 | 行号 |
|---|---|---|
| 用户提到 "spec-driven" / "怎么写 spec" | §18 | L1423-1503 |
| 触及 forbidden 路径 (auth/payment/secrets/migration) | §32 / §32.1 | L2495-2578 |
| 触及测试文件，"改测试让它通过" | §20 / §20.3 | L1531-1601 |
| "vibe coding" / "yolo" / "skip tests" 关键词 | §33 红线分级 | L2579-2619 |
| "无 eval 不进 main" / 改 prompt 类文件 | §35 EDD | L2680-2741 |
| 跨模型 review / codex 审 / "第二模型" | §19 + §48 | L1504-1530, L3789-3986 |
| Constitution 起草 / 项目宪法 | §37 | L2812-2889 |
| Hooks 配置 / 自动化 / "怎么设 hook" | §41 | L3150-3308 |
| Sub-agent 设计 / harness-auditor 等 | §39 + §42 | L2963-3069, L3309-3381 |
| Trajectory replay / 调试 / 重放 | §44 | L3472-3570 |
| Canary 部署 / feature flag rollback | §45 | L3571-3646 |
| LLM-as-Judge / CI 双 judge | §47 | L3716-3788 |
| **自我进化飞轮 / "AI 改自己"** | **§50 v3.9** | **L4163-4287** |
| 第零轮启动 / 新项目接入 | §10 + §29 | L882-984, L2133-2274 |

## 按章节号

| § | 标题 | L 起 | L 止（约） |
|---|---|---|---|
| 1 | 环境能力 | 7 | 45 |
| 2 | 产品愿景理解 | 46 | 99 |
| 3 | 代码状态同步机制 | 100 | 143 |
| 4 | 上下文管理 / Context Engineering | 144 | 215 |
| 5 | 工具栈详细规范（Claude/AG/Codex 三平台） | 216 | 655 |
| 6 | 配置文件职责边界 | 656 | 679 |
| 7 | 安全与回退策略 | 680 | 695 |
| 8 | 独立思考职责 | 696 | 783 |
| 9 | 输出格式规范 | 784 | 881 |
| 10 | 第零轮启动序列 | 882 | 984 |
| 11 | 后续每轮流程 | 985 | 1014 |
| 12 | 竞品分析原则 | 1015 | 1025 |
| 13 | 配置迭代原则 | 1026 | 1036 |
| 14 | 决策框架 | 1037 | 1072 |
| 15 | 快捷命令 | 1073 | 1112 |
| 16 | 沟通风格 | 1113 | 1127 |
| 17 | 仓库内记忆持久化 | 1128 | 1422 |
| 18 | Spec-Driven 开发流程 | 1423 | 1503 |
| 19 | 交叉审核与多模型策略 | 1504 | 1530 |
| 20 | TDD 强制流程（含 §20.3 Test-Lock）| 1531 | 1601 |
| 21 | Agent Skills 开放标准与 Skill 生态 | 1602 | 1688 |
| 22 | 社区 Skill 推荐清单 | 1689 | 1745 |
| 23 | CI/CD 流水线 | 1746 | 1836 |
| 24 | 发布管理 | 1837 | 1890 |
| 25 | 可观测性 | 1891 | 1954 |
| 26 | 设计系统 | 1955 | 2026 |
| 27 | 无障碍（Accessibility） | 2027 | 2074 |
| 28 | 隐私合规 | 2075 | 2132 |
| 29 | 新项目集成教程 | 2133 | 2274 |
| 30 | 安全工程基线 | 2385 | 2431 |
| 31 | 性能预算与 SLO | 2432 | 2494 |
| 32 | AI 代码生成的人工审核边界 | 2495 | 2578 |
| 32.1 | Forbidden 路径定义 | 2495 | 2543 |
| 32.5 | 6 大反模式（Vibe Shipping / Yes-man / Hallucination 等） | (in §32) | — |
| 33 | Vibe Coding 红线分级 | 2579 | 2619 |
| 34 | Harness 设计自审（八条原则） | 2620 | 2660 |
| 35 | Eval-Driven Development（EDD） | 2680 | 2741 |
| 36 | Self-Healing 自动修复门禁 | 2742 | 2811 |
| 37 | Constitution 协议（与 Spec Kit 映射） | 2812 | 2889 |
| 38 | Agent Loop 模式（执行循环范式） | 2890 | 2962 |
| 39 | Multi-Agent 编排范式 | 2963 | 3069 |
| 40 | AI Pair Programming 模式 | 3070 | 3149 |
| 41 | Hooks 驱动的自动化 | 3150 | 3308 |
| 42 | Sub-agents 实战 | 3309 | 3381 |
| 43 | Agent Reliability Engineering（ARE） | 3382 | 3471 |
| 44 | Deterministic Agent Replay | 3472 | 3570 |
| 45 | Agent Canary Deployment | 3571 | 3646 |
| 46 | MCP Skill Interoperability Manifest | 3647 | 3715 |
| 47 | Agent-Native CI/CD + LLM-as-Judge | 3716 | 3788 |
| 48 | Cross-Platform Auto-Review Bridge | 3789 | 3986 |
| 50 | 自我进化飞轮（v3.9 — Constitution-Anchored Self-Improvement） | 4163 | 4287 |

## 按铁律 (#1-#14)

铁律全文在 `CLAUDE.md` L17-32。详细解释：

| # | 简称 | 详见 |
|---|---|---|
| 1 | 决策服务产品愿景 | §2, §8 |
| 2 | 不编造不假设 | §32.5 反模式 #3 / §3 |
| 3 | 模型名从 §5 选 | §5.0 / §1.2 |
| 4 | Agent 犯错 → 更新配置 | §13 / §41 |
| 5 | 敢于挑战用户 | §8.4 |
| 6 | 每 3 轮出摘要 + 更新 STATUS | §17.3 |
| 7 | 不过度优化即将重写部分 | §13 |
| 8 | 先创建 Git 分支 | §9.4 + branch-guard.sh |
| 9 | 占位数据不算完成 | §24 |
| 10 | 国际化 / 配置分离 | §28 / §27 |
| 11 | 禁止删除重建替代精确修复 | §32.5 反模式 #4 |
| 12 | 无 eval 的 agent 配置改动不进 main | §35 + eval-gate.sh |
| 13 | Forbidden 路径禁止 vibe coding | §32.1 + forbidden-guard.sh |
| 14 | Test-Lock 不可绕过 | §20.3 + test-lock-guard.sh |

## 按反模式 (§32.5 #1-6)

| # | 反模式 | 防护 |
|---|---|---|
| 1 | Vibe Shipping（不读代码就部署） | §33 + UserPromptSubmit hook |
| 2 | Yes-man AI（顺从用户错误想法） | §8.4 + 铁律 #5 |
| 3 | Hallucination Amplification | §3.1 + 铁律 #2 |
| 4 | Dependency Hallucination | §32.5 + grep 实际依赖 |
| 5 | Context Starvation | §4 + Context Engineering |
| 6 | Eval Gaming（指标对但目标偏） | §35 + property-based test |

## 维护

新增章节时**必须**同步本 INDEX。`/cto-audit` 会校验 handbook 章节数 vs INDEX 条目数一致。
