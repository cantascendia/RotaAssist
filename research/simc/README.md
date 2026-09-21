# Pinned SimulationCraft Havoc experiment — 2026-09-22

This is an **independent SimulationCraft APL experiment**, not a measurement of
RotaAssist or a claim that an addon can see every SimC state variable. The stock
official Fel-Scarred Havoc profile was compared with two explicit one-line APL
edits. No tested edit improved both single-target and five-target results, so
none is a recommendation for the addon.

## Source and provenance

| Item | Pinned value / source |
| --- | --- |
| Upstream | [simulationcraft/simc](https://github.com/simulationcraft/simc), `midnight` commit [`774babde5ddc7c5fc9f1abb129b473f8a076df70`](https://github.com/simulationcraft/simc/commit/774babde5ddc7c5fc9f1abb129b473f8a076df70) |
| Official Windows archive | `simc-1210.01.774babd-win64.7z` from `http://downloads.simulationcraft.org/nightly/`; SHA-256 `2b04df41bdf505c59b9e41108efa858039fc40e378233172cd39a3edaaea5d44`; 120,919,819 bytes |
| Extracted `simc.exe` | SHA-256 `8c6df94966798cabf6864664c2648de9252e396a5ea90188c115c17c8b5339de`; reports SimC `1210-01`, revision `774babd`, game build `12.1.0.69875 Live` |
| Stock profile | [MID2_Demon_Hunter_Havoc.simc at that commit](https://github.com/simulationcraft/simc/blob/774babde5ddc7c5fc9f1abb129b473f8a076df70/profiles/MID2/MID2_Demon_Hunter_Havoc.simc), SHA-256 `d14ce688a7016d548c4abd3c2554be2b891c1284d771180ab7cc2571c17db3e1` after LF normalization |
| Embedded stock APL | 45 `actions*` lines joined with LF and a final LF; SHA-256 `1c1f2231e161d107ecaa81f02fd0b39d4438e3b96d15dd3b813f3ab53b4a8f74` |

The profile bundled in the Windows archive has CRLF line endings and SHA-256
`0e86f609e3c0cc6014fd294f362d54da29b74009fb24f83bb4155ab4d2a1960e`;
its LF-normalized bytes equal the pinned GitHub source profile. The upstream
profile and executable are SimulationCraft material under its upstream license;
neither is tracked here or included in the RotaAssist addon ZIP.

The nightly archive was downloaded over **HTTP** because that official host did
not offer HTTPS. Its SHA-256 pins the bytes we tested, but we did not verify a
publisher signature. The GitHub Actions artifact for the same commit (run
`35555269115`, artifact `10620711070`) required authentication and could not
serve as an independent download. Reproduction should verify a trusted binary
source before treating the archive as supply-chain evidence.

## Run protocol

`scripts/simc_bench.py` rejects any EXE, stock profile, APL, game build, seed,
target count, thread count, or iteration count that differs from its pinned
request. It also rejects unknown warnings and errors. The only observed model
warning is `implementation_not_yet_verified` for Rune of Unleashed Fire; its
proc target/damage assumptions remain unverified. Raw logs, generated candidate
profiles, full SimC JSON and individual reports are under the ignored
`dist/research/simc/runs/` directory on this machine.

For example, after obtaining the pinned binary and stock profile:

```powershell
python scripts/simc_bench.py `
  --simc dist/research/simc/extract/simc-1210.01.774babd-win64/simc.exe `
  --profile dist/research/simc/official-MID2_Demon_Hunter_Havoc.simc `
  --output-dir dist/research/simc/runs `
  --intervention stock --targets 1 --duration 120 `
  --iterations 5000 --seed 20260922 --threads 2
```

The official [SimC enemy option](https://github.com/simulationcraft/simc/wiki/Enemies)
is `desired_targets`, used here for 1 and 5 targets. `target_count` was found
to be silently ignored and was excluded from all reported comparisons. Each
scenario uses fixed fight length, no length variation, the same gear/talents,
the same seed and two CPU threads. Seeds `20260922` and `20260923` were used as
train and held-out checks. Requests for 5,000 iterations produced **4,999
reported DPS samples** per run in this pinned engine. There were 20 full runs,
99,980 reported samples total. The `±` values below are approximate 95% CI
half-widths of each individual mean (`1.96 × SimC mean_std_dev`), not CIs for
the difference between APLs.

[results.json](results.json) preserves all 20 measurements, candidate APL hashes,
observed warnings, and hashes of the original full SimC JSON outputs.

## Results

The two interventions are exact one-line substitutions in the stock APL:

- `eye_beam_hold_aoe`: change `actions+=/eye_beam` to
  `actions+=/eye_beam,if=active_enemies=1|cooldown.essence_break.remains<3`.
- `essence_break_gate_2s`: change
  `actions+=/essence_break,if=cooldown.eye_beam.remains>4` to the same line with
  `>2`. All other stock profile bytes remain unchanged.

| Targets / fight | Seed | Stock DPS ± CI half-width | Eye Beam hold change | Essence Break gate change |
| --- | ---: | ---: | ---: | ---: |
| 1 / 120 s | 20260922 | 276,218.84 ± 256.23 | −0.011% | −0.149% |
| 1 / 120 s | 20260923 | 276,082.13 ± 257.35 | +0.006% | −0.102% |
| 5 / 120 s | 20260922 | 540,101.17 ± 405.66 | −13.876% | −0.282% |
| 5 / 120 s | 20260923 | 539,737.35 ± 405.46 | −13.809% | −0.252% |
| 1 / 300 s | 20260922 | 252,904.68 ± 157.76 | — | −0.240% |
| 1 / 300 s | 20260923 | 252,794.07 ± 155.42 | — | −0.185% |
| 5 / 300 s | 20260922 | 497,569.82 ± 261.25 | — | −0.388% |
| 5 / 300 s | 20260923 | 497,625.95 ± 260.77 | — | −0.452% |

The Eye Beam change's tiny single-target gain on the held-out seed is smaller
than the individual-mean uncertainty and comes with a large five-target loss.
The Essence Break change loses on every tested seed and duration. The stock
APL is the best measured choice among these tested candidates; this is not a
global optimum or a cross-patch comparison. SimC is an offline combat model,
and these experiments do not establish live Midnight client safety, UI behavior,
RotaAssist decision accuracy or actual player DPS.

Run the additive validator with `python -m pytest tests/test_simc_bench.py -q`
(`pytest` and `hypothesis` required). It checks that mismatched scenarios,
builds, warnings, sample counts and altered stock APL bytes fail closed.
