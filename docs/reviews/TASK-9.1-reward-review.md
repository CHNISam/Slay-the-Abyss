# TASK-9.1 independent reward review

Reviewed revision: `e0aa137b5ab28f5c73febd0a1659a8ce08b924ee` on `feat/task-9-card-rewards`.
Reviewer: quality-gates, not involved in `abyss_run.lua` implementation.

## Result

No blocking issue found in the reviewed initial-deck/reward scope. Production code was read only. This is offline Lua evidence; no UI, save import, game session, or player acceptance was performed.

## State and transaction checks

- `Run.new` creates ten permanent instances from the starter table and copies catalogs. Combat receives the permanent deck, current HP and run seed.
- `startCombat` rejects unknown encounters, wrong floors and repeated starts before changing the run. Combat creation finishes before the run enters combat phase.
- `finishCombat` rejects unfinished and already-finished combat. On victory it commits battle HP and seed, applies the starting relic's capped six-point heal once, awards normal gold once, then samples three unique card choices without replacement. Claiming a card does not award more gold or healing.
- On defeat it commits zero HP without healing or rewards. Replayed finish/claim commands cannot recover resources.
- Choice validation precedes mutation. Explicit zero skips the pending choice. A selected card receives one new permanent UID; next combat actually contains that card in its hand/draw piles. Reward views are copied.
- Candidate selection excludes basic/special cards, conditions, X costs and unsupported operations. Independently constructing single-card battles confirmed all 17 current candidates satisfy `Combat.canPlay`; advanced mechanics remain TASK-16 scope.
- Reward RNG starts at the completed battle seed and consumes exactly one RNG step per offered choice. Invalid claims and valid claim/skip preserve the already-committed seed.

## Executed evidence

Environment: Windows, Node 22/Fengari Lua 5.3, locked dependencies installed using `npm ci --ignore-scripts`.

`npm run check` exited 0:

- Syntax, six-table validation and Lua data build passed.
- 54 JavaScript tests passed, zero failures/skips.
- 15 core combat Lua tests and all 8 run Lua tests passed.
- Python: 10 passed, one explicit Windows symlink-privilege skip (`WinError 1314`), zero failures.

An additional temporary Lua black-box probe, executed through `node scripts/test-lua.mjs <temporary-probe.lua>`, passed with:

```text
REWARD_REVIEW_PASS real_wins=8 next_combats=8 currently_playable_reward_candidates=17
```

The probe used seeds 1 through 8 and only `Run.play`/`Run.endTurn` to beat `cultist_solo` with the unmodified ten-card starter deck. It inspected but did not edit battle HP, energy, enemies or piles. Selection iterated playable cards, preferred attacks, then ended turns, bounded to 40 turns and ten plays per turn.

For each victory it asserted exact normal gold, capped combat-end healing, three currently playable choices and expected RNG advancement. Choices `seed % 4` exercised skip and all three positions. It checked unchanged HP/gold/seed on claim, exact deck/UID increment, replay rejection, and physical membership of the selected card in the next battle's hand/draw piles.

Separate deep-copy comparisons proved full run equality after invalid claims (`-1`, `4`, fraction, infinity, NaN, string, boolean, table), repeated finish/claim, unknown start, unfinished finish and stale card UID. A one-HP starting run lost through actual enemy action and rejected finish/claim replay without receiving healing, gold or cards. The existing suite additionally checks nil choice and wrong-floor start.

An earlier 64-seed version with repeated full-state snapshots reached the runner's 15-second timeout and was terminated. It is not counted as passing evidence; the bounded eight-seed probe above passed. No timeout limit was raised and no production file was changed.

## Remaining boundaries

- This review establishes the current 17-candidate offline rule path, not the full 37-card runtime or UI/playability acceptance.
- Map advancement, other relic triggers, potions, advanced effects and final settlement belong to their separate tasks.
- The pre-existing development-only Fengari/sprintf-js audit finding remains recorded in TASK-8.1; this review added no dependency.

Reproduce the committed functional evidence with `npm ci --ignore-scripts`, `npm run check`, or the narrower `npm run build:data` followed by `node scripts/test-lua.mjs tests/lua/run.lua`.
