# TASK-12.1 independent map review

Reviewed revision: `2625fa0` on `feat/task-12-branch-map` (PR #14).
Reviewer: quality-gates, not involved in the map/random implementation.

## Result

No blocking issue found in the map/navigation/same-run snapshot scope. Only this document and the TASK-12.1 record were changed. No UI, storage adapter, combat integration or game verification was performed.

## Graph and navigation

- Generation produces 43 nodes: three choices on floors 1–14 and one Boss node on floor 15. Floors 1–13 have two distinct outgoing choices per node; floor 14 converges to the Boss. The Boss has no outgoing edge.
- Independent forward reachability and reverse dynamic programming checked every node for seeds 0–15. Each edge advances exactly one floor; every node is reachable from a start and can reach the Boss. Each map has 24,576 complete routes, or 393,216 across the 16 checked seeds. This is a structural proof/count over the real generated edges, not 393,216 individual combat playthroughs.
- Forced layers 1/combat, 3/treasure, 5/shop, 6/elite, 8/event, 14/camp, 15/Boss guarantee all seven node kinds on every route. Elite nodes never occur before floor 6.
- Every battle node references an existing encounter with matching tier and eligible floor range. Nonbattle nodes have no encounter ID.
- Existing tests verify deterministic seeds, encounter-order independence, legal branches, atomic rejection of unknown/skipped/repeated/backward/disconnected choices and isolated UI views.

## Snapshot and alias boundary

Restore regenerates the expected graph from validated seed and source configuration, replays legal path choices, then compares all structure and scalar values. It returns the regenerated state rather than copying attacker-provided graph tables.

Independent negative probes rejected 12 mutations without throwing: negative/out-of-range/fractional/changed seed, wrong random seed type, missing nodes, NaN floor, skipped path, cyclic path entry, graph-edge table cycle, cyclic nodes reference and a backward self-edge. Changed Boss-floor rules and encounter floor ranges also rejected. The committed suite additionally checks version, duplicate graph nodes, node/encounter tampering, sparse paths, unexpected keys and source-signature drift.

Same-value shared input tables can be accepted safely. Reproduction:

```lua
local snap = Map.generate(data, 42)
snap.nodes[41].nextIds = snap.nodes[40].nextIds -- both floor-14 edges contain f15_l2
local restored = assert(Map.restore(data, snap))
local expected = restored.nodes[40].nextIds[1]
snap.nodes[40].nextIds[1] = "input tamper"
assert(restored.nodes[40].nextIds[1] == expected)
assert(restored.nodes[41].nextIds[1] == expected)
restored.nodes[40].nextIds[1] = "output tamper"
assert(restored.nodes[41].nextIds[1] == expected)
```

The Sprint Lead clarified that the alias requirement protects against state pollution and permits safe normalization of equal-value input aliases. The probe also mutated the input path and node type after restore and verified the result remained unchanged. Both input/output separation and separation between restored nodes passed. Cyclic or structurally different aliases remain rejected.

## Completion semantics

`Map.view(map).complete` becomes true upon navigation into floor 15. It means the route has reached its last node. The map module has no combat dependency and does not produce `victory` or `outcome`; it does not assert that the Boss is defeated. Node-resolution gating and actual Boss victory must be supplied by TASK-13/TASK-17 integration.

## Executed evidence

`npm ci --ignore-scripts` followed by `npm run check` exited 0 on Windows:

- Syntax, six-table validation and Lua data build passed.
- 54 JavaScript tests passed, zero failures/skips.
- 15 core combat Lua tests and 10 map Lua tests passed.
- Python: 10 passed, one explicit Windows `WinError 1314` symlink privilege skip, zero failures.

Two temporary independent probes executed the real modules through the existing bounded Lua runner and printed:

```text
MAP_REVIEW_PASS seeds=16 all_path_count=393216 invalid_mutations=12 complete_is_victory=false
MAP_ALIAS_NORMALIZATION_PASS input_output_independent=true output_nodes_independent=true
```

No timeout or concurrency limit was raised. The map probe completed in approximately one second and the alias probe in under one second. For committed reproducibility run `npm run check`, or `npm run build:data` then `node scripts/test-lua.mjs tests/lua/map.lua`; the alias reproduction above can run as a temporary Lua file through the same runner.
