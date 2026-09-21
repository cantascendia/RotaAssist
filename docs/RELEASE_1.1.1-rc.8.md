# RotaAssist 1.1.1-rc.8 — character-specific context

Astra implementation. A new character snapshot records selected talent entries
and ranks, hero subtree, equipment item tokens, public attributes and relevant
spell metadata. Uncommitted edits, incomplete reads and configuration changes
during collection do not become a valid build.

APL profile selection uses the complete character snapshot. Independent decisions
can consume numeric talent ranks. Unknown configuration prevents experimental
promotion; build changes immediately clear the previous head, tail and reference
cache. Dynamic attributes update separately from talent-tree scans.

Enter **`/ra build`** to inspect configuration coverage, observed attributes and the
talent import string. Existing `/ra independent on|off` behavior remains default-off.
Recognizing a build does not establish damage-model qualification. The frozen
rotation policy is unchanged, and complete talent effects/gear-based spell damage
are not yet calibrated.

Two pinned upstream Havoc builds were compared in eight real SimC runs (15,992
samples). Deliberately forcing the Fel-Scarred policy onto Aldrachi lost about
38.87%–41.95% to that build's stock policy. This is a negative control, not a
measured player gain; runtime hero checks should already reject that mismatch.
Detailed evidence is included under `docs/research/character-build/`.

Validation: **666 Lua tests, 79 Python tests, seven new behavioral mutation checks**,
165 addon Lua syntax checks, and package payload/load-order verification.
The actual user's character, real combat and UI have not been validated.

Install `RotaAssist-1.1.1-rc.8.zip` under
`World of Warcraft/_retail_/Interface/AddOns/`, retaining
`RotaAssist/RotaAssist.toc`. Ace3 is bundled; Interface is `120100`.
The local installer preserves the previous installation. Full battlefield
understanding and maximum output remain unachieved.
