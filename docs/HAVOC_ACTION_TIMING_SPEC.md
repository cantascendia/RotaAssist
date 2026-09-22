# Havoc public action timing

The independent observer currently rejects every positive cooldown, including a
publicly confirmed GCD. Near the end of a GCD this prevents a next-action hint.
Add bounded planning inside the player's public SpellQueueWindow, capped at
400 ms. This is a conditional next-action recommendation, not automatic casting
or proof of optimal damage.

- Collect isOnGCD only synchronously in SPELL_UPDATE_COOLDOWN through the central
  safe cooldown reader. Other consumers retain its existing four return values.
- Require enabled=true, public finite spell and GCD clocks with identical start
  and duration, and a positive public charge count for charge spells. Unknown
  charge state, restricted clocks, short real cooldowns and stale events cannot
  establish GCD-only readiness.
- Revalidate both clocks on every read. Discard evidence on player cast start,
  success, charge updates, spec/build/spell changes, world entry and disable.
  A new event replaces the previous evidence, including nil/false flags.
- The observer may project cooldowns to the bounded GCD horizon only for spells
  with this evidence. Do not assume regeneration, procs or future enemies.
  Auras with public remaining time can expire; positive aura flags without a
  remaining time become unknown at a future horizon. Modeled surge flags cannot
  survive an unproven future Metamorphosis window.
- Native recommendation defaults and experimental opt-in remain unchanged.
  Expose planning delay and timing provenance in borrowed diagnostics.

Validation must exercise actual event dispatch, the real safe reader, observer
and final queue. Add-only regressions, generated clock/secret combinations and
behavioral mutations must reject fake, expired and invalidated GCD evidence.
Offline evidence is not Mythic+ or raid combat acceptance.

Source: Blizzard generated SpellSharedDocumentation.lua (live mirror inspected
2026-09-22), isOnGCD is NeverSecret and documented as trustworthy only while
responding to SPELL_UPDATE_COOLDOWN:
https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellSharedDocumentation.lua
