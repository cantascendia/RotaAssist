# Recommendation quality / 推荐质量边界

This document defines what evidence is required before describing RotaAssist as
matching or exceeding an optimal rotation helper. It is not a DPS benchmark result.

## Current evidence

- Havoc APL metadata identifies version `12.0.2`, updated `2026-04-09`.
- The bundled Havoc decision tree identifies generation date `2026-02-28` and
  training accuracy `0.7292`. This is agreement with its training labels, not a
  measurement of damage, current-patch correctness, or performance against Hekili.
- The training pipeline generates synthetic scenarios from priority rules.
  Passing its parser tests does not validate those rules against SimulationCraft.
- Devourer data contains unverified spell IDs. A spell ID existing in the client
  does not establish that it represents the intended ability or specialization.
- APL lookahead estimates future resources, cooldowns and combat windows. Hidden
  combat state, random procs and subsequent player actions can invalidate it.
- Havoc profile selection still matches English `signatureTalentNames` against
  client-localized talent names. On zhCN/jaJP it may fall back to the default APL
  profile. Translated UI text does not establish localized talent-build coverage;
  stable talent IDs and client verification are still needed.
- Agreement with the displayed recommendation is an adherence metric. The
  in-addon accuracy percentage is **not** a damage score or proof of optimal play.

Hekili's maintainers explicitly ended their Retail project with Midnight 12.0
because the API changes prevented them from meeting their design and quality
standards: [upstream announcement](https://github.com/Hekili/hekili).
RotaAssist must be evaluated under the same client constraints; historical Hekili
behavior is a product reference, not a verified current-client baseline.

## Release requirements

1. A standalone ZIP must include its dependencies, resolve every active TOC/XML
   reference, and install into exactly `Interface/AddOns/RotaAssist/`.
2. Unknown, unavailable or protected API values must not become fabricated facts.
   Recommendations must reject passive and unlearned abilities where publicly
   available APIs permit that check.
3. An estimate for the action *after* Blizzard's recommendation must not displace
   that recommendation and then appear as the immediate next action.
4. Repeating the player's habits is not sufficient evidence of good advice.
   Personal-history predictions must not override a more authoritative next action.
5. Empty or unsupported states must clear old recommendations, including after a
   specialization change. Unverified data must have an explicit fallback.
6. Mock tests and package inspection are offline verification. Real loading,
   combat transitions, protected values and rendering require a real client.

## Evidence still required for a performance claim

For each supported specialization and talent build, record the client build,
gear, talents, encounter model, APL revision and SimulationCraft revision. Compare
against an independently sourced reference using the same assumptions and seeds.
Report sample count, uncertainty and damage loss across single-target, multiple
targets, burst, resource starvation, movement and interrupted casts. Do not use
the same priority rules as both generator and ground truth.

Replay a separate held-out set to measure impossible-action rate, delayed major
cooldowns and incorrect resource assumptions. Then verify in-client behavior and
frame time. Keep results by specialization; a Havoc result cannot establish
Vengeance or Devourer quality.

Until these artifacts exist, the accurate description is **a rotation coach with
heuristic lookahead**, not "theoretically optimal" or "better DPS than Hekili".

中文：本轮交付优先解决真实安装与推荐正确性问题。模拟评分、训练准确率、规则语法
通过率和测试数量都不能替代同条件 DPS 对照实验。未经客户端及独立基准验证，
不得宣称理论最优、全专精可用或已超越旧 Hekili。
