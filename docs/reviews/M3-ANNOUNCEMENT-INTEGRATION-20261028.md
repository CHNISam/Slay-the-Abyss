# M3 source integration: announcement retirement and historical design sources

This is source-level integration evidence, not native-device, publication, or full hosted Quality acceptance.

## Exact inputs and ownership

- Accepted main: `9875c128c3eadb34075efd81e45205f0bbe20736` (PR283); the existing integrated parent is `b9d071e5dd8a8ebb1c5d71b4f0b5671b30a44527`.
- PR282: `d7fa6f219a1461cf2b461f03724fb00da79e621f`. Its author history (Codex and Furinya / CHNISam) is retained as a merge parent. Announcement removal, official-log documentation, and the existing v0.11.0 preparation are retained; no Tag, Release, or publication is performed.
- Existing PR267 / PR265 / PR256 / PR268 production behavior remains intact. The only production Lua changes from the integrated parent are PR282's host/entry announcement retirement and deletion of `abyss_release_notes_ui.lua`. No battle, card-display, rule, art-layout, Nest, drag, shop, or camp implementation is changed.
- Historical canvas source: `b6fb0f4a506d431b05a11d04dd05518cd6ec8b72`, author 潘洪森 / CHNISam, with Claude Opus 5.5 collaboration. The 16 original text blobs under `docs/design/ui-canvas/` (124527 bytes) remain recoverable from that commit. The integrated copy retains 15 blobs unchanged; `Map.dc.html` removes only four trailing spaces on blank line 85 to satisfy the existing whitespace gate. Its original blob is `a8c89f2a4f4639c1a9c17a177a6384df7457e3d9`; reinserting those four spaces reproduces it exactly. Associated with existing TASK24 / TASK25; no task is created or marked Done.
- Canvas is historical design material, not an offline-complete or production runtime. `support.js` / DCLogic and five Main `/_blob` images are absent; none are downloaded or executed. Its PatchNotes proposal is superseded by PR282. Its historical advice about discarding other worktrees is not an instruction to execute.

## Conserved trace proof (not a replacement golden)

All earlier archives and their pinned hashes remain unchanged:

| Stage | Writes | Ordered hash |
|---|---:|---:|
| Original e0 | 72915 | 148113441 |
| Accepted c5 / PR261 compatibility | 77278 | 1948853637 |
| Accepted room port | 79543 | 1215629804 |
| Reviewed M3 frame / first UI batch | 79757 | 1467902785 |
| PR282 alone, still independently checked | 79475 | 1007819925 |
| Composed M3 + PR282, actually executed | 79689 | 2034622601 |

The PR282 `before` array is exactly equal to the frozen M3 `before` array. The M3 proof still checks its 214 additions (156 rarity decoration, 58 node cost ink), 593 replacements (40 rarity ink, 13 energy ink, 512 enemy geometry, 28 target-flight writes), and all 78950 otherwise unchanged writes. PR282 retires exactly the same 68 announcement-owned rows from the M3 result, in value and order. The composed live scenario compares **every one of its 79689 writes** to this independently derived sequence while also retaining the original strict recorder and interaction assertions. Negative tests retain rejection of restored notices, lost visual changes, deleted/changed/reordered unrelated writes, and added writes.

The first combined raw run intentionally failed the old 79757 final assertion and printed `79689 / 2034622601`; the derived conservation proof independently produced that exact result before the current assertion was adopted. No budget or deadline is raised.

`m3-announcement-retirement-sources-20261028.json.gz` archives eleven exact pre-retirement source files from the integrated parent, including the deleted module and affected build/layout/host/version inputs. Its SHA256 is `0d31e4bb052cd578db29062e63708f739ff3e4719f75e50580b7ee119515959a`. Current identities are strictly bound; theme geometry has an exact inverse, and the entire trace scenario before its final assertion is unchanged. These historical sources are restored only into repository-local temporary test trees. Both original 79543 and 79757 fixtures execute with their original guards and 30-second deadlines; the live runtime never restores the removed controls.

## Local validation

- Four presentation / M3 UI contracts: 17 tests passed (47.4 s), including exact 79543 replay (12.66 s), composed live per-write guard (18.85 s), and all old/new negative controls.
- Additional original 79757 fixture replay passed (14.07 s).
- Architecture: 214 modules / 1237 edges; Luacheck 1.2.0: no new diagnostics, all 84 historical warning entries unchanged; battle render <=10, scoped functions <=15, 418 governed measurements. Removing the retired module/responsibility is the sole budget inventory change.
- Backlog metadata and JavaScript syntax checks passed.
- Host/package/native-startup/release contracts: 53 tests passed (55.75 s), including original game-entry fixtures with 16 host / 6 deck / 10 prologue cases, announcement absence, version-only menu, package provenance and corrupted-readback rejection.
- Battle-speed pointer/modal gestures: all 11 cases passed; all four test-strength mutants killed by assertions; network policy passed.
- Before whitespace normalization, canvas source inventory verified all 16 Git blob identities and the exact 124527-byte total. The local verification manifest is `build/integration-review/canvas-source-manifest.json`. The normalized integrated copy totals 124523 bytes; verification against the pinned original confirms that removing the four line-85 spaces is its only difference. CI run `40642057675` failed all rules shards at `git diff --check` before tests because of this whitespace; the gate is unchanged.

Hosted full Quality, actual merged-head verification, native import/device testing, and real publication remain separate gates owned by the parent execution flow.
