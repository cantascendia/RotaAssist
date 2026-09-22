# Adaptive burst experiments and enhanced Eye Beam correctness

This round tested a concrete hypothesis: increase Immolation Aura priority only
when the current enemy population crosses a threshold. The experiment did not
demonstrate a convincing improvement, so its candidate was **not adopted**.
Both shipped policy files remain byte-for-byte unchanged.

## Search and decision

Each hero had 16 discovery candidates, including its unchanged policy. New rules
used population thresholds 2/3/5 at five positions. Discovery evaluated single
target, add waves and moving add waves, 300 iterations each, seed 20261110.
The worst reference ratio determined ranking, with a 1% single-target regression
limit against the previous policy. Top four plus the unchanged policy were
confirmed at 1000 iterations on seed 20261111 before freezing the selection.

Final holdout used seed 20261112, five scenarios, 120/300 seconds and 3000
requested iterations per side. Ten comparisons per hero included full reference,
previous and selected policy. Aldrachi selected its previous policy, so those
candidate/previous roles share reports: **50 unique runs, 149950 DPS samples**,
not 60 independent runs. All raw/input hashes are verified. The Fel-Scarred
candidate improved five-target means by only about 0.15%–0.18%; none of its ten
comparisons had a positive conservative lower difference bound against the old
policy. This is insufficient evidence for replacement. `adoption.json` records
the rejection; `holdout.json` and `search-summary.json` retain the results.

The comparison does not weaken the reference by removing its extra actions.
A separate six-run, 500-iteration diagnostic removed auto-retargeting or fragment
pickup from the reference, one intervention at a time. Retargeting changes were
negligible under these specific profiles. Removing pickup reduced Aldrachi's
moving-wave mean by about 2.85% and Fel-Scarred's by about 0.57%. These noisy
diagnostics guide research; they do not measure additive independent causes,
real-client pickup reliability, or the user's DPS.

## Runtime fix that does ship

Abyssal Gaze (452497) was absent from the current active-replacement and shared
cooldown mappings. Its selected Demonic transition was also missed by the
forward model. The fix uses the Eye Beam (198013) identity for cooldown metadata,
selected-talent transitions and channel classification, while still requiring a
public **current** override before treating an unlearned replacement as learned.
Chaotic Transformation resets both cooldown identities. A just-cast replacement
can use the paired base's whitelist metadata to suppress stale predicted repeats.
Native recommendations retain their existing soft-block exemption.

Tests cover real queue filtering, proc expiry, restricted identity, selected or
unknown Demonic, cooldown reset aliases and post-cast refresh. An initially
incorrect test fixture used a native recommendation for a soft-block assertion;
the fixture now exercises the predicted path that the existing soft-block is
designed to filter. Its before/after assertions were retained.

An optional adaptive-policy registry/export path is validated for future
qualified candidates, including selected-hero identity checks. No adaptive data
file is loaded by this release. Experimental mode remains off by default.

## Reproduce and limits

```text
python scripts/retune_encounter_policy.py --simc dist/research/simc/extract/simc-1210.01.774babd-win64/simc.exe --output dist/research/adaptive-burst
python scripts/diagnose_encounter_controls.py --simc dist/research/simc/extract/simc-1210.01.774babd-win64/simc.exe --output dist/research/adaptive-burst/diagnostic
python scripts/mutate_adaptive_selection.py --output dist/research/adaptive-burst/mutations-final
```

The scripts pin engine/profile/APL hashes. [Pinned class source](https://github.com/simulationcraft/simc/blob/774babde5ddc7c5fc9f1abb129b473f8a076df70/engine/class_modules/sc_demon_hunter.cpp)
dispatches Eye Beam to Abyssal Gaze during its enhancement. `abyssal-gaze.txt`
retains the pinned executable's spell query, with trailing whitespace normalized;
the original is in `dist/research/adaptive-burst/abyssal-gaze.txt`.
[SimC encounter events](https://github.com/simulationcraft/simc/wiki/RaidEvents)
define the synthetic movement/add-wave inputs.

There is still no live combat acceptance. Future pulls, target lifetime, boss
downtime, priority-target damage, safe movement and observation coverage remain
unqualified. [Blizzard's description of combat restrictions](https://news.blizzard.com/en-us/article/24246290/combat-philosophy-and-addon-disarmament-in-midnight)
also explains why displayable state is not necessarily available to addon
decisions. More passing tests or simulated samples cannot establish real-time
global optimality under unknown state and future events.
