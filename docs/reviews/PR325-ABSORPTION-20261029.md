# PR325 regression absorption into PR329

## Scope and provenance

PR325 `7f5728fa701c110cc626878649250ab8ca8e7c4b` extracts work from PR323; this small child of PR329 `62e075b226d8746d8bdff992f5299b9e83ba6438` conserves its unique valid offline regressions without another overlapping feature PR. No runtime, data, configuration, build/CI/scheduling scripts, existing Lua fixture, or 131-input source witness changes. No original assertion, hash, seed, timeout or worker limit is removed or relaxed.

Original PR325 source and its 11-input gzip witness are preserved by `refs/recovery/pr325-original-7f5728fa`. Witness SHA256 is `ff8fcf8c4bc81912b2046fc71eee573fca57f15fd3499a5621e613dcde90ab2c`. Each of its 11 complete 807 baseline sources is byte-identical to the accepted 20a source already pinned by PR329's strict 131-input dual-parent layer. Existing current-source validation, exact parent projections, CRLF and drift/missing/cross-path rejection remain unchanged. Do not import PR325's narrower helper stack over that composition or add a third inverse system.

The copied six-case Lua comment about scope approval is original historical wording, not a new pending/public-scope decision. Current competition remains Traveler/Ironclad only, Acts 1–2, with explicit full-source eight roles/frozen V4 Raiden retained. No persistent save, GIL, platform/device acceptance or AC closeout is claimed.

## All 32 original PR325 changed paths

| Path | Absorption / equivalent current guard |
| --- | --- |
| `backlog/tasks/task-30 - M3-出牌手感：防御等无目标牌拖到空旷处松手即打出.md` | Original PR325 implementation/provenance remains recoverable; do not replay stale task metadata/status. Current TASK-38 CLI note records absorption; all native ACs remain unchecked. |
| `backlog/tasks/task-59.3 - 完成正式开局和八种角色选择.md` | Original PR325 implementation/provenance remains recoverable; do not replay stale task metadata/status. Current TASK-38 CLI note records absorption; all native ACs remain unchecked. |
| `backlog/tasks/task-76 - 修复切出游戏再返回后界面无法点击.md` | Original PR325 implementation/provenance remains recoverable; do not replay stale task metadata/status. Current TASK-38 CLI note records absorption; all native ACs remain unchecked. |
| `config/luacheck-baseline.json` | Current combined baseline retained. The existing 131-input identity restores exact accepted 20a/807 baseline; no diagnostics are removed. |
| `data/presentation/ui_theme.json` | Current composed theme retains PR325 font normalization plus PR323 mobile/map work; native font/capacity/energy tests and strict 131-source guard cover it. |
| `docs/backlog-details/TASK-76.md` | Imported all 13 historical-only lines verbatim; same final document as PR325, no new device acceptance. |
| `scripts/build-ui.mjs` | Already byte-identical to PR325 at 62e; retained unchanged with current tests/source guards. |
| `scripts/map-ui-layout.mjs` | Current composed map keeps PR325 nativeFontSize normalization plus PR323 TYPE legend; exact current identity and accepted baseline remain guarded. |
| `scripts/native-ui-theme.mjs` | Already byte-identical to PR325 at 62e; retained unchanged with current tests/source guards. |
| `scripts/ui-layout.mjs` | Already byte-identical to PR325 at 62e; retained unchanged with current tests/source guards. |
| `src/lua/abyss_battle_card_view.lua` | Current composed view retains PR325 screen-space drop-line correction; extra PR323 potion aim/text rendering stays. Existing raw/mobile release tests and 131-source guard protect it. |
| `src/lua/abyss_card_input.lua` | Already byte-identical to PR325 at 62e; retained unchanged with current tests/source guards. |
| `src/lua/abyss_deck_ui.lua` | Same PR325 alive/GetChild, callback, update and close boundaries; current extra PR323 detail/keyword behavior retained. Unique destroyOnRecycle path now covered by the byte-original imported three cases and mutant. |
| `tests/approved-energy-orb.test.mjs` | Unioned PR325 exact 44px approved HTML and rounded native number/theme assertions; retained PR329 approximate assertion and every other existing assertion. |
| `tests/battle-drag-click-compatibility.test.mjs` | Imported broader raw-family discovery and missing/duplicate/wrong/noncanonical negatives only; PR329 strict accepted-source adapter and all original 15 bodies/hashes remain. |
| `tests/competition-roster-prepared-ui.test.mjs` | Imported broader raw-family discovery and missing/duplicate/wrong/noncanonical negatives only; PR329 strict runner adapter and all original 33 bodies/hashes remain. |
| `tests/fixtures/pr323-preserved-ui-layer.json.gz` | Not copied: original immutable PR325 witness remains in recovery ref. All 11 complete 807 beforeSource strings equal existing 131 accepted 20a records; current identities and two-parent/CRLF/drift checks supersede it. |
| `tests/helpers/approved-node-ui-refactor.mjs` | Current exact outer accepted projection, including sibling/override reads, already restores 807 before original immutable inner inverses. Do not replace it with PR325 thin import. |
| `tests/helpers/max-hp-accepted-source-inverse.mjs` | Current exact accepted projection before all preserved MaxHP inner sources already covers PR325’s 11 inputs; retained stronger current composition. |
| `tests/helpers/p0-presentation-inverse.mjs` | Current 131-input validation and complete materialization already supersede PR325’s 11-input materialization; original P0 hashes/negatives retained. |
| `tests/helpers/pr323-preserved-ui-inverse.mjs` | Not copied: existing pr323-accepted-source-inverse owns exact 131 current inputs and accepted 20a/original PR323 identities; no third projection system. |
| `tests/lua/mobile_card_release.lua` | Already byte-identical to PR325 at 62e; retained unchanged with current tests/source guards. |
| `tests/lua/native_cursor_fields.lua` | Already byte-identical to PR325 at 62e; retained unchanged with current tests/source guards. |
| `tests/lua/pr323_deck_lifecycle.lua` | Imported byte-original from PR325, including original assertions and default 30s runner budget. |
| `tests/lua/pr323_preserved_safety.lua` | Imported byte-original from PR325, including original assertions and default 30s runner budget. |
| `tests/lua/support/game_ui_fixture.lua` | Already byte-identical to PR325 at 62e; retained unchanged with current tests/source guards. |
| `tests/max-hp-accepted-source-inverse.test.mjs` | Current explicit accepted projection already feeds frozen original MaxHP source/hash/hunk/negative assertions; PR325 older helper is not needed. |
| `tests/mobile-card-release.test.mjs` | Already byte-identical to PR325 at 62e; retained unchanged with current tests/source guards. |
| `tests/pr323-deck-lifecycle.test.mjs` | Imported byte-original from PR325, including original assertions and default 30s runner budget. |
| `tests/pr323-preserved-safety.test.mjs` | Imported byte-original from PR325, including original assertions and default 30s runner budget. |
| `tests/pr323-preserved-ui-source.test.mjs` | Not copied: existing pr323-accepted-source-inverse.test covers all 131 complete sources, LF/CRLF, null, partial/appended/missing/cross-path drift. Historical materialization remains in existing strict P0 chain. |
| `tests/ui-capacity.test.mjs` | Already byte-identical to PR325 at 62e; retained unchanged with current tests/source guards. |

## Focused evidence

- Copied original two Lua files and two Node wrappers are byte-exact PR325. Node wrappers PASS 3/3: six safety cases, three lifecycle cases (including `destroyOnRecycle`), and removal of the native alive boundary is killed by the original `GetChild ... invalid object` assertion.
- Actual two-worker raw CLI rerun PASS 6+3. New unknown fixtures take the existing conservative exclusive worker path. Each retains the unchanged default 30s deadline.
- Stronger 15/33 discovery/source plus energy selection PASS 10/10. The original 15 and 33 bodies, all frozen hashes/hunks and 60/30s runner dispatch remain unchanged; no unnecessary heavy rerun of these unchanged bodies.
- Worker, 131-source, energy and new scheduling/discovery contracts PASS 16/16. This includes all 131 current inputs, both historical parents, CRLF/null and unknown/partial/appended/missing/cross-path negatives, original worker failure propagation, and exact approved 44px/native rounding checks.
- `pr325-absorption-discovery.test.mjs` verifies both raw fixtures and both wrappers exactly once across hosted Windows 8/Linux 4 JS plans and both raw worker plans, with conservative unmeasured-fixture weights; no timings or CI knobs change.

Evidence directory: `pr323-accepted20a-evidence-20261029/`, including `pr325-absorption-conservation.json`, `focused/pr325-preserved-safety-lifecycle.log`, `focused/pr325-raw-worker-rerun.log`, `focused/pr325-discovery-source-energy.log` and `focused/pr325-pure-contracts.log`. Original PR325 reviewer evidence stays independent. Exact new SHA still requires root review and full hosted Quality; neither PR325 nor PR323 is closed by this local child.

Syntax, Backlog roadmap verification and network-policy checks also pass. These offline checks do not replace the new exact-SHA full hosted Quality.
