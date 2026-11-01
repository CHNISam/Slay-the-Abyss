# Dazed temporary status-card slice — TASK-16 / TASK-16.1

This slice adds Dazed, not a substitute Sentry AI. The latter and Artifact belong
to enemy_parity's independent commits. No original-PC execution, original RNG
equivalence, platform import, Genshin or mobile acceptance is claimed.

## Fixed evidence and confidence

All Java paths below are relative to the community decompiled mirror
[`aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`](https://github.com/aeubanks/sts/tree/319009d5df0a82d9fb0f23cc22322286c6a87ec0).
They are inspectable method evidence, not authenticated official source or a
runtime oracle. Hashes are SHA-256 over the fetched raw UTF-8 bytes.

| Fixed file | Observed contract | SHA-256 |
| --- | --- | --- |
| [cards/status/Dazed.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/status/Dazed.java#L17) | Constructor: cost -2, STATUS, COLORLESS, COMMON, target NONE, ethereal. Empty use and upgrade. makeCopy makes a new Dazed. | `bd07efcea70830fab6d8604cbd2952147cbaa51b88647447aaf888c8875b4e36` |
| [actions/common/MakeTempCardInDiscardAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/MakeTempCardInDiscardAction.java#L20) | Normal constructor defaults sameUUID=false. First update constructs one visual/discard effect per card for numCards<6. makeNewCard uses makeStatEquivalentCopy unless sameUUID is explicitly enabled. | `78eeca2eeeaf22de9146148cdcb015b7bdd335f0529a6f62fdadba3dd4d28efd` |
| [vfx/cardManip/ShowCardAndAddToDiscardEffect.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/vfx/cardManip/ShowCardAndAddToDiscardEffect.java#L37) | Constructor adds the card to discard immediately; its later animation completion is not the first logical insertion. MasterReality excludes status/curse. | `9386ebe73aabf208e05f23068e168921f8db069151947d7ed4582308e2198d80` |
| [cards/CardGroup.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/CardGroup.java#L438) | addToTop appends to the list; getTopCard selects its last element. moveToExhaustPile moves to exhaust separately from discard. | `03de4e22ab22bedf1d90df72bdc83f033ff6aa776ad9d8f7259e1ee9293f7fa8` |
| [cards/AbstractCard.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/AbstractCard.java#L804) | makeSameInstanceOf explicitly restores UUID; makeStatEquivalentCopy does not. canUse rejects STATUS costForTurn<-1 without MedicalKit. triggerOnEndOfPlayerTurn queues ExhaustSpecificCardAction for ethereal cards. | `bcd472ececfd8ce4150ccd4eb6dd07a2e2dc43e139196fe00de34705cf1a2a61` |
| [actions/common/ExhaustSpecificCardAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/ExhaustSpecificCardAction.java#L32) | Only a card still present in the specified group is moved to exhaust. | `86224fd382a494afef43efac62f33f92a08e5a4562be1a03409cb071eb1080b3` |

The entire fixed MakeTempCardInDiscardAction contains only the `<6` branch. Two
other pinned community mirrors were also read: [purewhitelove/ButterflyGame
fc379c8](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/actions/common/MakeTempCardInDiscardAction.java)
(blob `594d2d683fdbf16bc10274ccf12dfd5ddd502ae9`) and
[fadedwind/refgameSource 462da73](https://github.com/fadedwind/refgameSource/blob/462da73b934eaf8a833791f3cab74dc792fdeeb6/Slaythespire.src/com/megacrit/cardcrawl/actions/common/MakeTempCardInDiscardAction.java)
(blob `135797861ea9e29984f2f389a8bc0f71756dbe8f`). They likewise lack a larger
count branch, but may share decompilation ancestry. This does **not** establish
that the authentic game creates no cards at count >=6. The implemented 0..5
range is an explicit candidate ABI limit; larger values reject atomically.
The A0 Sentry amount two lies inside the verified path.

## Representation and boundaries

- Dazed retains `type=status`, `rarity=common`, `cost=-2`, `ethereal=true`, empty
  `effects`, and no upgrade. This is an unplayable status, not a zero-cost card.
  `canPlay` rejects before checking effects or paying energy. Empty effects stay
  invalid for other cards. MedicalKit is outside supported content.
- `makeTempCardInDiscard(card,value)` takes a known catalog ID and integer count
  0..5. It creates fresh unupgraded instances at discard top, with monotonic
  combat UIDs. It never copies a played card or alters a permanent Run instance.
  Anger's `addCardToDiscard` retains its separate upgraded-copy contract.
- All card/count/UID increments are prevalidated before pile mutation. UID math
  crosses signed-int32 safely and rejects loss of binary64 advancement. Count
  zero changes no pile, UID, events or RNG. Successful nonzero batches emit
  `cards_created` with a detached frame after immediate insertion.
- The existing hand ethereal disposal exhausts held Dazed on player turn end;
  discard/draw Dazed are not exhausted merely for existing. Full original
  exhaust/relic-trigger action ordering is not claimed.
- Reward and shop candidates explicitly reject status/curse by type. Dazed's
  COMMON rarity is preserved. Permanent decks, reward ownership, upgrades and
  next combat initialization are unchanged. Generation is not ApplyPower and
  does not reference Artifact's upcoming API. Dead-source queued generation is
  deliberately not enabled by the separate ApplyPower-after-death exception.
- Read-only battle UI shows the checked text, blank cost, existing status art
  `100122`, existing disabled tint, and no actionable card selection. PR19 theme
  values/layout are reused. The offline prototype's embedded catalog stays in
  sync and uses its existing generic deck SVG as a schematic status-card icon;
  platform UI uses the approved theme's actual `100122`. No new visual direction
  or animation fidelity is claimed. The prototype's sample pool excludes status.

## Verification

On unchanged 0936c6e, the new real-entry Lua suite ran and reported **11 failures
of 20**: missing Dazed definition, unsupported generation and unplayable-state
handling. The initial Node attempt hit sandbox spawn EPERM; that attempt is not
counted as a schema red result. Fengari is a local runtime, not original Java.

After implementation, the extended Lua suite checks 21 groups: source fields,
energy/state-preserving rejected play, immediate discard timing before the next
enemy damage, two distinct instances, repeat batches, zero/five endpoints,
invalid request atomicity, int32/binary64 boundaries, played-card rollback,
ethereal hand-only disposal, real Run next-combat isolation, and actual reward /
shop entry filters (a supported-payload fixture makes the type guard necessary).
The generic enemy generation fixture proves the effect entry and ordering, not
the as-yet separate Sentry policy.

Schema adds 11 cases and keeps ordinary empty/negative cards rejected. The real
generated native-tree UI regression checks Dazed display/disabled input, and
Python checks source/overlay/prototype parity and blank sentinel cost. Final
targeted command results are recorded in Backlog. Full combination check is
owned by root; platform acceptance and TASK-16/16.1 strict AC stay open.
