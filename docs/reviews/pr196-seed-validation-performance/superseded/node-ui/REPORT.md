# node_ui fixture-cost candidate, PR196@9a4cf64

## Result

A test-only candidate reduces sampled native Lua instruction work by 40.7%, while all 40 existing test bodies, real UI construction, state transitions and error checks remain intact. This is not proof that the 30,000 ms Fengari/Windows CI timeout is fixed. No remote branch, task, production code, support helper, CI configuration or timeout was changed.

- Fixed head: `9a4cf64fb6c0f435bb8ad61a3f68f0549a2d03bf`; PR196 was still open and at that head on the final live check at 2026-10-25 01:53 UTC.
- Test base Git blob: `1daaa937e31c888dfa0ecca5be066c8d3083b07d`.
- Candidate Git blob: `9c365aefde1fc5f43a0340f7a36941033529dc32` (see `FROZEN.json` for authoritative calculated identity if this line differs).
- 97 tracked inputs independently matched the supplied head's recursive Git tree; the data/UI builders were rerun from these verified inputs. `context/verified-inputs.json` contains identities. Generated files are not incorrectly presented as tracked Git blobs.
- AGENTS.md, HANDOFF and SCOPE were read. Both requested Backlog overview/execution commands failed because the CLI is absent; no task lifecycle action was attempted. The original task remains owned by its original assignee.

## Diagnosis and minimal change

The unchanged test calls `Run.new` and `Map.generate` 59 times each. Native instruction profiling attributes about 63.284 million of the 97.276 million instructions to these two constructors, about 65.1% of total work. The actual 30,000 ms CI timeout was supplied by the parent from run40148436803/job121034689242; this environment does not reproduce that runtime.

42 constructor pairs use the default data object and seed42. Of these, 40 are inside `entered`; two direct constructions are left unchanged. The candidate lazily constructs one pristine default run/map pair, then independently deep-copies the whole pair for each of those 40 `entered` calls. The remaining 17 custom-source calls and the two direct calls still use fresh real constructors, yielding 1 + 17 + 2 = 20 constructor pairs. This explains why 42 default pairs yield 39 fewer constructions, not 42 fewer.

Every copied pair starts before map navigation. Each case still runs the original `Map.available`/`Map.choose` loop, real `Nodes.enter`, fresh control construction from the generated native tree, `UI.new`, real clicks and all original assertions. The cache does not contain an entered node, a precomputed shop/event result, UI object, narrowed pool, skipped path, or mocked production behavior. Only default `data` with omitted/42 seed uses it; arbitrary/custom sources are not memoized. Full source-state traces establish that default input data stays unchanged during this existing suite.

## Measurements

All runs below use system liblua5.4 via `run-lua.py`, not Fengari and not the game client. Instruction counts use a debug hook sampled every 1,000 instructions; absolute times and small count differences are proxy measurements, not CI budgets.

Three sequential baseline/candidate pairs:

- Baseline: 97,276,000 instructions each; CPU 1.146683, 1.155283, 1.208906 seconds.
- Candidate: 57,670,000 instructions each; CPU 0.787821, 0.790078, 0.790200 seconds.
- Instruction reduction: 40.715%; median CPU: 1.155283 → 0.790078 seconds, about 31.6% lower.
- Profiled constructor calls: Run.new 59 → 20; Map.generate 59 → 20.
- Real production call counts unchanged: Nodes.enter 58 → 58; UI.new 54 → 54.
- All executions finish `LUA_NODE_UI_PASS 40`. The unmodified group names and complete printed test output match.

## Preservation proof

The final baseline and candidate differ only in `tests/lua/node_ui.lua`. From the `colour` helper onward, including setup, all 40 test bodies and terminal output, the files are byte-identical. The native production modules, generated UI and data files are unchanged.

`observe.lua` is an audit-only harness, not part of the candidate test. It executes the full real suite and serializes complete reachable table graphs at cold fixture creation, entered-node return, setup, and every test completion. This includes run/map/data/RNG/queue state, all UI instances, controls, callback results, source data, table alias relationships, function identity relationships, metatables and weak-map keys. Function source location and upvalue count are represented; only shifted line numbers of byte-identical test-local functions are normalized, while production function locations are retained. It does not serialize closure upvalue values, replace any production result, or claim a production bytecode-equivalence proof.

- 59 cold pairs observed, including the two direct constructions; all 54 UI instances retained for end-of-test observation; 53 setup returns observed.
- Every issued pair has no shared table with earlier pairs or its source input.
- Every cached clone has no shared table with the pristine template; template state remains unchanged after UI operations.
- Full baseline/candidate traces compare byte-for-byte equal. Raw SHA256: `4b6dddfb5145ff220c8ff663427fa1b3acd0c025793e09e2fa8bc59745a9ef6b` for both. Compressed copies are under `evidence/`.

The audit harness initially rejected Merchant's existing weak-key metatable and later its run-table key. These were observer limitations, not target-test failures. The final observer handles both explicitly and the complete final run passes.

## Red/green and negative controls

The constructor-cost contract was written and run first: baseline fails with 59/59 versus expected20/20 (`budget-red.log`); the candidate passes (`budget-green.log`). This is an external performance experiment, not an assertion added to the 40-case regression file.

Four isolated negative controls establish that the preservation checks are not superficial:

1. Return the shared pristine pair instead of cloning: fails the isolation audit with `fixture alias leaked across entered calls`.
2. Corrupt each copied run's roomGeneration to1: all40 ordinary tests still pass, but full-state trace comparison detects the change. This specifically proves the trace catches otherwise-unasserted state loss/drift.
3. Remove the real camp upgrade-counter increment: the original Searing Blow case fails.
4. Remove the real Cleric removal affordability validation: the original stale-affordability case fails.

Mutations exist only in disposable `mutants/` copies. Neither candidate nor baseline contains them. See `evidence/mutations.json` and raw logs.

## Scope and next action

This is a minimal locally validated candidate, not an integrated fix. The user's restriction forbids full npm checks, installation, their Codex/computer, platform work or remote writes by this worker. Accordingly no full suite, Fengari, Windows CI, platform import, game-client verification or integration claim is made. No test group, seed, interaction, assertion, real Run/Nodes/UI path or CI time budget was reduced.

The parent/owner may apply only `candidate.patch` to the same current test blob after checking for author changes, then run the real current-SHA Fengari target/full gate in the approved serialized environment. Do not merge this old isolated runtime tree wholesale.
