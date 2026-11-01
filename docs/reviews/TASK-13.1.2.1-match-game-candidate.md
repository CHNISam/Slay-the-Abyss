# Pairing-event reducer candidate

TASK-13.1.2.1, under TASK-13.1.2. Base: `2e2098c2c478a021d52cafe5d6e45148aaa886dd`.

## Boundary

This is an independently implemented, candidate-only board reducer, **not a playable event**. Nothing imports it from production. It does not enable another event or change the six-event pool, Run, Nodes, combat, card data, random streams, or UI.

`tools/candidates/match_game.lua` accepts an already sampled and shuffled board. Twelve dense nonempty string card IDs must have even multiplicities; duplicate IDs across original pairs are valid. Inputs are copied into private closure state. Card IDs are not permanent deck UIDs. Invalid boards return `nil, 'invalid_board'` without mutation or executing input metamethods.

The returned object supports colon calls:

- `select(slot)`: reveal a legal integer slot 1–12; return true, or false plus a reason. A first selection consumes no attempt. Selecting it again, a removed slot, or another slot while a pair awaits resolution is rejected without changing state.
- `resolve()`: the adapter calls this after presenting both revealed cards. Consume one attempt whether matched or mismatched. Matching compares card IDs and removes both slots; return true and a fresh result containing `matched`, optional `awardCardId`, `attemptsLeft`, and `complete`. The fifth resolution emits any final award before entering the terminal state. Repeated resolution cannot emit the award again.
- `view()`: fresh detached slots, visibility flags, phase and remaining attempts. Concealed and removed slots do not expose their card IDs. Phase is `selecting`, `resolving`, or `complete`.

The one-shot result is **not** an exactly-once permanent inventory transaction. A future adapter must atomically commit the card acquisition and event state, and define recovery before enabling production. The caller may retain/replay a returned string externally; this module cannot prevent an unrelated grant API from accepting it. There is deliberately no callback or persistent UID allocation in the reducer.

## Fixed source and interpretation

Existing ledger: `docs/evidence/unknown-events-p0/source-ledger.json`, entry `events/shrines/GremlinMatchGame.java`.

- Mirror commit: `purewhitelove/ButterflyGame@fc379c875c11e008e9c10548ac8e394c301c532f`.
- Git blob: `f86144bdf0e00acad096e8668f17fa96d6aabac1`.
- [Fixed source](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/events/shrines/GremlinMatchGame.java).

The constructor establishes five attempts. `initializeCards` creates six source cards plus six duplicates. `updateMatchGameLogic` compares IDs, removes a successful pair, schedules one acquired card, and decrements attempts after either result. The implementation here is a fresh state model, not copied source, text, graphics or UI.

The supplied-board validation and private-state API are defensive integration contracts, not original-game eligibility claims. Source timing uses reveal waits; this reducer instead exposes an explicit resolution barrier. It does not claim timing parity. Sampling by rarity, colorless/curse availability, preview relic hooks, shuffle consumption, acquisition modifiers, and complete event presentation remain out of scope. The mirror is not an authenticated official PC binary; strict PC version parity remains unverified.

## Verification

`tests/lua/match_game_candidate.lua` contains 17 assertion groups: hidden/revealed views, pending locks, matches/mismatches, five-attempt terminal behavior, final award, cross-pair equal IDs, input/result/view detachment, independent instances, invalid indices, malformed boards, cycles and metatables.

Tests first: the absent module produced the explicit `pairing reducer candidate must exist` failure. After implementation, all 17 groups pass through the existing native Lua 5.4 helper. Ten independent temporary mutations are rejected: missing decrement, match-only decrement, missing selection reset, missing removal, same-slot acceptance, concealed-ID leak, retained input alias, mismatch award, six attempts, and absent pending lock. Temporary mutation files/logs are local evidence, not delivered modules.

No local npm/full check, installation, Fengari run, platform build/import, or device testing was performed for this candidate. The root publisher must run the exact published head's Quality checks. Parent TASK-13.1.2 and all production/platform acceptance remain open.
