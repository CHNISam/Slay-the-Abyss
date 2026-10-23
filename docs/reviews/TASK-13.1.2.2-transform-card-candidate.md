# Event transform selection candidate

TASK-13.1.2.2, under TASK-13.1.2. Base: `9d81126ea930c3fdaeab4fb5a99443d91e6b4080`.

## Boundary

`tools/candidates/transform_card.lua` is an independently written **candidate-only selector** for the `autoUpgrade=false` path used by Living Wall and Transmogrifier. It is not imported by production, enables no event and does not modify the six-event pool, permanent deck, Run, Nodes, combat, data or UI. A future integration must supply complete, version-verified ordered source pools; the project's present partial card pool is **not** a substitute for the original distribution.

API: `select(category, prohibitedId, pools, rng)` returns a fresh `{cardId=..., upgraded=false}` and an advanced **cloned** `abyss_sts_random` state. A refusal returns `nil, reason`. Input pools and RNG are never mutated. The caller owns the category classification and source-ID mapping; identifiers are card IDs, not permanent deck UIDs.

- `colored`: concatenate supplied `common`, `srcUncommon`, `srcRare`, in that order. These names deliberately distinguish the mirror's **current common** from **source uncommon/rare** pools. Do not silently change them to all-current or all-source pools.
- `colorless`: use supplied `srcColorless`, not the current colorless pool.
- `curse`: use supplied `curses` in its caller-provided enumeration order, removing the original ID and `Necronomicurse`, `AscendersBane`, `CurseOfTheBell`, `Pride`.
- All branches exclude every occurrence of the original ID before sampling. Other duplicate IDs retain their multiplicity and position. No rarity roll, sort, deduplication or rejection-resampling of prohibited IDs is added.
- Selection consumes one inclusive bounded RNG **wrapper** call, including a singleton pool. The curse branch uses `randomIntBetween(0,n-1)`; the other branches use `randomInt(n-1)`. Internal primitive rejection can consume more than one 64-bit draw, without extra wrapper counter increments.

Only the selected category's pool groups are required and inspected. Each must be a plain dense array of nonempty string IDs; outer and selected-pool metatables are refused. Empty filtered pools, malformed inputs and invalid RNG return explicit reasons without committing any random state. This defensive input/empty-pool API is an integration contract, not a claim about the original engine's malformed-input behavior.

The descriptor intentionally has no permanent UID, acquired-card modifiers, old-card upgrade state, or rarity/type metadata. A future adapter must atomically commit the returned random state, remove the selected permanent card, acquire the replacement with all relevant hooks, and complete the event. Replaying this function with the same inputs is deterministic; it does **not** provide exactly-once inventory acquisition. It does not implement the general `autoUpgrade=true` path.

## Fixed source identities

Mirror: `purewhitelove/ButterflyGame@fc379c875c11e008e9c10548ac8e394c301c532f`. All four files were fetched at this exact commit and their complete UTF-8 content recomputed as Git blobs; hashes matched the connector and existing event ledger where indexed.

1. [AbstractDungeon.java](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/dungeons/AbstractDungeon.java), blob `0b56f48444f990fec0225747f19125eab17233af`, SHA256 `7fffaba8861ac461219dd5e6ef2dc8bbc4496434a81513e32b71bffa4c080eef`. Lines 1031–1036 identify COLORLESS/CURSE switch cases; 1223–1241 route transformation and make a fresh copy; 1439–1452 filter source colorless; 1454–1507 flatten the colored branch's exact groups and draw once.
2. [CardLibrary.java](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/helpers/CardLibrary.java), blob `eb2c14b80bbf25c4b6c622dd4339bfbc88d40704`, SHA256 `9c4b12b0129667062a47900034688e7baffcfb30f8f68d5508e32b3b0a298d2f`. Lines 833–845 filter original and four special curses, retaining map enumeration order, then use the supplied RNG. This candidate does not invent or sort the Java map's enumeration order.
3. [LivingWall.java](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/events/exordium/LivingWall.java), blob `6c711975d7cfe35e166a9a1ef947656153d09884`, SHA256 `c6cb733606779b86e09f11127954e97c83c13496b525500ee6ec9448db344093`. Lines 161–166 remove the selected card, transform with `false` and `miscRng`, then schedule acquisition.
4. [Transmogrifier.java](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/events/shrines/Transmogrifier.java), blob `f0f6fdb215ccc3a440a80958a81cf8ab575f62f0`, SHA256 `d89d81161b2aa032b12c85ffd9866aa63227e734a00f1aa71490bbc2a464cf25`. Lines 79–88 use the same `false`/`miscRng` transformation-and-acquisition flow.

The existing `abyss_sts_random` and `abyss_randomxs128` modules are reused unchanged. This adds no new RNG algorithm and does not replace any run-wide stream. The mirror is not an authenticated official PC target binary; `STRICT_PC_PARITY_UNVERIFIED` remains. Full catalog composition, unlock/relic-dependent pool construction, Java map iteration order, target-version fidelity, all card/curse effects, event eligibility and acquisition hooks remain outside this slice.

No original game source, presentation, graphics, audio or prose is shipped by this change.

## Verification

`tests/lua/transform_card_candidate.lua` has 20 groups. It checks each possible ordered slot of supplied colored/colorless/curse pools, original/special exclusions, preserved duplicates, source-group distinctions, singleton consumption, signed32 counter wrap, detached results/input RNG, malformed and metatable-bearing inputs, six independently calculated signed64-seed vectors, and a bounded-RNG rejection fixture.

Tests first: the absent selector produced `transform selection candidate must exist`, exit 1. After implementation, all 20 groups pass under the existing native Lua 5.4 helper. Seed vectors were independently derived with Python arbitrary-precision integer arithmetic rather than the Lua candidate or its helper. The crafted rejection case starts at words `07e07ff03fffe000/0000000000000000`, rejects first raw `ffffffffffffffff` for bound 3, selects slot 3 on the second primitive draw and increments the wrapper counter only once.

Twelve local negative controls fail as expected: wrong common source, swapped tier order, wrong colorless source, retained original, retained special curse, global special-curse filtering, input RNG mutation, double draw, off-by-one bound, skipped singleton draw, inherited upgrade and accepted sparse pool. Candidate bytes were restored after every mutation batch and the final clean suite rerun.

All 94 Lua test files also passed under the existing native Lua 5.4 helper, using the cached generated data/layout fixtures. The battle UI file passed 51 groups with a local wrapper supplying its required layout from cached `battle-ui.json`; no generated fixture was claimed freshly rebuilt. All production `src/lua` and `data` blobs were rehashed against the frozen develop tree with zero mismatches.

No npm installation/full check, Fengari execution, platform build/import/playtest or official PC binary comparison was performed. Native regression results and independent review are reported with the delivery; root must verify the exact published head's Quality checks before integration. Parent TASK-13.1.2 and all playable-event/platform acceptance remain open.
