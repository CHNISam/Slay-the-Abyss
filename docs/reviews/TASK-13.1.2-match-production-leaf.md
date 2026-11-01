# 留影牌局：Match and Keep! production leaf

Base: `1dc33fe790a5f82be4f1bf2f0d09e339dcb943dd`. This implements the missing leaf under existing TASK-13.1.2; TASK-13.1.2.1 remains the historical supplied-board reducer only. No reduced event/card pool or reroll fallback is introduced. The player-facing name and short Chinese copy are independently authored; card faces use existing project names and CardDisplay.

## Fixed behavior evidence

Read through the authorized GitHub connector on 2026-10-29, at `purewhitelove/ButterflyGame@fc379c875c11e008e9c10548ac8e394c301c532f`, below `杀戮尖塔原码/`:

| Source | Git blob |
|---|---|
| [events/shrines/GremlinMatchGame.java](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/events/shrines/GremlinMatchGame.java) | `f86144bdf0e00acad096e8668f17fa96d6aabac1` |
| dungeons/AbstractDungeon.java | `0b56f48444f990fec0225747f19125eab17233af` |
| cards/CardGroup.java | `c68b25ad094b8cc04a0e380db8e67a1fb1f3bfe4` |
| helpers/CardLibrary.java | `eb2c14b80bbf25c4b6c622dd4339bfbc88d40704` |
| characters/Ironclad.java | `5f43b50acac9a180f88be8afee938476a9734524` |
| characters/TheSilent.java | `342a2877e4bbc8dc89e55242e5a3d8b6a9d682ac` |
| characters/Defect.java | `74559873e3e8c54d12e321d107d0d878ffadd4e6` |
| characters/Watcher.java | `7c55b6a1da5d73d46e88404d68135fcc3fd1b6d1` |

A0 construction samples class rare, uncommon, common with three direct `cardRng` identity draws; then shuffles the **entire 35-card current colorless pool** using one floor-local `shuffleRng.randomLong`, choosing the first uncommon; then samples the ten ordinary curses with one `cardRng` draw; then creates the class start-event card (Bash, Neutralize, Zap, Eruption). It does not roll rarity, pity, reward count or random upgrades. Preview relic hooks run on six originals, then six stat-equivalent board copies are appended. One room-local `miscRng.randomLong` seeds Java Collections shuffle for all twelve cells.

Two reveals compare source card IDs. Both matched and mismatched pairs spend one of five attempts. A match waits one second, obtains one **fresh makeCopy**, and removes two cells; mismatch waits 1.25 seconds and conceals both. The fifth pair still awards before one-second cleanup and the separate final Leave. There is no early Leave/cancel/skip. Searing Blow uses the project's existing constructor-count makeCopy convention; ordinary preview upgrades are not copied to the permanent award, and actual obtain hooks run normally.

This mirror is behavioral evidence, not authenticated execution of an official PC binary. Native animation/frame timing and device behavior are not certified by offline tests. No original code, prose, artwork or audio is copied.

## Canonical mutable colorless owner

`run.colorlessCardPool={act,cards}` is a same-run mutable owner, not static data. Its first use in an act copies existing `sourcePools.colorlessRaw`, not reversed `srcColorless` or a filtered rarity bucket. Subsequent uses retain shuffled order; the next act resets it because source AbstractDungeon construction initializes card pools again. The complete Run transaction/snapshot owns it, including aliases and failures after its shuffle.

Consumer audit at this base: Neow and shop read sorted colorless rarity lists; Sensory Stone sorts a temporary rarity list; potion/card generation and transformation read source pools. No existing production consumer owns or shuffles the current 35-card pool. `docs/backlog-details/TASK-16-card-pool-catalog.md` already records that missing mutable-pool boundary. Adding this owner for Match does **not** certify or change those other consumers' recorded parity gaps.

## Root integration contract

- `abyss_match_event.prepare(run,event,miscRng,roomFloor)` returns `true` or `false,reason`. Call inside the existing entry rollback boundary and abort on false. Both arguments are required: Nodes prepares the destination event **before** publishing `run.floor` or `run.miscRng`; pass existing staged `miscRng` and `node.floor`. `Run.roomStreams(run,roomFloor).shuffleRng` supplies the actual signed64 seed-plus-floor stream. No prior-room stream is used.
- `options(run,event)` returns intro Continue, rules Start, or result Leave; no board-stage options.
- `choose(run,flow,choice,token)` runs inside Nodes' existing `Run.transaction`. Continue/Start/Leave take no token. Flip takes a slot token; Resolve takes its pending pair token; Finish takes cleanup token. A successful final Leave returns `true,'complete'` for the existing Nodes completion owner. Everything else retains the node as pending.
- `view(run,event)` is called on the already detached view copy. It removes private `board`, shuffle RNG and selection internals, replacing them with `event.match` display slots and tokens. Concealed/removed cells disclose no identity. Revision + room-generation + destination-floor tokens reject stale/replayed commands. Board cards have no permanent UIDs.
- `scripts/match-event-layout.mjs` exports `augmentMatchEventPicker(picker,theme)`: call it on the existing picker spec. It preserves the existing twelve full-size forge card faces and their single hit areas, adding opaque `matchBack` overlays and one `matchRetry` button. The 6×2 arrangement is a platform layout adaptation, not a new renderer or shrunken-font board.
- Exact control audit: baseline node tree has 4,642 controls and generated game tree 10,491. A rejected duplicate-face approach added 1,921 controls. Reuse adds **57** (12×4 overlays +9 retry), with twelve grid children,39 direct children per cell and20 picker children (each below64). All original cell specs excluding the new overlay remain byte-structurally identical; this is not an upload-byte or performance measurement.
- `abyss_match_event_ui.install(ctx)` provides `ctx.renderMatch(view,node)`, `ctx.resetMatch()` and `ctx.updateMatch(dt)`. `isBoard(event)` selects an explicit Match picker mode for play/resolving/cleanup. Existing `pickerView/forgeGrid/card1..12` inputs receive Match-owned actions/tokens; `inputPaths()` supplies only NEW `pickerView/matchRetry` for the normal generic/native/controller binder. Branch before ordinary picker rendering; no paging/back/confirm. Call resetMatch before any non-Match render, and updateMatch from normal lifecycle update. Intro/rules/result retain standard eventView rendering.
- Concealed cells are never passed to fillCard. Prior face child visibility/text is saved, all face fields hidden and text cleared, native artwork cleared, and back children explicitly non-raycasting. Reveal restores the reusable face then invokes existing fillCard. Reset restores pre-Match visibility/text, hides overlays/retry and retires Match callbacks via an epoch. The unchanged real camp renderer then repopulates the same controls normally.
- UI uses existing `ctx.fillCard`/CardDisplay and `ctx.commit('chooseEvent',choice,describe,token)`, never a private award callback. Visibility, view identity, run/map/flow/event ownership, native attachment and revision guards retire stale actions. Failed resolution preserves the exact pair and all owners, pauses automatic resolution, and exposes one explicit retry; no automatic retry loop and no skip-award escape.
- Root owns central dispatch/EventPool/theme/layout registration and architecture classifications (`abyss_match_event`: core; `abyss_match_event_ui`: ui). This leaf worktree does not edit those shared files or Backlog metadata.

## Verification boundary

`tests/helpers/match-event-oracle.mjs` is an independent BigInt XS128/Java48 interpretation using the pinned source-registration facts, not production Lua. Four class vectors cover direct sampling order, room seed signed64 wrap, both shuffles, final pool order and full RNG continuations. `tests/match-event.test.mjs` regenerates these vectors and runs the dedicated bounded Lua files. The UI test uses this leaf's generated native layout when wrapped by Node, or the integrated generated `abyss_ui_layout` during the full raw Lua suite.

Actual command results and remaining integration/native acceptance are reported by the root from its final composed tree. A passing leaf suite is not full event-pool integration, full Quality, original-PC binary parity, official import/ready, natural route coverage, or PC/phone UI acceptance. No commit, push, PR, merge, build publication or device input is performed by this leaf.

## Production integration evidence (2026-10-29)

The composed candidate now registers both Match and Duplicator in the existing full EventPool and dispatches them through Nodes, Run transactions and the shared native NodeUI picker. It does not shrink, filter or reroll either source event pool. The controlled room tests cover admission, staged room floor, detached views, five Match awards, result/leave, Duplicator unique permanent copy and unchanged command RNG. Native-mock tests cover concealed identity, stale owners, picker transitions and explicit retry. These remain offline tests, not natural-route or device acceptance.

The test-only outer event source layer stores all 20 changed production/script/config/content inputs as complete before/after sources. Before sources are bound to Git `1dc33fe790a5f82be4f1bf2f0d09e339dcb943dd`, and genuinely new modules have null before sources. The later accepted death-settlement guard is disjoint from these 20 inputs and composes through its own unchanged guard layer. Historical witnesses, native-write assertions, time budgets and the accepted death helper are not refreshed. Current event tests execute the live modules without projection.

Source identity, CRLF equivalence, wrong/partial/duplicate/reordered inputs, missing sources, cross-path inputs and all-before-write validation have explicit negative controls. The outer materializer removes only exact added event modules from isolated historical trees and preserves older materializers' existing path ownership; unknown destination bytes fail rather than being overwritten.

This slice closes only Duplicator and Match. Other unmapped first/second-act events remain incomplete under TASK-13.1.2; the full event catalog and their eligibility/order remain present, and M3 is not complete. The mutable colorless-pool limitation of other existing consumers documented above remains unresolved. Neither this slice nor its historical replay proof certifies full original-game RNG parity or a complete natural two-act run.

## PR334 CI closeout

The original failing jobs all rejected the unregistered complete launch-content source. Its complete Git1dc before source and current after source are now registered in the event archive. No prior before source or historical runtime assertion was changed. A separate complete two-file integration witness binds the merged Combat/Run sources to both immutable event and nested-snapshot-owner inputs; unknown, partial, wrong-path and appended bytes remain rejected. The architecture whitespace guard still checks every token before exact projection.
