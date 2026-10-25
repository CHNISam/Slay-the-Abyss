# Pure-seed candidate: 088a6ab incremental compatibility

## Outcome

The unchanged five-path candidate still applies cleanly to PR196 head `088a6ab6d2fe47dd3bdb4a74bd4e3d01e69e0224`. The requested incremental native Lua 5.4 scope passes: 11 baseline files / 57 printed groups and 12 candidate files / 64 printed groups, all exit 0. All 11 matching baseline/candidate stdout and stderr pairs are byte-identical; stderr is empty. The extra candidate file contains the seven seed-validation regression groups.

The PR head was freshly read after execution and remained 088a6ab. No upstream pure-seed edit or pre-existing `run_seed_validation.lua` was found. This is a local candidate only; no remote or production checkout was changed.

## Source and build integrity

- The full, non-truncated 088 Git tree was freshly retrieved through the read-only GitHub connector. All 196 focused snapshot inputs were independently checked against their exact Git blob IDs.
- 186 unchanged inputs were copied from the previously verified bbf baseline only after matching the new 088 tree. Ten remaining inputs were fetched from pinned 088: the current data sources/launch-content files; event_pool, fountain, node_ui and nodes modules; the Fountain core/UI and potion-target tests; and their potion gesture support dependency.
- All 60 current production Lua modules and all data files are present. The four pure-seed production baseline blobs are unchanged from bbf and match the frozen candidate's expected original blobs.
- Both snapshots freshly execute `node scripts/build-lua-data.mjs` and `node scripts/build-ui.mjs`. All four build commands exit 0; all 12 generated files are byte-identical between baseline and candidate.
- After execution, recursive comparison of every snapshot file finds exactly the original five candidate differences. The four production candidate blob IDs and new regression blob ID remain identical to the previous independently reviewed/frozen candidate. No partition, case, seed, numeric value, CI script, or budget was changed.

## Fresh 088 execution scope

| Fixture | Files | Passing groups in each applicable snapshot |
|---|---:|---:|
| node_ui and slices 2–8 | 8 | 40 |
| fountain_event | 1 | 7 |
| fountain_event_ui | 1 | 3 |
| potion_target_rejection | 1 | 7 |
| run_seed_validation, candidate only | 1 | 7 |

The supplied native runner executes files serially, in separate Lua states, without hooks or fixture changes. All commands, complete stdout/stderr, exit codes and durations are retained in `evidence/baseline-complete-output.log`, `evidence/candidate-complete-output.log` and `evidence/execution-results.json`.

The prior bbf 49-partition compatibility evidence remains unchanged in the parent directory and belongs to bbf, not 088. This follow-on intentionally does not rerun unrelated partitions, the 588-input oracle, property scans, or the earlier full profile. There is no claim that all 49 families were re-executed at 088.

## Frozen handoff

- `candidate.patch`, unchanged SHA256: `2846c91e580a373387887067ced22e9e260e949a71da3d839019c94bbeceeaf8`
- `candidate-manifest.json`: now identifies base 088 and lists the exact five original/candidate blobs and candidate SHA256s.
- `evidence/input-verification.json`: all 196 input blobs and hashes.
- `evidence/generated-manifest.json`: 12 freshly built output hashes.
- `evidence/summary.json`: counts, output-pair equality and exact changed paths.
- `FROZEN.json`: final artifact checksums and rechecked remote head.

## Limits

Native Lua 5.4 compatibility does not establish Fengari's 30-second gate, full CI, live-game behavior, or platform UI acceptance. No package installation, full npm suite, user computer, user Codex, Backlog mutation or remote write occurred. No running CI was touched. Canceled earlier runs are not treated as green; this check makes no claim about the outcome of ongoing exact-SHA CI. Root or the original author must verify the current remote head before applying the patch and use the original exact-SHA CI gates for integration.
