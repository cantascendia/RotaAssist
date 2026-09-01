# RotaAssist Eval 集

> 建立于 Round 16（2026-09-01）。依据：手册 §35 / 铁律 #12「无 eval 的 agent 配置改动不得进 main」。

## 为什么这个项目特别需要 eval

本仓库有两类**静默失效**的历史前科 —— CI 绿灯、测试全过、产品坏掉：

1. **APL 条件词汇静默失效**（Round 16 发现）
   `APLEngine.lua:310` 对未识别 token 返回 `pass = false`，
   `parseNumericCondition` 解析失败时返回 `nil,nil` 导致 `pass = true`。
   实测 **76 / 352 条规则（21.6%）行为错误**，25 个测试文件、344 个用例无一发现。

2. **配置文件规则漂移**
   `CLAUDE.md` / `AGENTS.md` 里写的 secret-value 铁则，与代码实际做法长期不一致
   （文档说"用 pcall + issecretvalue"，代码里有 6 处只 pcall 不 issecretvalue）。

单元测试验证**代码做了什么**；eval 验证 **agent 在读了配置后会怎么做**。两者不能互相替代。

## 目录结构

```
evals/
├── README.md
├── golden-trajectories/   # 正向：agent 应该怎么做
├── regression/            # 历史 bug 的回归 case
└── capability/            # 能力扩展 case
```

## 每条 case 必填字段

`id` / `description` / `input` / `expected_steps` / `forbidden_actions` /
`acceptance_criteria` / `priority`（P0/P1/P2）

## 运行

```bash
/cto-eval run          # 全量
/cto-eval run --p0     # 仅 P0
```

## 当前覆盖

| id | 覆盖的规则 | 优先级 |
|---|---|---|
| `001-secret-value-comparison` | CLAUDE.md「先 issecretvalue 再运算」 | P0 |
| `002-apl-condition-vocabulary` | AGENTS.md「只用已实现的 APL 条件词汇」 | P0 |
| `003-dead-code-vs-precise-fix` | 铁律 #11 与 D-013 的边界 | P1 |
