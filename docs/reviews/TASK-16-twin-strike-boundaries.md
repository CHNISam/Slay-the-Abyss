# TASK-16: Twin Strike per-hit boundary regressions

Reviewed 2026-10-23 against develop `1060b5798df5c6b8ec1c42dac904242eb7027345`.

This is a test-only coverage improvement. Current production behavior passes;
no balance, card data, runtime, platform artifacts, or Backlog state is changed.
The existing 30-card pool tests assert unmodified Twin Strike totals, while the
Guardian and feedback suites cover queued mode shift and two distinct hits.
They did not detect either controlled multi-hit modifier regression below.

## Independent source and limits

The reference is the same fixed third-party decompiled mirror used in prior
card audits, commit `fc379c875c11e008e9c10548ac8e394c301c532f`:

- [TwinStrike.java](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/cards/red/TwinStrike.java): constructor damage 5, cost 1; two separate normal damage actions; upgrade increases each attack by 2.
- [StrengthPower.java](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/powers/StrengthPower.java): normal attack damage receives the full Strength amount.
- [WeakPower.java](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/powers/WeakPower.java): player normal damage uses factor 0.75.
- [VulnerablePower.java](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/powers/VulnerablePower.java): normal received damage uses factor 1.5 without the modifying relic.
- [AbstractCard.java](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/cards/AbstractCard.java): calculateCardDamage applies outgoing/incoming modifiers before flooring the attack amount.

Thorns/block behavior and source-liveness restrictions retain the already
implemented contract, not a claim of complete action-queue parity. The mirror
is not independently authenticated against a licensed PC binary. No source
implementation is copied into this repository. No new original-game runtime
observations, platform compilation, import, or live play are claimed.

## Added cases

`tests/lua/twin_strike_boundaries.lua` exercises the actual supported card through
`Combat.play` in 16 cases, eight each for base and upgraded instances:

- Strength +3 yields 8+8 / 10+10; Strength -3 yields 2+2 / 4+4.
- Weak yields 3+3 / 5+5, not flooring a combined attack total.
- Strength +2, Weak and Vulnerable yield 7+7 / 10+10.
- Enemy Block 6 is consumed separately: base absorbs 5 then 1, upgrade 6 then 0.
- Two Thorns 3 reactions consume player Block 4 then reduce HP by 2.
- A lethal first Thorns reaction stops the second hit.
- Killing the selected enemy on the first hit does not redirect the second hit.

Assertions also cover individual damage events, intervening retaliation, cost,
phase and exactly one original instance discarded. Fixed fixture HP/statuses
isolate these boundaries; they are not natural acquisition evidence. Existing
card_pool acquisition/upgrade coverage remains unchanged.

## Verification and negative controls

All 79 pre-existing native Lua suites pass on the unchanged baseline. All 80
pass with this additional suite. The new suite passes 16/16. Native runner is
liblua5.4; this is not a Fengari or platform Lua verification claim.

Two isolated modifications to the multi-hit damage path were tested, restoring
the production file afterward:

1. Share Strength across hits instead of applying its full amount to each hit.
   All 79 pre-existing suites still pass; the new suite rejects six cases.
2. Add 0.99 to the attack base only for weakened player multi-hit attacks,
   perturbing pre-floor per-hit damage upward. All 79 pre-existing suites still
   pass; the new suite rejects three cases. This is a rounding-sensitivity
   negative control, not a proposed implementation or an exact ceil algorithm.

These red results demonstrate a coverage gap, not a production bug fix.
The first raw baseline run omitted the generated layout required by battle_ui
and failed that suite; supplying the same generated layout as scripts/test-lua
corrected the harness and its 43 cases pass. No production change was needed.

No npm install or full npm check was run. A publisher must still run the usual
current-head CI gates; these local checks do not close strict or platform ACs.

Reproduction: build data with `node scripts/build-lua-data.mjs`, then use the
project's normal Lua runner for `tests/lua/twin_strike_boundaries.lua` or the
all-suite discovery entrypoint. No runner registration changes are necessary.
