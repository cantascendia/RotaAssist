# Automatic runtime context evidence

Scope: spec-independent spell discovery, current-target eligibility filtering
and per-spell targetable enemy lower bounds. No personal profile is required.

The extracted client API reference is pinned to Gethe/wow-ui-source commit
`78282522143e25c3540583734fd192c3d69be910`:

- [SpellBookDocumentation.lua](https://raw.githubusercontent.com/Gethe/wow-ui-source/78282522143e25c3540583734fd192c3d69be910/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellBookDocumentation.lua)
- [SpellDocumentation.lua](https://raw.githubusercontent.com/Gethe/wow-ui-source/78282522143e25c3540583734fd192c3d69be910/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellDocumentation.lua)

The implementation uses runtime enum values and documented skill-line offsets,
item types, base/override IDs, passive and off-spec flags. API shape evidence
does not establish live availability: pcall plus secret/type guards remain
necessary and incomplete reads retain an explicit incomplete marker.

Reproduce from the repository:

```powershell
& 'C:\Program Files (x86)\Lua\5.1\lua.exe' scripts/run_tests.lua
python -m pytest tests training/test_apl_parser.py -q
python scripts/mutate_runtime_context.py
```

Additive regression cases cover spell discovery, metadata integration, new
overrides, spec/build changes, restricted data, target switches, no-APL queue
integration, range-specific counts and a 256-ID storage cap. The new property
test generates 50 unit populations and checks unique engaged enemy counts.
Seven mutations must fail behavior tests; existing assertions were unchanged.

Targetable counts are not AoE hit counts and are not supplied to damage ranking.
The scan is capped at 40 nameplates; complete coverage is never claimed. The
generic context does not mark an unmodeled specialization as independently
supported. This work provides no new measured DPS result and no live acceptance.
