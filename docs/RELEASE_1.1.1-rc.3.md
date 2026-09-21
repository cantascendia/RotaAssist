# RotaAssist 1.1.1-rc.3 — local model-correction candidate

Date: 2026-09-22. Astra took over coding, review and delivery after the user's
updated instruction. This is a local ZIP delivery.

## Changes

Havoc prediction uses corrected base generator amounts and cooldowns, excludes
the passive Glaive Tempest effect from manual recommendations, and respects a
publicly readable resource maximum. Unknown maxima retain a conservative
fallback without reducing an already observed resource amount.

The package includes its required libraries. Extract
`RotaAssist-1.1.1-rc.3.zip` into the retail client's `Interface/AddOns/` directory,
producing `Interface/AddOns/RotaAssist/RotaAssist.toc`. The repository installer
checks payload hashes and retains the previous installation when upgrading.

See [model validation](HAVOC_MODEL_VALIDATION_2026-09-22.md) for source provenance,
the 874-row independent replay and limitations. The ZIP's accompanying local
`verification/` directory records tests, packaging, installation and source SHA.

Target Interface: `120100`. The local retail executable is absent, so real client
loading and combat are unverified. This release does not establish globally
optimal DPS, live-client acceptance or superiority over historical Hekili.
