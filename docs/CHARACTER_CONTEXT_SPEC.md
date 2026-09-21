# Character-specific decision context

2026-09-22. Add a public character snapshot with provenance, rather than equating
a hero-profile label with a validated personal build.

Read the active specialization/configuration, every enumerated talent node,
selected entry, rank, definition and selected hero subtree. Reject staged edits,
partial/error/secret data, duplicate/inconsistent nodes and a configuration that
changes during collection. Recheck active configuration and staged state before
publishing. Unselected choice entries do not become learned talents. Catalogued
unselected talent spells can report rank zero only after a complete scan.

Capture equipped item IDs and canonical item tokens (including modifiers), public
combat stats and rotation-relevant spell metadata. Nil item links for present items
are incomplete, not empty slots. Talent, equipment and stat completeness are
separate. Spell cost metadata is a point-in-time observation, not a guaranteed
cost for all future casts. Do not infer damage coefficients from tooltip text.

Build identity uses deterministic sorted numeric talent/rank and canonical gear
tokens; it is an equality key, not a cryptographic signature or performance
certificate. No player name or account identifier is needed. Invalidate immediately
on specialization, talent/configuration, equipment and learned-spell changes.
Refresh through the central event dispatcher; avoid per-frame talent-tree scans.
Old queue, observer and reference caches must not survive invalidation.

Use the complete snapshot for APL profile selection and expose numeric talent-rank
conditions to the independent evaluator. Unknown build blocks experimental
independent promotion when the module is present; it must not silently inherit a
previous build. Keep the default assisted path. Retain public, bounded skill reads.

Provide localized `/ra build` diagnostics so the user can inspect snapshot status,
talent/gear coverage and spell metadata without implying DPS qualification.
Record offline profile sensitivity using two pinned upstream Havoc builds, with
each policy compared to the stock policy on identical gear/talents inside its row.
This does not benchmark the user's actual character, which requires live capture.

Test-Lock scenario 3: additive API fixtures, pending edits, active-config races,
choice nodes, hero selection entries with no spell definition, cache invalidation,
unreadable gear/stats, generated order-independent fingerprints and mutations.
