# Player onAttacked / HP-loss TOP action order

Reviewed production base: `4c24aa0e526ab0f1997101c4bf49ba7aa1fdccc1`.
Source: read-only STS1 reference `319009d5df0a82d9fb0f23cc22322286c6a87ec0` (community decompiled reference; not authenticated executable).

`AbstractPlayer.damage` calls Power `onAttacked` before actual HP-loss callbacks and final revive handling. `StaticDischargePower.onAttacked` queues one TOP `ChannelAction` per stack. `ThornsPower`, `FlameBarrierPower`, and `watcher/BlockReturnPower` likewise queue TOP actions. Same-priority Powers retain application order. `CentennialPuzzle.wasHPLost` subsequently queues TOP draw-three, so its draw resolves before those earlier channels/retaliations.

Before this change Static channels and player retaliation ran synchronously after the HP callback had queued Puzzle. A full Lightning row could kill the last enemy before Puzzle drew; Puzzle was consumed but the draw disappeared. The no-Static Thorns variant had the same cause. Fatal damage without Fairy could also channel before defeat clearing.

The existing Actor boundary now constructs player NORMAL onAttacked reactions before HP-loss callbacks. It uses existing native/shared action owners, existing channel/block effects and captured retaliation target IDs. Enemy-target reaction batches remain in their existing order. No extra RNG calls, scheduler, or VFX timing was introduced. Tungsten's final HP reduction remains after Static qualification; Buffer remains before it.

Targeted evidence:

- `tests/lua/static_hp_top_order.lua`: 13 groups, 0 failed. The unchanged fixture against the four original production files at the reviewed base fails 9 groups; red log retained at `work/static-red/output.log` in the independent review tree.
- Covers standalone real damage, an existing shared owner, public `Run.endTurn` enemy action, no-Static lethal Thorns, exact two-channel card RNG, Buffer, Tungsten, Fairy, defeat clearing, both Power application orders, BlockReturn, and late-fault public-turn rollback preserving table/RNG identities.
- Existing Plated queue 49 and native Rupture queue 36 groups pass. Existing Defect defense and Act3 shapes/Defect integration fixtures pass.
- Modified production files have zero Luacheck diagnostics; diff whitespace check passes.

The two initial new-fixture no-trigger assertions expected `false`; inspection established `bindBattle` initializes only `attackPlayed=false` and existing `native_rupture_queue.lua` requires `centennialUsed=nil` without HP loss. Both exact assertions were corrected to this pre-existing contract; production initialization and existing assertions were unchanged.

Source SHA-256: StaticDischargePower `93b86d1b514f5da259978d98e45061dc0483ba48fbfd9e09882df6faa15d94ef`; CentennialPuzzle `b1069310819ff2fdd812467a1d0f461d9d40cea376e244268dfdc270217dd56e`; AbstractPlayer `2720ba8dd7a216781a3b2fcb709f5ec67dc9b2559af25f7f6b89df1ef0947d95`.

This is a targeted offline behavior review and implementation, not final-SHA independent approval or live play verification. Shared-owner injection isolates its action-owner boundary; normal entry is separately exercised through `Run.endTurn`.
