# Adaptive rotation research — 2026-09-22

The target is the highest expected damage achievable from information the addon
can actually observe, for a specified build and encounter. A working predictor,
a SimulationCraft reference, and an in-game DPS improvement are different results.

## Observable information

Blizzard's [Midnight combat design statement](https://news.blizzard.com/en-us/article/24246290/combat-philosophy-and-addon-disarmament-in-midnight)
explains that protected combat information can be displayed without being
available for addon decision logic. Availability must be checked at runtime;
it is not correct to treat every spell or resource as permanently public or secret.

The generated Blizzard API documentation was inspected from the Gethe source
mirror at commit `78282522143e25c3540583734fd192c3d69be910` (2026-09-18).
This is source evidence, not execution in the user's client.

Havoc talent signatures were checked against SimulationCraft's generated
[trait data](https://github.com/simulationcraft/simc/blob/8ec2d693548ca053d39697983e05a2da5adbe892/engine/dbc/generated/trait_data.inc),
SHA-256 `2796785843aa83468a85ba2bd8ab2ab4624e56c8255d0c5a02a067eb91b95c62`.
Art of the Glaive is spell `442290`, Demonsurge `452402`, and Student of Suffering
`452412`. A spell can occur under multiple trait definitions, so selection uses
the spell ID resolved from the active definition, not one hardcoded definition.

The [spell structure definitions](https://github.com/Gethe/wow-ui-source/blob/78282522143e25c3540583734fd192c3d69be910/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellSharedDocumentation.lua)
also distinguish a held cooldown (`isEnabled=false`) from an inactive cooldown.
They describe `chargeModRate` as a UI update rate; it must not be used to divide
the charge's reported recharge duration. Recharge simulation uses the reported
start time plus duration. These semantics were checked during source review.

| Input | Evidence and use |
|---|---|
| Current recommendation | [AssistedCombat API](https://github.com/Gethe/wow-ui-source/blob/78282522143e25c3540583734fd192c3d69be910/Interface/AddOns/Blizzard_APIDocumentationGenerated/AssistedCombatDocumentation.lua): `GetNextCastSpell` supplies one recommendation. `GetRotationSpells` supplies a list, not a ranked future simulation. |
| Resource and cooldown availability | [Secret predicate API](https://github.com/Gethe/wow-ui-source/blob/78282522143e25c3540583734fd192c3d69be910/Interface/AddOns/Blizzard_APIDocumentationGenerated/SecretPredicateAPIDocumentation.lua): runtime predicates describe secrecy; returned values still require `issecretvalue` checks before use. |
| Cooldowns and charges | [Spell API](https://github.com/Gethe/wow-ui-source/blob/78282522143e25c3540583734fd192c3d69be910/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellDocumentation.lua) marks cooldown and charge queries as potentially secret when cooldowns are restricted. Unknown is not zero or ready. |
| Talent build | Selected numeric talent spell IDs avoid dependence on translated display names. Selection must come from active ranked entries rather than all alternatives on a choice node. |
| Enemy count | RotaAssist's visible hostile nameplates are an estimate. They do not prove all counted units are in ability range, relevant to the pull, or will survive another global. |
| Future resources and windows | Deterministic spell-cost updates and cast-history windows are approximations. Random procs, haste, talent effects, interrupts and hidden auras can invalidate them. |

## Why an absolute optimum cannot be certified

Two combat states can expose the same public signals while having different
hidden resources or procs. Those states can require different best actions.
A policy that receives identical inputs must choose the same output in both;
therefore it cannot be certified as optimal in every hidden state. Future random
events introduce another distinction between expected damage and hindsight.
This is an inference from the information boundary, not a claim that every
practical improvement is impossible.

The useful comparison is consequently scenario-specific expected damage with
uncertainty, against an independently maintained reference. SimulationCraft's
full-state APL can establish a reference inside its simulator; it cannot silently
be transplanted into a restricted in-game addon and retain that guarantee.

## Executed experiment

The official SimC Windows engine `1210-01`, commit
`774babde5ddc7c5fc9f1abb129b473f8a076df70`, reported game data
`12.1.0.69875 Live`. Its pinned MID2 Havoc Fel-Scarred profile was tested with
fixed gear/talents, 1 or 5 targets, 120 or 300 seconds, and two seeds. Runs used
two CPU threads. Each final run requested 5,000 iterations; the JSON reports
4,999 DPS samples. The simulator warns that Rune of Unleashed Fire proc targeting
is based on a model assumption, which also limits these results.

The held-out seed `20260923` at 120 seconds produced:

| Full-state SimC policy | Single-target DPS | Five-target DPS |
|---|---:|---:|
| Official stock APL | 276,082 ± 257 | 539,737 ± 405 |
| Hold Eye Beam in AoE for Essence Break | 276,099 ± 258 | 465,202 ± 388 |
| Reduce Essence Break's Eye Beam cooldown gate from 4 to 2 seconds | 275,800 ± 255 | 538,375 ± 408 |

Uncertainty is an approximate 95% interval half-width (`1.96 * standard error`),
not a range of individual fights. Delaying Eye Beam in this five-target case
lost about 13.8%; neither intervention established an improvement to adopt.
The stock APL remains the reference. It is not a proven global optimum, and
none of these numbers are RotaAssist's measured in-game DPS.

The rerunnable benchmark, complete matrix and provenance are in
[`research/simc`](../research/simc/). Large executables and raw run outputs remain
in the ignored local `dist/research/simc/` directory and are not in the addon ZIP.

## Predictor verification

The final addon regression suite passed 583 cases and all 157 addon Lua files
passed Lua 5.1 syntax checks. Six targeted mutations of the new simulator were
all detected. An isolated mock run of the actual Havoc APL took 0.463 seconds for
10,000 depth-three predictions (about 0.0463 ms each); this excludes actual WoW
API and rendering costs and is not a client frame-time measurement.

## Verification and release gates

1. Pin simulator executable hash, source revision, game data build, profile and
   APL hashes. Keep gear, talents, target model and duration equal for comparisons.
2. Evaluate explicit candidate changes and preserve losses as well as wins.
   Select on development runs and check another seed and encounter duration.
3. Keep reference DPS separate from RotaAssist DPS. A modified SimC APL is not
   the live addon, and synthetic policy agreement is not damage improvement.
4. Test observable-state refreshes, unknown-state handling, per-action time
   advancement, finite charges, opener interruption, and caller-state isolation.
5. Verify the packaged files and installation. Actual client loading, runtime
   protected values, frame timing and combat improvement still require the
   target client; this machine currently lacks the retail `Wow.exe`.

Hekili's [Retail retirement announcement](https://github.com/Hekili/hekili)
attributes its Midnight discontinuation to the API changes. Historical Hekili
is a usability reference, not an available same-patch benchmark competitor.
