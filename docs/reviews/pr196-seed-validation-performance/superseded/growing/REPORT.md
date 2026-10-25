# growing_card_text fixture cost candidate

## Result and limits

- Local, one-file candidate only. No commits, remote writes, installs, full npm suite, Windows operations, user Codex use, production-file changes, or Backlog edits.
- Frozen PR source: `9a4cf64fb6c0f435bb8ad61a3f68f0549a2d03bf`; PR 196 still had that head at the final read on 2026-10-25 01:45 UTC. The existing author has not published a newer version of this file. This work neither claims ownership nor overwrites their branch.
- Exact main comparison: `3ed8bf4b88a950c4736ec2d68e83f141d415c4db`.
- Native Lua 5.4 targeted fixture: baseline and candidate both 11/11. Candidate preserves all 160 normal/upgraded card-label comparisons, all 173 isolated fixtures, real native-layout UI construction, real Combat construction, live click/play/draw flows, rollback checks, integer boundary, reward behavior, and legacy display coverage.
- This does NOT establish Fengari's 30000 ms budget, full CI success, game runtime acceptance, or UI platform acceptance. The reported CI timeout is contextual input from the parent, not a timeout reproduced by native Lua.

## Source identity

The 9a4 baseline contains 87 tracked inputs. Every input's Git blob SHA was recomputed against the fixed Git tree before building. The 3ed8 comparison contains 84 tracked inputs, likewise verified. Generated data, theme, presentation and native layout were built locally using the matching checked generators and JSON/Python inputs, not borrowed from a different build. See `context/verified-baseline-final.json`, `context/verified-main-final.json`, and frozen tree manifests.

Only `tests/lua/growing_card_text.lua` differs between baseline and candidate. Original blob: `7e74ece835c144c77230ad309c32c0cbba41d821`. Candidate blob: `b0340ac5236bff22f209b899e93d6cf1b3565cd2`. Candidate SHA256: `6b5d8543225c866f1e7b1498d3b1bc08d246200f208c3b4cd62b5dfac21961f3`. Patch SHA256: `23169b076bdbeaea19f24bc03ae3b6c8c64b2aeb40e0a39f226b1d4834b4f1ba`.

The Backlog CLI was not present (`backlog: command not found`). AGENTS.md, HANDOFF and SCOPE were read. No task-management files were edited.

## Root cause evidence

The main-to-PR fixture diff expands 40 card definitions to 80: 80 normal/upgraded comparisons become 160, with the additional Perfected Strike printed-text expectation. This coverage increase is intentional and retained, not reverted to satisfy a runtime budget. Fixture count consequently rises from 93 to 173. Expanded card/catalog data also increases repeated copy work.

Every fixture rebuilt the exact same seed-42 Run, generated its encounter queue, started a real cultist battle, then immediately discarded that battle by assigning a new Combat with the case deck. These setup results do not depend on the case. Map generation is not involved: measured Map.generate count is zero.

Original profile, inclusive CPU (not additive):

| API | Baseline count | Candidate count | Baseline CPU s | Candidate CPU s |
| --- | ---: | ---: | ---: | ---: |
| Run.new | 173 | 1 | 0.475829 | 0.002570 |
| Run.startCombat | 173 | 1 | 0.349313 | 0.001364 |
| EncounterQueue.new | 173 | 1 | 0.255680 | 0.001420 |
| Combat.new | 348 | 176 | 0.510681 | 0.156729 |
| UI.new | 173 | 173 | 0.051534 | 0.051451 |
| Map.generate | 0 | 0 | 0 | 0 |

A separate seed-specific baseline profile measured total CPU 1.198190 s, RunSeed.forFloor 346 calls / 0.049471 s, normalize 1038 calls / 0.048740 s, and STS Random.fromSeed 2770 calls / 0.123655 s. In this fixture, forFloor alone was only about 4.1% of total native CPU; its production optimization is independent and should not be assumed to remove this fixture's repeated queue/catalog work. Measurements are not Fengari cost attribution.

The fixture also eagerly builds successful-assert diagnostic strings, but that code was left unchanged: the measured repeated Run/start setup is the single variable addressed here.

## Candidate

`candidate.patch` adds one real, initialized seed-42 Run template. It calls the existing Run.new and Run.startCombat APIs once, removes only the already-discarded opening combat, and uses existing Combat.copy to deep-copy the complete Run for each case. Every case still gets a fresh actual UI and a fresh actual Combat through the original constructors. No minimal fake Run is substituted; no catalog, data, RNG, or ownership tables are shared across cases.

The implementation changes only fixture setup, adding eight lines and deleting two. The actual cases, labels, expectations, iteration counts, and failure rules are unchanged. The instruction/call-count cost contract was first run against baseline and failed with 173 repeated Run constructions; the candidate passed with one real construction. This evidence-only contract is not proposed as an additional project test.

## Verification

1. Data and native UI generators passed for both frozen source trees without installation.
2. Exact fixture on 3ed8: 11/11. Exact fixture on 9a4: 11/11. Candidate: 11/11, including final fresh execution in `evidence/candidate-final.log`.
3. Three finite native runs each, serial within this worker:
   - Main 3ed8: 0.621698–0.728298 s, median 0.637223 s.
   - PR baseline 9a4: 1.451412–1.991089 s, median 1.535078 s.
   - Candidate: 0.872959–1.147010 s, median 0.877582 s.
   - Candidate median reduction: 42.8%. Other worker activity was not controlled; treat wall time as finite local measurements, not a stable CI prediction.
4. Lua count-hook proxy, sampling every 1000 VM instructions over the full fixture: main 40,546,000; PR baseline 98,861,000; candidate 33,947,000. Candidate is 65.7% below PR baseline. This is native-Lua instruction work, not a Fengari duration guarantee.
5. Baseline/candidate stdout is byte-identical.
6. `trace.lua` serializes every fixture's complete initial Run, preserving table identity/aliases via reference IDs; it then records all ten card slots' text, names and visibility on every subsequent render. Both executions made 173 fixtures and 253 observed renders. The 23 MiB traces are byte-identical; both SHA256: `8f86e9bb064d8ff74e19dca2e2b2ba67bf70365eec8fe22487eb38ae837d1439`.
7. Independent graph isolation probe traversed all 173 resulting Run graphs: 333,896 table objects, no cross-fixture table sharing.
8. Five negative controls all exited nonzero and failed the expected behavioral cases. Mutations were loaded into the test process from probe strings; checked production files were not edited:
   - Disable Rampage growth: cases 1, 4, 7 fail.
   - Force static combat display: cases 1, 4, 7, 8, 10 fail.
   - Omit failed-play rollback: cases 3 and 6 fail.
   - Signed-32 integer wrapping: case 8 fails at 2147483653.
   - Share the cached Run instead of deep copying: cases 10 and 11 fail from reward-state contamination.

## Reproduction

Use the existing Python/ctypes Lua 5.4 runner: `/workspace/scratch/331215e8236a/signed-cap-review/run-lua.py`.

From `baseline`, `candidate`, or `main-3ed8`:

```sh
python /workspace/scratch/331215e8236a/signed-cap-review/run-lua.py tests/lua/growing_card_text.lua
python /workspace/scratch/331215e8236a/signed-cap-review/run-lua.py ../instructions.lua
python /workspace/scratch/331215e8236a/signed-cap-review/run-lua.py ../profile.lua
```

From `candidate`:

```sh
python /workspace/scratch/331215e8236a/signed-cap-review/run-lua.py ../isolation.lua
MUTATION=wrap_integer python /workspace/scratch/331215e8236a/signed-cap-review/run-lua.py ../mutation.lua
```

Other mutation names are no_growth, static_label, no_rollback, share_run. `measure.py` repeats only this fixture three times per source; it is not a full suite.

## Handoff

Freeze this as an independently reviewable alternative, separate from the common RunSeed production optimization. Root alone may decide whether to apply it after review and source recheck. Full current-SHA CI, including actual Fengari budget enforcement, remains required. Do not claim this candidate passed 30 seconds or close the original timeout solely from these measurements.
