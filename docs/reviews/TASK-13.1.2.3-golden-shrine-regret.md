# TASK-13.1.2.3: Golden Shrine and the required Regret curse

2026-10-24. Bounded offline production slice under TASK-13.1.2. Base `1181764d32c561077986504ca1ae383450f746a2`; final integrated SHA and CI belong to the PR. This is a seventh complete event, not an isolated candidate and not completion of the full event-pool task.

## Complete playable behavior

- `Golden Shrine` maps to internal `golden_shrine`, presented with original generic text as `鎏金石龛`. A0 choices are +100 gold, +275 gold and one permanent `regret`, or leave without changing assets. No random roll is added by construction or choices.
- The production `restricted-seven` pool contains four ordinary events, three shrines and zero one-time events. Golden Shrine is inserted in source shrine order before Purifier and Upgrade Shrine; it has no extra eligibility filter. It is removed when selected on entry, not when a choice is made. Historical `restricted-six` and the unchanged full audit catalog remain explicit modes.
- The existing 25% shrine-branch decision, bounded index draw, fallback and exhausted-pool diagnostics remain. Adding a supported shrine changes specific-event distribution: this restricted pool is not the original full distribution. Unsupported events are not drawn and rerolled.
- `regret` is the sole newly enabled curse ABI: type/rarity `curse`, cost -2, empty ordinary use, no upgrade, ethereal, exhaust, innate or repeatable behavior. Player-facing name/text are independently written as `余悔`. It is not in the starter, reward or shop pools, cannot be upgraded, persists between battles, and can be removed by existing UID-based services.
- Desecration validates the required catalog entry and a non-colliding advancing safe permanent UID before changing gold, deck, UID allocator or node completion. Missing/malformed data and invalid allocation reject atomically; accepted and stale repeated choices cannot award twice.

## End-turn action contract

Every held Regret captures the same initial full hand size before any end-turn card is used. Each queued copy is then removed from hand into `cardInUse`, applies HP loss, and is discarded if alive. Later copies do not resample the shrinking hand. Dazed and other ethereal cards count toward the initial amount because ordinary discard/ethereal processing happens later.

The trigger is not a player card play: no energy payment, ordinary play/use reaction, normal attack calculation, block absorption or extra random draw occurs. Supported Strength, Weak, Vulnerable, Thorns and Artifact do not modify this HP loss. The existing HP-loss presentation event is used.

If a copy is lethal, the source death screen halts the action manager before its later UseCardAction. The current curse remains in `cardInUse`, earlier copies remain discarded, and later copies remain in hand. No later curse, regen, temporary-Strength removal, ethereal cleanup, enemy action or next draw runs. Run defeat and native game-over/restart UI are exercised, not inferred from a standalone damage call.

## Fixed source and random/version limits

The source is the third-party decompilation mirror `purewhitelove/ButterflyGame@fc379c875c11e008e9c10548ac8e394c301c532f`, not an authenticated official game build. Full source paths, blob SHAs, links and independent byte verification are in [the source ledger](../evidence/golden-shrine-regret-source.json). The implementation is independent; no source code, original narrative, artwork or audio was copied into production.

Key contracts:

| Source | Git blob | Verified responsibility |
| --- | --- | --- |
| events/shrines/GoldShrine.java | `22e1ee260a216673eae76d7d5ada4caf2e2b499c` | A0 +100, +275 and Regret, leave; no option RNG |
| cards/curses/Regret.java | `f8d952467eefb802fe536757e59c3016d2a6e9d6` | Full-hand capture and auto-use HP-loss action |
| actions/GameActionManager.java | `931cded5ae1aed78771e0a5389e8358946b78f8f` | Capture all queued cards before resolving, suppress normal play hooks |
| characters/AbstractPlayer.java | `a543883e0b4b6d32723ec1ebd00b4d632296b231` | Remove current card before queued resolution, player damage and death |
| actions/common/LoseHPAction.java | `b17ea693ee62134f4d7f10d56e72f4c25d5fd460` | HP_LOSS type rather than NORMAL attack |
| actions/utility/UseCardAction.java | `3069a750b5c07b1a1c8aebfcf021984cad9a8a5a` | Subsequent discard; no normal use reactions |
| screens/DeathScreen.java | `0dcb52bf576a4ac264fb273f8bdec1570617133f` | Death blocks further action-manager updates |
| dungeons/Exordium.java | `4da51b8f6bbddbdd30eed7d28645037c784da0c6` | Golden Shrine is in ordinary shrineList |
| dungeons/AbstractDungeon.java | `0b56f48444f990fec0225747f19125eab17233af` | Shrine selection, eligibility and consume-on-selection |

The event uses the existing event-selection stream contract and adds zero eventRng/miscRng draws during option execution. This does not verify global map/combat/reward random-stream parity, official target JAR identity, or complete event eligibility. Scrap Ooze and Duplicator audit conflicts remain untouched.

Important limitation: this mirror caps Regret HP loss at one with IntangiblePlayer. Intangible is absent from the playable status catalog and is not implemented here; no test or claim says HP loss bypasses it. Evolve and curse-acquisition relics such as Omamori are likewise absent from the playable inventory. Future introduction must implement their source interactions before enabling them; this slice does not invent a generic curse, power or relic framework, nor rewrite unrelated poison or self-damage contracts.

## Regression evidence and integration boundary

Missing-feature reds preceded production: 14 runtime failures, canonical data/schema/presentation failures, generated-node UI failure, and curse UI failure. Independent review found the missing optional-field preflight and prototype type/icon mappings; both received red-to-green coverage. Original 39-card fixture counts were explicitly updated to 40 total (37 class cards, two statuses, one curse), not relaxed to arbitrary counts.

Local commands use existing tools only, without installations or the user's Codex:

- All 122 repository Lua fixtures passed using the existing system Lua 5.4 library runner, including 19 event/curse runtime groups, five independent boundary groups, generated node UI, curse battle/deck UI, and lethal game-over. This is not a Fengari/full platform claim.
- 920 direct JS checks across 51 non-Fengari files, 16 additional selected pure-JS checks, and one actual prototype `cardEl` rendering check passed. Two fixed RNG/pool-vector JS fixtures also passed with only their Lua launcher replaced by the existing native runner.
- All 17 Python presentation tests passed in the isolated prototype composition containing the one new row plus five type/icon/style mappings. The ordinary working prototype was deliberately not overwritten while another change owned its branding.
- Data validation, generated data/UI/theme/map artifacts and JavaScript syntax checks passed. The first broad JS attempt exposed unavailable `fengari-node-cli` through the map-export wrapper; it is recorded as unavailable, not a gameplay failure or a full-suite pass. Full npm/Fengari Quality remains the exact-head CI gate.

The isolated prototype delta uses the approved existing status icon/type color and line border, with a Chinese curse label. It changes neither layout nor branding. Canonical lore-v2 input and presentation files remain unchanged. Final composition must run the new `tests/prototype-regret.test.mjs` and full Python checks against the actually integrated prototype, not only the isolated copy.

No candidate export, official import, in-game playtest or same-candidate UI acceptance was performed by this slice. M1, TASK-12.3 and TASK-13.1.2 remain open on their own evidence boundaries.
