# TASK-10.6: Artifact-aware intent previews

## Scope and source

Code baseline: `d0bf7276b298e3fbffcb6dfd9a21dbf3df4358f1`.
The later documentation-only `3a984f9a603093d9d9c9111138d3bfcaecbea176`
AGENTS, HANDOFF and SCOPE were read; this change does not replace those documents
or alter milestone, task-owner or platform acceptance status.

The stock Fat Gremlin exposes a supported numeric-boundary discrepancy:
player Weak `2147483647`, Artifact `1` makes the old generated GameUI refresh
throw `status stack overflow`. On a copy of that same state, real
`Combat.endTurn` succeeds, consumes Artifact and leaves Weak `2147483646`.
This is not an ordinary-play frequency, reachability or live-platform claim.
Ordinary Weak `2` with Artifact `1` already worked and remains a control.

## Correction

Intent formatting now uses `Actors.applyPower` on an `Events.frame` snapshot
with its own event list. The existing core owns input validation, recipient
selection semantics, Artifact gating, one-charge consumption and stack rules.
There is no new cap, gameplay change or error suppression. Each effect sees the
previous effect's copied state; the live battle and event journal are read-only.

Enemy playback needs a separate historical boundary. After an Artifact event,
its charge is already absent from the displayed frame while the old Weak stack
has not yet decayed. Reapplying the whole completed intent to that frame would
still overflow. Only an enemy whose real intent event has begun retains that
event's calculated face through the enemy phase. Unacted enemies continue to
reflect current statuses. The cache is actor-ID keyed, not slot keyed, and is
cleared on player phase, battle/run replacement and playback completion,
cancellation or recovery; dead actors do not reuse it. No feedback controller,
event protocol, layout, data or battle-resolution code changes.

## Regression evidence

`tests/lua/intent_artifact_preview.lua` exercises the real generated GameUI,
commands, controls and playback using the existing host fixture:

- Stock boundary refresh and full End Turn, normal values, neighboring bound
  and non-applying Jaw Worm control.
- All five supported ordinary debuffs on either recipient, repeated charges,
  independent actor budgets, signed/zero powers, later damage/block ordering.
- Unblocked overflow and invalid amounts still reject without live-state writes.
- Two stock Fat Gremlins with Weak at the upper bound and two Artifact charges
  complete every feedback step without recovery.
- A synthetic supported sequence verifies that a later enemy sees newly applied
  Vulnerable, an executed self buff is not previewed twice, and the next player
  phase and next command get fresh values. It is not a new stock enemy move.
- Cancellation/battle replacement, status details, card preview, committed
  state contents and live actor/event-table identities remain covered.

Test-first results retained: the initial 12 groups had 7 expected failures;
the gate-only patch then exposed historical replay recovery. Strengthened
15-group coverage had 3 failures before the playback correction. Final coverage
passes all 15 groups. Explicit cancellation is allowed to print the existing
`recovered cancelled` diagnostic; unexpected recovery is rejected.

Four isolated mutations all fail: restoring raw status stacking, discarding
copied effect changes, disabling the historical cache, and freezing unacted
enemies. The unchanged original minimal probe now reports refresh success and
core end-turn success with Weak `2147483646` and Artifact `0`.

Local verification used the available native Lua 5.4 runtime: all 125 Lua
fixtures pass, including existing battle, card-preview, split-actor, feedback,
status and Artifact suites. The first broad run had four missing candidate-file
dependencies; the exact tracked files were restored from the pinned baseline
and their Git blob hashes verified before rerunning all 125, without reducing
the suite. Twelve Node layout/theme checks pass, and the new JS wrapper parses.

`tests/intent-artifact-preview.test.mjs` connects this fixture to the normal
project runner. Local Fengari is unavailable: an existing JS host wrapper
stopped at module resolution, with no install or retry. Full `npm run check`
and current-head CI remain separate integration gates, not claimed here.
No candidate export, official import, live game, device visual or UI acceptance
was performed by this local fix.
