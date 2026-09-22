# RotaAssist 1.1.1-rc.14 — Enhanced Eye Beam integration

Abyssal Gaze now participates in Havoc's active replacement, shared cooldown,
selected Demonic and Chaotic Transformation paths. The queue can retain a
publicly confirmed enhanced Eye Beam even if the replacement itself is not
reported learned. Expired or restricted override identity is not accepted as
proof. Base whitelist metadata supplies post-cast soft-blocking for predicted
actions when only Eye Beam is listed. Channel classification follows the paired
base, and native recommendations keep their existing exemption.

This fixes a concrete burst-state integration gap. It does not establish a DPS
gain. A separate population-aware priority experiment tested 16 variants per
hero, then 20 held-out comparisons against previous and reference policies.
Its results did not justify changing the shipped priority policies. The release
therefore keeps both existing policy files and default settings unchanged.
See the [research record](../research/adaptive-burst/README.md).

Validation: 741 Lua tests, 116 Python tests, 169 addon Lua syntax checks and nine
focused behavioral mutations. Generated properties cover 60 population/boundary
cases and 45 enhanced-channel transition cases. Holdout verification covers 50
unique simulator runs and 149950 DPS samples, with cached duplicate roles counted
once. Package hashes and ordered TOC/XML loading are checked locally.

Extract `RotaAssist-1.1.1-rc.14.zip` into `_retail_/Interface/AddOns/`, retaining
`RotaAssist/RotaAssist.toc`. The installer preserves the previous installation.
Interface is `120100`. No personal export is required; independent main-slot
selection remains an explicit `/ra independent on` experiment. Actual Mythic+
and raid DPS, complete battlefield understanding and theoretical maximum output
remain unvalidated. The current local test environment has no running Wow.exe
or Wow.exe at the inspected retail path, so no in-game acceptance is claimed.
