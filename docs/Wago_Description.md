# RotaAssist — A Rotation Coach, Not a Crutch

*Built for World of Warcraft: Midnight 12.1 (Interface 120100)*

---

## Blizzard already tells you the next button

Assisted Combat ships with the game. It highlights one spell. Every rotation addon
out there wraps that same call and draws that same one spell somewhere else on your screen.

**RotaAssist does the part Blizzard doesn't.**

- **The next five, not the next one.** Multi-step lookahead from a forward APL
  simulation, so you can plan a burst window instead of reacting one global at a time.
- **Whether you actually hit it.** Live and historical accuracy tracking, broken down
  by combat phase, so you learn where your rotation drifts.
- **What kind of moment this is.** Twelve combat phases detected automatically — burst,
  AoE, execute, emergency and more — using non-secret signals only.
- **What you forgot before the pull.** Flask, food and rune checks before the fight
  starts, not a wipe later.

An icon tells you what to press. A coach tells you why you're behind.

---

## Supported Specializations

**v1.1.0 ships Demon Hunter only.** This is deliberate.

| Spec | specID | Status |
|---|---|---|
| Havoc | 577 | Fully supported |
| Vengeance | 581 | Fully supported |
| Devourer | 1480 | **Experimental** |

**Why only three?** Seventeen other specs exist in the source tree. On audit, they
averaged around 30% of their priority rules permanently dead — conditions the engine
could never evaluate, failing silently while the addon looked like it was working.
Several decision trees were 14-line stubs. Rather than advertise twenty specs and ship
half a rotation for most of them, this release ships the three that are genuinely
complete. Breadth can be added later. Credibility can't.

**About Devourer:** the spec is real and live, but several spell IDs in our data came
from early datamining and have not been verified against a live 12.1 client. RotaAssist
guards every spell lookup at runtime, so an unknown ID never throws a Lua error — the
affected recommendation simply doesn't display. Verify one yourself with
`/dump C_Spell.GetSpellInfo(442501)` and please post corrections. Devourer players are
the reason this gets fixed.

---

## Midnight 12.x Compliance

- **No secret values are ever used to make a decision.** Every read that can return a
  secret value goes through one template: `pcall` → `issecretvalue` → type check →
  fallback. This release fixed six places where that guard was missing or came too late.
- **Built on the official `C_AssistedCombat` API.** The recommendation chain starts from
  Blizzard's own call.
- **The APL is a forward simulator**, reading simulated state rather than restricted
  live APIs.
- **The prediction model uses only non-secret features** — cast history, nameplate
  count, combat duration, spec.
- **No memory reading. No automation. No input injection.** Official APIs only.

---

## Features

- **Multi-step lookahead** — see 3–5 casts ahead, not just the next one
- **Accuracy tracking** — real-time meter plus per-phase historical breakdown
- **Combat phase detection** — 12 phases, non-secret signals only
- **Pre-pull checklist** — flask, food, rune verification before combat
- **Personal AI prediction** — decision tree plus Markov chain trained on YOUR cast history
- **Multi-source fusion** — Blizzard recommendation, APL simulation and AI blended into
  one weighted call
- **Interrupt and defensive alerts** — sound plus visual flash
- **CooldownViewer coexistence** — optional hook so the cooldown panel doesn't duplicate
  Blizzard's native viewer (off by default)
- **Trilingual** — English, 简体中文, 日本語

---

## Installation

1. Download the zip from the Files tab (or install via the Wago app).
2. For manual installs, extract into `World of Warcraft/_retail_/Interface/AddOns/` —
   you should end up with `Interface/AddOns/RotaAssist/RotaAssist.toc`.
3. Restart the game, or type `/reload`.

No required dependencies. Ace3 is embedded.

---

## Slash Commands

| Command | Description |
|---|---|
| `/ra` | Print the command list |
| `/ra toggle` | Show/hide the main display |
| `/ra config` | Open settings |
| `/ra lock` | Lock/unlock the display position |
| `/ra accuracy` | Print accuracy history |
| `/ra aplcheck` | APL condition diagnostics — expected output for all shipped specs is zero |
| `/ra debug` | Toggle debug mode |
| `/ra reset` | Reset all settings |
| `/ra version` | Show version |

`/ra aplcheck` is an honesty tool. Unrecognized rotation conditions used to fail
silently — green tests, broken product. Now they're recorded at load time and you can
read the list yourself.

---

## Bug Reports

Please report issues in the comments. Include:

- Your client version (`/dump GetBuildInfo()`)
- Spec and hero talent
- The full Lua error — **BugSack + BugGrabber** strongly recommended
- Steps to reproduce

Devourer spell ID corrections are especially welcome.

---

*Released under the MIT License.*
