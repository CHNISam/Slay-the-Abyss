# Map floor boundaries implementation plan

**Goal:** Apply the verified generated-row and separate-room boundaries from PR #59 without claiming original generator parity.

**Architecture:** Keep map navigation and snapshots in `abyss_map`. Distinguish 15 generated rows from Boss floor 16 and its independent treasure room on floor 17. Expose the latter through the existing navigation API using `type=treasure, roomKind=boss_treasure`; its reward transaction belongs to the node coordinator. Preserve the approved map presentation and hide this separate treasure room from ordinary map rows.

**Tech stack:** JSON content, Lua rules, Node validation/build tools, Fengari regression tests.

1. Write `tests/lua/map_floor_boundaries.lua` for forced floors 1/9/15, early exclusions, Boss16, separate treasure17 and snapshot restoration; run it and confirm a missing-rule assertion fails.
2. Update map rules, source signature/version, generated graph and encounter bounds; run the boundary test until green. Reject old snapshots rather than silently reinterpret them.
3. Update map UI capacity and Boss viewport extent; hide the independent treasure room and its connecting line. Adjust existing floor assumptions in validation and UI tests.
4. Run `npm run check`, record exact evidence and leave full parity/platform acceptance open. The original PC RNG/path/node-weight/encounter algorithm and Boss treasure rewards require further work.

Regression follow-up: removing the old artificial forced rows exposed LCG low-bit correlation that made some ordinary encounters unreachable. Preserve the failing encounter-coverage assertion; separate room/topology and encounter state using the same initial seed, consistent with the independently seeded responsibility streams described by Forgotten Arbiter. Keep the existing LCG and uniform pool selection explicitly unverified against PC algorithms.

The user authorized independent Backlog implementation and delegated this slice. The source report remains `docs/reviews/TASK-12.4-map-floor-evidence.md`; its third-party reverse-engineering provenance is unchanged.
