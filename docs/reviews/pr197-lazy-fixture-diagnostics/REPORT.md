# PR197: lazy assertion diagnostics, current 308c target only

## Deliverable

Apply only `current-helper.patch` to head `308c1afa07fabb00f33d909a5a27739d8ec4bbae`. It changes exactly one line in `tests/lua/support/potion_basic_five_fixture.lua`: construct the existing `a ~= b` failure message only when the comparison fails. Equality is evaluated once. Only on failure, `assert(false, ...)` constructs the original message; diagnostic text and helper line number remain unchanged. No test body, expected value, setup, cache, seed, Run operation, timeout, split, production source, task or build-lua-data test is changed.

Original helper Git blob: `aafe7f86ce2ed069dc420eee3cfd5635c2481e37`.
Candidate helper Git blob: `55043be4d13a76754ebb1641e9d64e20217ab8f9`.
Candidate helper SHA256: `75593c31653541d6c935fa092ef0ca8bfce4359591c1f6850b1a2fdfa4a764b7`.

`superseded-0b34-candidate.patch` and everything under `baseline`, `candidate`, `evidence` are historical investigation evidence for the prior unsplit head, not the delivery patch. Do not apply the old patch or replace current split fixtures. The original author already changed the current fixture execution boundaries; this candidate neither introduces that split nor claims the aggregate timeout budget is unchanged.

## Current-head source verification

The five current files (basic/draw/status/helper and JavaScript entry) were fetched at 308c and each Git blob checked. `current-evidence/head-delta.json` confirms all runtime source/data files and the acquisition fixture are unchanged from 0b34. The previous 87-file Git-blob-verified source/materialization supplies those unchanged inputs. Generated `abyss_data.lua` came from the actual data builder. This is a minimal executed-source snapshot, not a complete checkout of every 308c documentation file.

## Failure-path semantic correction, 2026-10-24 23:34 UTC

The earlier optional candidate evaluated equality twice on a failure: once in `a~=b`, again in `assert(a==b, ...)`. A controlled stateful `__eq` returning false then true reproduced a real semantic defect: the original helper rejected after one comparison, but that candidate compared twice and incorrectly passed. Its red result is retained under `failure-path-evidence/pre-fix-current-candidate.log`.

The delivered one-line helper now uses `if a~=b then assert(false, originalMessage) end`. Three controlled `__eq` cases (false then true, always false, true then false) confirm both the original and corrected helpers evaluate equality exactly once, preserve pass/fail outcome, and produce exactly the same error on the two failing cases. The real current 2/5/4+1 fixtures, all eight earlier negative mutations, and cold-template/alias helper contracts were rerun on original and corrected candidates and passed their expected outcomes. Only the failure branch changed; the previously measured equality/tostring success-path counts below remain applicable. Full graph traces and full instruction profiling were not rerun or relabeled as new evidence.

A read-only PR197 check at correction still returned head `308c1afa07fabb00f33d909a5a27739d8ec4bbae`. No original branch or remote resource was changed. The superseded optional patch/report/hash are retained under `failure-path-evidence/pre-fix-*`; apply only the updated `current-helper.patch`.

## Measured work reduction, not a Windows performance claim

Current basic/draw/status equality invocations respectively remain 491,276 / 61,463 / 155,947, total 708,686 on both versions. Every original comparison still executes. Successful comparisons avoid two useless `tostring` calls and the failure-message concatenation.

Current basic/draw/status tostring totals:
- Before: 1,265,719 / 158,572 / 401,479.
- After: 283,167 / 35,646 / 89,585.
- Aggregate reduction: 1,417,372 calls, exactly twice the unchanged equality invocation count.

Native Lua 5.4 instruction hooks (one hook per 1,000 VM instructions; approximate counters, not Fengari timing):
- Basic: 22.208M -> 16.782M.
- Draw: 4.835M -> 4.156M.
- Status: 7.550M -> 5.828M.

No initialization or clone work is removed by the final patch. The prior unsplit baseline and one-line candidate both called Run.new 4 times, started 27 combats and invoked exported C.copy 241 times. In the current split execution, six untouched cold templates produce the same 27 private copies. The optimization is unnecessary success-path diagnostic construction, not cache sharing or skipped assertions.

## Current-head verification

Using only the existing native Lua 5.4 ctypes runner, each baseline and candidate fixture passed its real terminal marker: basic 2, draw 5, status 4, acquisition 1. The three current behavior fixtures record 86 / 29 / 51 real API calls. Canonical full before/after state graphs, including table-reference topology, are byte-identical between current baseline and candidate for each fixture. Hashes and byte counts are in `CURRENT-RESULT.json`; the large graph files remain local and are not delivery artifacts.

Independent cold-template checks passed on both versions: six Run.new templates unchanged after the three fixtures, 27 copies with no mutable-table sharing back into their templates, and all 27 fresh combat openings retaining player/enemy status-definition aliases. These are offline review guards, not added production/test changes. Important existing limitation: current 308c Combat.copy is the older recursive implementation and does not preserve every combat catalog alias on subsequent copies. The patch does not change or claim to fix that behavior; full API graph equivalence preserves the baseline exactly.

Eight deliberate negative mutations fail on both current versions with the same normalized diagnostic: rejection changes seed, Data, deck identity, potion identity, combat identity, or shuffle RNG counter; cold copy shares Data; fresh opening splits the status-definition alias. The first six are rejected by the existing real fixture assertions, the latter two by the independent review guard. Native pointer addresses in identity failure messages naturally vary.

`node --check tests/potion-basic-five.test.mjs` passed. `git diff --no-index --check` emitted no whitespace diagnostics; its exit 1 represents the expected content difference. A direct whitespace scan also passed. No full npm check, installation, user-computer access, production edit, remote write, push or merge occurred. Fengari is unavailable (`MODULE_NOT_FOUND`), so neither the old 30-second failure nor the current per-script 30-second budgets have been validated here. Current-head Windows CI remains necessary.

## Rejected approaches retained, not shipped

Caching whole cold combat graphs reduced constructors but increased copied graph work and pure instruction count on the old fixture, so it was rejected. Adding memoized pairs to `same` also increased instruction count relative to the lazy-diagnostic-only candidate, so it was rejected. Neither approach appears in the patch.

## Reproduce the delivered candidate

Working directory: `<review-directory>/current-candidate`.
Runner: `python3 $LUA54_RUNNER`.
Run each `tests/lua/potion_basic_five.lua`, `tests/lua/potion_basic_five_draw.lua`, `tests/lua/potion_basic_five_status.lua`, and `tests/lua/potion_basic_five_acquisition.lua` separately.

For short evidence delivery, use `current-helper.patch`, `REPORT.md`, `CURRENT-RESULT.json`, `current-evidence/checks.json`, `current-evidence/mutations.json`, and short `*-plain.log` files. The newest correction evidence is `failure-path-evidence/checks.json`, `failure-path-evidence/mutations.json`, `failure-path-evidence/post-fix-*-eq-contract.log`, and `failure-path-eq-contract.lua`. Do not upload the large `*-graph.trace` files.
