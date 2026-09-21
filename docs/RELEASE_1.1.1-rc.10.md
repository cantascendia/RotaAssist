# RotaAssist 1.1.1-rc.10 — automatic runtime context

Implemented by Astra for automatic use by different players, without personal
character exports or an offline simulation prerequisite.

The addon discovers the current learned active spellbook and current override
IDs, excluding passive, off-spec, unlearned and flyout entries. Specialization,
talent and spellbook changes refresh the catalog. Missing/restricted APIs leave
an incomplete observation rather than preserving a previous complete build.
Discovered spells also feed the existing character metadata snapshot.

Current-target range checks now cover recommendations for any specialization,
including those with no loaded APL. Explicit out-of-range candidates are removed;
unknown range is not treated as known availability. New proc replacements are
queried on demand. Target changes invalidate previous range observations.

The main recommendation payload records a per-spell targetable enemy lower
bound, deduplicating GUIDs and excluding idle, dead and friendly nameplates.
These diagnostic fields are not used as AoE damage inputs and are not displayed
as an exact enemy count. Targeting distance does not establish cone, cleave or
splash geometry; hidden enemies and restricted identity remain unknown.

Validation: 692 Lua tests, 100 Python tests, 167 addon Lua syntax checks and
seven killed behavioral mutations. One new generated property test covers 50
unit configurations. The packager verifies payload hashes and ordered TOC/XML
loading. These are offline tests, not live game acceptance or a DPS benchmark.

Extract `RotaAssist-1.1.1-rc.10.zip` under `_retail_/Interface/AddOns/`, preserving
`RotaAssist/RotaAssist.toc`. Interface remains `120100`. The local installer
backs up an existing installation. Automatic sensing requires no `/simc` export.

This release does not establish universal optimal rotations. The independent
damage policy is still Havoc-only, experimentally opt-in and below its earlier
reference benchmark. Generalized damage models, complete battlefield observation
and live-client validation remain unfinished.
