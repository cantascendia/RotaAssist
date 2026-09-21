# Independent recommendation and policy research

Owner: Astra. User explicitly requests decisions beyond Blizzard's suggestion.
This supersedes the unconditional official-head rule only for a verified
independent decision path; uncertain/incomplete inputs must remain explicit.

## Implementation contract

- Author a declarative priority policy and export that same policy to the
  SimulationCraft test runner and Lua decision evaluator. Do not copy upstream
  engine/APL code into the MIT addon. The stock profile is a local test fixture.
- Evaluate candidate policies using actual DPS under fixed gear, talents,
  duration, target counts and seeds. Keep discovery and held-out evaluation
  separate. Report stock comparison and uncertainty; an inferior policy does
  not become an automatic replacement because it is independent.
- The evaluator returns a chosen action only when earlier priority choices are
  demonstrably unavailable/false. Unknown facts do not silently skip earlier
  actions. This is priority-policy determinacy, not global damage optimality.
- Separate policy validity, observation completeness, tested talent/gear context
  and live-client validation. A full-information SimC result does not establish
  the same policy's DPS under restricted addon observation.
- Queue integration must seed subsequent simulation from the actual chosen head,
  not from a discarded official suggestion. Preserve the reference head and
  independent status for diagnostics and fallback decisions.
- New tests are additive (Test-Lock scenario 3); any changes to the previous
  unconditional-head contract require scenario 1 with this spec as evidence.

## Limitations that cannot be renamed away

Retail Wow.exe was not found in the checked installation; no live session was
validated. Live personal gear/talents are unavailable.
The first benchmark context is the pinned MID2 Fel-Scarred Havoc profile.
Unknown future procs, timing, geometry and restricted state prevent a promise of
the globally highest action at every instant. The measurable goal is a better
policy under declared inputs, not an unsupported universal guarantee.

## First implementation outcome

The first independent policy did not clear held-out performance gates. Therefore
this release evaluates it in observation-only mode alongside the existing queue.
The evaluator and shared exporter work without a Blizzard recommendation, but
the displayed head is not changed by this unqualified policy. Head replacement
and correct tail seeding above remain requirements for a later qualified policy,
not claims about this release. Diagnostic results distinguish policy determinacy
from performance qualification. No real-client readiness is inferred from mocks.
