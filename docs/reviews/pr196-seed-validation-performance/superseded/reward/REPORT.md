# Reward-protocol fixture cost candidate

## Result

A single-file candidate preserves all 50 original tests, including the 36 reward combinations, four genuine unknown-room paths and seed42 natural terminal route. Six alternating native Lua 5.4 runs show median wall time 0.8493s → 0.5360s (36.9% lower). This is a performance proxy only: it does not certify the Fengari 30,000ms CI budget, full Quality, platform play or a victory. The actual seed42 route ends in defeat and executes its original loss-gate/restart checks.

- Patch: `candidate.patch`.
- Only changed repository file: `tests/lua/diagnostic_reward_protocol.lua`.
- Baseline PR196 head: `9a4cf64fb6c0f435bb8ad61a3f68f0549a2d03bf`, independently rechecked unchanged at 01:45 UTC.
- Original blob: `acf083ea4af31fe5d239c31b661296a4714951c5`; candidate blob: `dee30308eaf12ddf2b38263c7ecf56bf46a89159`.

## Root cause and change

The reward matrix repeatedly reconstructs deterministic Run, map and first-node combat state for only seeds 0, 33 and 42. The candidate caches those three complete pre-reward graphs, then gives every case its own alias-preserving `Combat.copy` of the entire run+map. Each fixture still kills its own enemy fixture, sets its own stolen-gold ledger and actually calls `Run.finishCombat`. No reward fields are patched. Diagnostic route loaders, strategy, seeds, samples and every existing assertion remain byte-for-byte unchanged.

Native profile counts: Run.new 51→10; Map.generate 51→10; Nodes.enter 70→29; Run.finishCombat 59→59. Combat.copy calls 503→424; measured copy time increases 0.123→0.192s because copies now include the complete cached graph. Total profiled CPU decreases 0.848→0.549s. Full before/after per-case profiles are in evidence.

## Verification

1. Baseline and candidate each pass all 50 cases on all six alternating timing runs. All six pairs of complete stdout+stderr are byte-identical.
2. `check-fixtures.lua` serializes all fields and internal reference aliases of run+map immediately before and after each of the 44 fixture Run.finishCombat invocations. All 88 baseline/candidate graphs are byte-identical. Each graph is also verified to contain no metatable, function, userdata or thread; mutable tables are disjoint across cases.
3. A pre-change runtime construction-cost check fails with Run.new=51 / Map.generate=51, then passes at 10/10 after the candidate. This check is a local optimization audit, not a proposed production timing threshold.
4. Negative controls are isolated runtime wrappers or throwaway copies, not repository changes:
   - Mutate nested run.data after a rejected duplicate completion: all 36 matrix cases fail their original atomicity checks.
   - Mutate nested map state after the same rejection: all 36 fail.
   - Swallow genuine invalid-gold rejection: the original API-error case fails.
   - Reuse cached tables directly: 41 cases fail.
   - Deep-copy the graph but re-share run.data: the independence audit fails at fixture.run.data.
5. All 81 other tracked files in the copied runtime match their frozen Git blobs. The sole untracked generated runtime input, abyss_data.lua, was rebuilt by the verified source build script from verified JSON. The copied runtime contains only the dependencies needed for these bounded tests, not a full checkout.

## Boundaries and next step

No production, Backlog, CI configuration, timeout, samples, strategy, remote branch or other worker's file was changed. No installation, full npm suite, user computer or user Codex was used. `backlog instructions overview` could not run because the CLI is absent; no Backlog change was attempted. Full suite and Fengari were not run per assignment. Root should independently review and integrate the patch, then require the exact integrated SHA's original CI gates. The old timeout remains historical evidence, not erased by this native proxy.
