# Player Death Transition Implementation Plan

**Goal:** Preserve the fatal hit, show the player's collapse over the battlefield, then fade into the existing defeat results without changing combat rules.

**Architecture:** Only committed defeat events start the death sequence, so Fairy/Lizard Tail recovery remains ordinary combat. The existing feedback queue owns the input lock until the battlefield is fully covered; a matching result veil fades away on the host's presentation clock. All controls are fixed native UI nodes, using shared theme colors and timing.

**Tech Stack:** Lua/Fengari, generated native UI, Node test/build scripts.

## Steps

1. Add `tests/lua/player_death_transition.lua` using the production host, combat and generated native controls. Prove the missing player death sequence before editing production code.
2. Update `abyss_feedback.lua`, `ui-layout.mjs` and `ui_theme.json`: queue a player-only death step before committed defeat, preserve the fatal hit, collapse the hero, play one defeat cue, and cover the battlefield. Reset and failure must clear the veil.
3. Update `game-ui-layout.mjs` and `abyss_game_ui.lua`: use an opaque matching veil on result entry and fade it out before accepting restart/settlement. Do not affect directly restored results or victory/menu presentation.
4. Run the new fixture, feedback/recovery/result gesture/host suites, layout contracts and engineering gates. Cover fatal enemy attack, self/retaliation damage, revival, cancellation, failure, large frame deltas and restart cleanup.
5. Independently review, commit only this slice, PR into develop, wait for exact-head full Quality, squash merge and clean up the isolated worktree. Record live UI/audio as unverified until a new candidate is imported and played.

## Reference And Acceptance

Reference: `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0/screens/DeathScreen.java`: retains player/monsters, black overlay, death stinger, delayed death animation and fading text. This is a short independent native adaptation, not a claim that Java effects/assets were ported unchanged.

Acceptance: fatal contact precedes collapse; exactly one player death/defeat cue; fully covered screen at result handoff; result fade completes before restart/settlement; no death treatment on revival; no stale veil/pose after cancellation or new battle. Gameplay state and RNG must not be modified by presentation. Desktop/mobile appearance and audibility require separate same-candidate live evidence.

## Offline Evidence

- Regression was observed failing before implementation: fatal contact had no dedicated player-death queue entry.
- `node scripts/test-lua.mjs tests/lua/player_death_transition.lua`: 10 cases pass, including Fairy/Lizard Tail, retaliation, BGM handoff, cancel/fault recovery, stalled-frame visibility, exit-menu settlement guard and standalone restart.
- Existing Lua suites pass: feedback polish 17, startup recovery 5, result gestures 20, composed game host 16. Layout regression passes 9 cases; theme/capacity/native-contract tests were also exercised.
- `npm run check:engineering` passes: architecture 257 modules/1425 edges, all 3897 measurements collected, 37 historical warnings/no new diagnostics, 941 governed responsibility measurements, four critical mutations killed, two native-contract cases pass. Only existing feedback warning coordinates moved in the explicit lint baseline; no new warning suppression or threshold changes.
- Independent read-only review `ses_e79ea2a3affemoIWNMyJbJHqr7` found and then verified fixes for the exit bypass, stalled collapse and standalone restart; follow-up reports no remaining actionable findings.
- Timing after fatal contact: 0.7-second player-death step, 0.9-second battlefield/banner fade, 0.35-second result reveal (1.95 seconds, plus the already-existing fatal-hit action wait).
- No candidate exported/imported and no desktop input sent. Native draw order, visual smoothness, real PC/mobile input and audio audibility remain unverified; TASK-29.1 live acceptance stays open.
- Full related checks exposed exact historical-source binding drift. An additive 10-file inverse binds only this change's complete hashes/hunks; original frozen archives, assertions and budgets are unchanged. Existing approved UI/Node inverses and all seven Battle slices pass; the historical presentation replay still executes all 81392 original native writes. A dedicated inverse regression rejects partial/unrelated drift while allowing the complete prior witness.
