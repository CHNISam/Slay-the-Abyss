# bbf587e pure-seed integration result

## Result

The frozen five-path pure-seed candidate is compatible with all six newly partitioned fixture families at PR196 head `bbf587ef04307c389c73ae19d2e9649271f58b6e` in this bounded native Lua 5.4 check. All 49 upstream baseline entrypoints and all 50 candidate entrypoints exit 0. The candidate adds only the seven-group `run_seed_validation` regression. The 49 matching baseline/candidate stdout files are byte-identical; all 99 stderr files are empty.

No remote, production checkout, user computer, user Codex, or Backlog file was written. No installation, full npm, Fengari, Windows CI, game client, property sweep, repeated 588-input oracle, or 128-seed profile was run. These results do not establish the Fengari 30-second gate, full CI, or platform acceptance. Root remains the only authorized remote writer. The current PR head was rechecked after execution and remained bbf587e.

## Why scope changed

The original assignment was a nine-path combination on 9a4cf64. Before applying it, a fresh remote read found bbf587e had replaced all six old fixture entrypoints with partition wrappers and helpers. Root instructed retaining only the four independently reviewed pure-seed production changes and their new regression test. The four cache patches are superseded for this task and were neither applied, migrated, nor tested in the obsolete nine-path combination. No old whole-file fixture was restored over an upstream partition.

## Provenance and exact scope

- The complete non-truncated bbf Git tree was freshly retrieved through the read-only GitHub connector. All 191 snapshot inputs independently match their exact remote Git blob IDs. 129 came from read-only worker baselines only after blob verification; 62 were fetched at pinned bbf587e, including all 49 partition entrypoints and six new support helpers. The six stale old entrypoints were explicitly rejected as bbf baseline inputs.
- All 143 tracked paths under src, data, scripts and .github are blob-identical between the supplied 9a4 tree and the fresh bbf tree. All 59 Lua production modules and all data files are present in the bounded snapshot. This is a task-complete source subset, not a full repository checkout.
- `node scripts/build-lua-data.mjs` and `node scripts/build-ui.mjs` were run independently in baseline and candidate. All four build commands exit 0. Their 12 generated outputs are byte-identical; no worker-generated output was used as input.
- After build and all tests, a recursive byte comparison of every baseline/candidate file reports exactly five differences: `src/lua/abyss_randomxs128.lua`, `src/lua/abyss_sts_random.lua`, `src/lua/abyss_run_seed.lua`, `src/lua/abyss_map_topology.lua`, and added `tests/lua/run_seed_validation.lua`. All upstream fixtures, support files, data, numerics, CI scripts and budgets remain unchanged.
- The four production candidate blobs and SHA256s exactly match the independent seed-validation review's frozen manifest. The regression test SHA256 exactly matches the author's frozen artifact record. Both original patches and their concatenation pass `git apply --check` on the exact bbf snapshot.

## Executed coverage

| Family | Entry files | Printed passing groups | Preserved coverage |
|---|---:|---:|---|
| boss_reward_rarity | 4 | 8 | 128 seeds, 1 through 128; three unique rare choices per seed |
| diagnostic_reward_protocol | 9 | 50 | All 50 original groups, including 36 combinations and unchanged natural route |
| gremlin_gang_selection | 8 | 8 | All 1680 paths, eight disjoint first-index slices; original per-path body unchanged |
| growing_card_text | 12 | 18 | Original 11 groups; the 80-card case is eight disjoint 10-card batches, both versions retained, 160 labels |
| node_ui | 8 | 40 | All 40 original groups |
| play_area_coordinates | 8 | 31 | All 31 original groups |
| run_seed_validation | 1 candidate-only | 7 | Canonical/rejected seeds, normalization, wrap, overloads, constructor-free identity validation, independent RNG vectors |

The upstream baseline has 49 files / 155 printed passing groups; the candidate has 50 files / 162 printed passing groups. The group increase versus old whole-file tests is due to partitioned reporting, not invented cases. Each entrypoint runs unchanged in its own native Lua state, serially, using the supplied existing runner. No process hits the bounded 30-second subprocess timeout. Single-pass aggregate observed times were 7.733 seconds baseline and 5.674 seconds candidate including the new regression. These are native one-shot observations, not performance guarantees or Fengari timings.

## Partition integrity check

`audit-partitions.py` independently reads actual wrapper arguments and proves the disjoint ranges cover every original group, seed and path. For diagnostic, growing, node and coordinate helpers, removing only the registration wrapper reconstructs the original 9a4 source exactly; growing additionally restores its indexed-loop/range-count syntax. Boss reconstruction is exact after restoring loop bounds and two reporting strings. Gremlin's full per-path body is byte-identical; the eight first-index slices cover 8×7×6×5 paths, with unchanged per-path oracle checks and explicit partition/aggregate assertions. No coverage omission was found in this bounded audit.

One upstream evidence-format nuance: all six `helperSha256` fields in `ci-fixture-partitions.json` hash CRLF worktree bytes, whereas the committed Git blobs are LF. Converting each actual committed helper to CRLF reproduces all six declared hashes exactly. The snapshot uses and verifies the committed LF blobs; no helper or manifest was changed.

## Frozen deliverable

- Patch: `candidate.patch`
- Patch SHA256: `2846c91e580a373387887067ced22e9e260e949a71da3d839019c94bbeceeaf8`
- Exact per-path original and candidate Git blobs / SHA256s: `candidate-manifest.json`
- Complete stdout, stderr, command, working directory, exit code and time per invocation: `evidence/baseline-complete-output.log` and `evidence/candidate-complete-output.log`
- Structured per-file execution: `evidence/baseline-results.json`, `evidence/candidate-results.json`
- Byte comparison and per-family counts: `evidence/output-comparison.json`
- Source/range proof: `evidence/baseline-verification.json`, `evidence/partition-coverage.json`, `evidence/partition-diff-*.patch`
- Fresh build commands/results and output hashes: `evidence/build-results.json`, `evidence/generated-manifest.json`
- The original nine-path work is explicitly recorded as not executed in `SUPERSEDED.md`.

## Reproduction

From this isolated directory, run `python audit-partitions.py`, then `python run-partitions.py baseline` and `python run-partitions.py candidate` serially. The runner is `/workspace/scratch/331215e8236a/signed-cap-review/run-lua.py` using existing liblua5.4. To rebuild, run the two Node build scripts above in each snapshot. No package installation is needed. Root or the original author must check the then-current remote head before applying the frozen five-path patch and run the original exact-SHA CI gates before treating integration as complete.
