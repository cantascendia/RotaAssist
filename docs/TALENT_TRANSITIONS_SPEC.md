# Talent-aware Havoc transitions

Extend the rc.8 character snapshot into the APL forward simulation, scoped to
Havoc (577) and pinned SimulationCraft 774babd / game 12.1.0.69875.

* Eye Beam triggers Demonic only with selected talent 213410. A complete catalog
  reporting rank zero preserves the previous form. Missing rank/configuration is
  unknown, never implicit talent selection.
* Demonic adds at least five seconds of Metamorphosis; SimC also adds the hasted
  channel duration. Until that duration is modeled, five seconds is a lower bound.
  Expiring a lower bound changes form/window knowledge to unknown, not false.
* Manual Metamorphosis adds twenty seconds. Add to a known remaining duration;
  never shorten an existing window. Unknown prior duration remains uncertain.
* Chaotic Transformation (388112) resets Eye Beam and the shared Blade Dance /
  Death Sweep cooldown in the simulated state only. Absent talent preserves CDs;
  unknown talent invalidates non-ready CDs because either reset/no-reset may occur.
* Clearing a cooldown must clear its unknown marker. Unrelated cooldowns remain
  unchanged. Other specs retain their existing behavior.
* Build invalidation clears the live cast-based form estimate. That estimate must
  not invent Demonic for unselected/unknown talents. Public aura observation
  remains authoritative; no new hidden-state reconstruction is introduced.

Tests are additive Test-Lock scenario 3: selection/absence/unknown, extension,
lower-bound expiry, cooldown pair reset, other-spec isolation, end-to-end changed
predictions, generated cooldown invariants, and behavioral mutations. This is
transition correctness, not a DPS qualification or complete damage model.
