# Unknown events P0 implementation plan

**Goal:** Resolve real unknown rooms and deliver six complete events in an explicitly restricted launch pool (user approved 2026-10-23).

**Architecture:** Nodes owns atomic entry and event commands. Reuse the existing probability reducer and independently tested RandomXS128 candidates, with persistent room/misc streams and a reconstructed event-selection stream. Preserve the full source catalog separately from the approved six-event production subset; no rerolling unsupported outcomes.

**Tech stack:** Lua/Fengari, Node test runner, Backlog CLI, existing native UI and GIL build/audit scripts.

1. Add failing tests in `tests/lua/unknown_events.lua` for bucket boundaries, previous shops, relic adapters, catalog eligibility, pool exhaustion, routing and transaction isolation. Run `node scripts/test-lua.mjs tests/lua/unknown_events.lua` and retain the red result.
2. Promote the two RNG candidates to `src/lua/abyss_sts_random.lua` and `abyss_randomxs128.lua` without changing candidate fixtures. Add a tested Java48 shuffle adapter for Shining Light. Preserve seed/counter snapshots and independently validate primitives against existing vectors.
3. Extend `abyss_unknown.lua` with source float/bucket behavior; implement catalog eligibility and three-pool lifecycle in `abyss_event_pool.lua`. Wire staged state into `abyss_nodes.lua` and initialize streams in `abyss_run.lua`. Test failed entry, repeated entry/view, restored state, four room handlers and map symbol preservation.
4. Implement Cleric, Purifier, World of Goop, Upgrade Shrine, Golden Wing and Shining Light with all their choices. Extend the existing event/picker UI using core-provided option models, keeping the PR19 layout/theme and existing stale touch guards. Test costs, UID choices, empty upgrade sets, entry-time randomness, death and repeated actions.
5. Run full `npm run check`, document catalog gaps and source disputes, build/audit a frozen native candidate, review the complete diff, push a PR, verify current-head Quality jobs and squash merge into develop. Keep official import, platform play and strict PC parity explicitly unverified.

The original full catalog remains P0 follow-up work; TASK-12.3 owns platform acceptance. M1 remains the earliest unfinished milestone.
