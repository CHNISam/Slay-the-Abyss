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

## CI timeout follow-up (same PR)

The first formal Fengari run did **not** pass: PR152
[run 40056551045, job 120760685203](https://github.com/CHNISam/Slay-the-Abyss/actions/runs/40056551045/job/120760685203)
on `STA-Sister-Win` ended with `ETIMEDOUT` at the existing 30,000 ms limit.
The JS suite reported 895 pass / 1 fail / 118 skip. Thirteen intent groups had
completed; the double-Fat group reached its `player_turn` event but had not
finished its final checks. There was no logged assertion failure. Buffered
stdout timestamps cannot establish individual group durations.

Native diagnostic profiling identified the expensive test path, not a proven
production stall: `drainChecked` repeatedly traverses the whole committed state
and event frames, while the old equality helper eagerly formatted error strings
on every successful comparison. The two multi-frame groups visited 940,187 and
582,397 nodes. Building messages and field paths only on mismatch preserves
these exact counts and all per-frame comparisons; native measured CPU fell
from approximately 1.123/0.646 seconds to 0.211/0.135 seconds. These are local
diagnostic measurements, not predictions or substitutes for Fengari results.

Coverage is split by concern, following the existing GameUI fixture pattern:

- `intent_artifact_preview.lua`: original groups 1–12, from the stock Fat
  Gremlin boundary through invalid-amount validation.
- `intent_artifact_playback.lua`: original groups 13–15, covering ordered
  enemies/next command, two stock applying enemies and cancellation/replacement.
- `support/intent_artifact_fixture.lua`: shared setup, comparison and playback
  helpers; not discovered as an independent test by the top-level Lua runner.

All 15 named test bodies and assertions are retained, with only the shared
recovery-counter alias changed. The complete `drainChecked` loop is unchanged.
The JS wrapper explicitly runs both files and requires 12 and 3 passed groups,
zero failed groups and no unexpected recovery. No runner, timeout, production
source, frame frequency or tested field was changed. All four original
mutations remain detected after the split. Comparator controls also reject
nested-value, type, missing-field, extra-field and Boolean differences.
The corrective commit still requires a successful formal Fengari CI run.

## M1 closeout: unchanged 30-second fixture budget

PR162 run `40066537158` exposed a further real timeout: the combined three-case
playback fixture completed the first case and reached the second case's
`player_turn`, then hit 30,000 ms without a logged assertion failure. On the
independent `5c6dbcc` baseline, that same unchanged fixture passed locally in
26.0 seconds; this local pass does not invalidate the slower CI failure.

The two multi-enemy cases now enter real `Combat.new` with Defend and the stock
Fat Gremlin/Jaw Worm definitions they exercise, every rule and every status.
The existing generated GameUI, pointer callbacks, production commands, real
feedback and complete `drainChecked` loop remain in use. The host still starts
normally; only its test battle is replaced with this dependency-scoped battle.
The twelve preview cases and cancellation/replacement case retain the complete
catalog. No production, layout, runner or deadline changes.

The original three playback bodies are independent and now have separate
top-level fixtures: ordered enemies/next command in `intent_artifact_playback`,
two stock Artifact charges in `intent_artifact_charges`, cancellation and battle
replacement in `intent_artifact_cancellation`. The JS wrapper explicitly
requires all twelve preview groups plus one group from each playback fixture.
All three original bodies and assertions are byte-preserved after normalizing
only the first two setup calls. The entire 0.05-second `drainChecked` loop,
including every committed-state comparison and actor/event identity assertion,
and the runner are byte-identical to the baseline.

Independent local evidence is under root `.artifacts/m1-artifact-test-cost/`:

- `catalog-equivalence.lua` compares full versus dependency-scoped catalogs in
  both original multi-enemy scenarios through three complete real `endTurn`
  traces. Every core field, event snapshot and retained definition matches;
  only unused catalog entries differ. Initial state traversal falls from
  2807/2796 values to 1234/1223. The helper still compares all remaining fields.
- The unsplit scoped fixture passed all three groups in 20.1 seconds. Final
  independent fixtures measured 10.25, 6.98 and 1.13 seconds, each under the
  unchanged 30-second deadline. All original feedback and PASS lines match the
  baseline exactly and in order.
- `node --test tests/intent-artifact-preview.test.mjs` passed the complete
  wrapper in 30.4 seconds, with every child using its default runner deadline.
- An isolated in-memory mutation disabling historical intent caching fails
  the retained self-buff assertion (`expected 18, got 21`). Production files
  remain unchanged. An earlier diagnostic attempt hit Fengari's unavailable
  `io.open`; that harness error is retained separately and is not counted as
  mutation detection.

These are fixed-source local results, not a claim that the current PR SHA has
passed formal CI or that any platform/UI acceptance is complete. Task ownership
and unchecked acceptance criteria are left for the integrating coordinator.
