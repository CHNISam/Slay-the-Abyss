# Discovery keeps its current action owner

Base `922601218cba78e850eabb771a20e91220b3949f`; source reference `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0` (read-only community decompile, not authenticated executable).

`Discovery.use` appends `DiscoveryAction`, then `AbstractPlayer.useCard` appends `UseCardAction`. `DiscoveryAction.update` opens the selection before its retrieval update generates the second unused group, creates the selected zero-cost temporary card, and lets the later UseCard exhaust and its hooks proceed.

The existing shared Watcher route executed Colorless Discovery by appending to the native card queue while a shared action queue owned the play. The shared queue continued disposal and Feel No Pain/Juggernaut before Discovery could pause. At the existing seed42 Cultist5-HP rollback fixture this killed the last enemy and prepared rewards during play, instead of during selection.

The correction uses the existing owner-aware `enqueueReaction` adapter for Discovery, pauses the shared `discover` handler, then resumes that same shared queue through the public `chooseCard` transaction. Native behavior, pool selection, RNG generation/retrieval implementation, disposal hooks and outer Run rollback remain unchanged. No new manager is introduced.

Verification:

- The original `run_turn_reward_rollback.lua` is byte unchanged: all six original turn/choice/retain × throw/reject cases, seed42, complete graph/reference/RNG rollback and retry/control comparisons pass within the original30s limit (26.569s locally).
- New `discovery_action_owner.lua`: native/shared public Run play and choice pause before exhaust, preserve owner/hand/RNG references on stale input, retain Watcher's source PureWater Miracle, generate one zero-cost temporary card and resume exactly once. Two groups pass; the unchanged fixture fails against the two original production modules (red retained in independent tree `work/discovery-red/output.log`).
- Existing Potion Discovery5 and Colorless actions pass. Both changed production modules have zero static diagnostics; diff whitespace check passes.
- `statuses.lua` preserves all35 original groups and setup. The lethal-player case now expects the still-alive1-HP enemy: `ThornsPower.onAttacked` queues a TOP DamageAction, `AbstractPlayer.damage` opens DeathScreen first, and `AbstractRoom.update` stops action-manager advancement with a screen open. Regeneration, original intent and later-enemy assertions stay intact. This matches the separately reviewed existing `queued_player_defeat.lua` source behavior.

No frozen budget contract, existing fixture timeout, source pool, original rollback test, or production numeric/RNG rule was modified. Final combined CI and live-client acceptance remain separate.
