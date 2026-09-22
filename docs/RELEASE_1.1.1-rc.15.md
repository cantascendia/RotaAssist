# RotaAssist 1.1.1-rc.15 — Public GCD action timing

An independent next-action hint can now survive the end of a publicly readable
GCD. It uses event-scoped evidence and the configured SpellQueueWindow, with a
400 ms cap. A short real cooldown, unavailable charge, restricted value or stale
event cannot establish this readiness. Targeted events do not refresh unrelated
spells. Evidence is discarded on relevant cast/build/charge/lifecycle changes.

Aura and cast-modeled Demonsurge expiry are checked at the planned action time.
Future positive aura states without expiry proof remain unknown. Resources,
random procs and future enemies are not invented. The decision is conditional on
the observed state and is rebuilt as observations change.

Validated by 756 Lua tests, 118 Python tests, 170 Lua syntax checks and twelve
behavioral mutations. The actual main queue test produces an independent hint
without native recommendation input and withdraws it on target loss. This is an
offline behavior test, not a game-client or damage benchmark.

Extract `RotaAssist-1.1.1-rc.15.zip` into `_retail_/Interface/AddOns/`, retaining
`RotaAssist/RotaAssist.toc`. Interface is `120100`. No personal export is required.
Enable the experimental independent main slot with `/ra independent on`; return
to the default with `/ra independent off`. The installer preserves the old copy.

The shipped priority policies are unchanged. This release does not establish
maximum DPS in Mythic+ or raids. Secret state and unknown future events remain
limitations, and no usable local Wow.exe was found for game-client acceptance.
