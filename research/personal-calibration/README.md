# Personal calibration 0.1 acceptance

The new local tool compares policies against the imported character rather than
reusing the reference profile's gear. Engine/source pins are unchanged from
`research/simc/README.md`. Only reference APL lines are retained. Two public test
exports were derived from upstream MID2 Fel-Scarred and Aldrachi profiles; neither
is the user's character. Both upstream APL byte hashes are identical at this pin.

The Fel-Scarred acceptance run uses scenarios 1 target / 120 seconds, 5 / 120,
5 / 300, with 500 discovery and 2,000 holdout iterations. Six discovery policies
(reference plus five own policies) and two holdout policies make 24 real runs.
The Aldrachi negative control uses 1 / 120 with 100 discovery and 200 holdout
iterations, making eight further real runs. Seeds 20261003 and 20261004 are
separate. Cache revalidation through the extracted launcher is not a new run.

Both experiments report `reference_not_reliably_beaten`. The selected Fel-Scarred
candidate loses approximately 1.47%, 1.62% and 2.17% in its held-out scenarios;
the deliberately mismatched Aldrachi comparison loses approximately 38.53%.
These are policy comparisons within the same character/scenario, not a comparison
of hero talents or player gains. No policy is promoted into the addon.

The tool preserves raw outputs, reported engine warnings (including SimC's known
Rune Unleashed Fire assumption), all discovery rows, the frozen pre-holdout
selection, and observed sample counts. It additionally records the reference
simulation's buffed attribute snapshot; those values are not live client stats.

Validation: 677 Lua tests, 99 Python tests including training parsing, 19 new
calibration cases including generated modifier invariants, and seven behavioral
mutations killed. The standalone ZIP contains ten files and verifies all payload
bytes. The extracted PowerShell launcher located this machine's pinned engine
and revalidated the complete real run cache successfully.

Actual-user capture and live combat acceptance remain outstanding. The kit
requires Python 3.11+, a separately installed pinned SimC release and its bundled
profile. Execution has no extra Python package dependency. It does not contain
the third-party simulator or reference APL.
