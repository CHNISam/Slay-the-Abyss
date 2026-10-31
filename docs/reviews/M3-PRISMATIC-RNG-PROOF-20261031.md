# Prismatic reward identity and retry proof

Status: **TEST_ADDED**, production behavior unchanged. Base develop
`06366f7821dd91eb089ff8139056132981fa039c`. This slice adds the remaining
Prismatic-specific independent consumer vector; it does not rewrite the existing
93-call card-consumer vector or alter card pools, effects, balance, or budgets.

## Independent expectation

`tools/oracles/sts1_prismatic_rewards.py` imports only the existing independent
Python XS128 primitive. It derives all 320 reward source IDs directly from the
frozen 370-row original registration, then checks equality with the existing
full `allColorRewardByRarity` catalogue: 76 common, 160 uncommon, 84 rare.
No production Lua, generated runtime card definitions, sampled subset, or cloned
production sampler supplies the expected result. HEALING cards remain eligible,
including Feed, Reaper, and Bandage Up; the type-specific overload's HEALING
filter does not apply to `getAnyColorCard(rarity)`.

Original source: [aeubanks/sts, fixed 319009d5](https://github.com/aeubanks/sts/tree/319009d5df0a82d9fb0f23cc22322286c6a87ec0).
Exact SHA-256 values for every source below are recorded in the new fixture's
`sourceFilesSha256`; CardLibrary is
`ac123d5376862fb1d1d382284e14a9dc0e955395f415265ae29f9aa8a2b6237a`.
The complete source registration's archive and extractor hashes remain in
`data/reference/sts1-card-pools/registration.json`.

- `helpers/CardLibrary.java:1060`: each reward identity attempt builds the
  rarity pool and calls `shuffle(cardRng)` before the identity selection.
- `cards/CardGroup.java:492,548`: shuffle consumes one `randomLong` to seed
  Java's separate shuffle owner; identity selection then sorts by source cardID
  and consumes one bounded cardRng integer. The shuffled permutation is erased
  by the sort. Each duplicate retry repeats **both** calls.
- `dungeons/AbstractDungeon.java:1403`: rarity roll and offset mutation precede
  the attempt/retry loop. All identities precede non-rare upgrade floats;
  rare cards do not consume an upgrade float.
- `dungeons/AbstractDungeon.java:2542` and `random/Random.java:38`: public act
  transition pads a positive counter below 250 to 250, consuming Boolean calls.
- `dungeons/TheCity.java:80`: A0 Act2 upgrade chance is binary32 **0.25**;
  0.125 applies at A12 and is outside this fixture's A0 scope.
- `relics/PrismaticShard.java:26`: actual non-Defect acquisition grants one
  master orb slot when the previous count is zero.

## Actual public chain

Fixed independent seed **7** exercises Boss reward -> public Act1/Act2 transition
-> Act2 normal reward -> Act2 elite reward using one persistent cardRng owner.
The test calls real `Run.obtainRelic(PrismaticShard)` and Singing Bowl (only to
open the real reward owner/token modal; it adds no draw/count modifier).
It navigates a **path-only controlled prefix** to the real Boss, supplies terminal
enemy HP for each battle, and skips the real boss chest through Nodes before
public `Nodes.advanceAct`. The Act2 first normal node is real; the following
elite uses the public `Run.startRoomCombat('elite')` tier entry. This is a
controlled source proof, not a naturally played route or natural relic drop.
No RNG owner, pool, card result, reward, or transition state is substituted.
Read-only observers tag the actual transaction/clone lineage and record returns.

The full trace has **275 wrappers**: 9 Boss draws, 241 transition Booleans,
14 normal draws, and 11 elite draws. Every row pins method/bound or chance,
returned value (including long hex), both state words and counter before/after,
and phase. Normal slot 3 first picks Bane, duplicates slot 2, then spends a new
long and bounded identity call to return FlurryOfBlows. Normal Finesse and elite
Rage upgrade floats are true. Real reward claims commit Bludgeon, upgraded
Finesse, then All For One into permanent instances, checking UID advancement.
Later reward modals reject the previous owner's token with complete value and
reference rollback, no trace growth and no redraw. Gold/potion/leave operations
also preserve the card stream.

## Verification and boundaries

Three thin JS entries retain the original 10s whole-file budget and Lua 30s
budget. Fresh independent file process timings: source **4.869s**, two mutation
cases **3.751s**, CRLF **0.160s** (local Linux, not a Windows execution claim).

- `node --test tests/prismatic-rewards-source.test.mjs`: full positive trace.
- `node --test tests/prismatic-rewards-mutation.test.mjs`: exact temporary module
  mutants omit either all Prismatic longs or only the duplicate retry long;
  rejected at Boss and normal exact draw-count assertions respectively.
- `node --test tests/prismatic-rewards-checkout.test.mjs`: real Git
  `core.autocrlf=true/core.eol=crlf` checkout, converted control file, exact LF
  raw-hash inputs and fixture, POSIX keys, generator `--check` still succeeds.
- Both new generator `--check` and unchanged old 93-call generator `--check`
  succeed. No production source change was necessary.

This supplies a full Prismatic consumer chain, not all seeds, natural acquisition,
original PC binary authentication, current official candidate/device records,
or new evidence for TASK16.1#6's actual-game-record requirement. Independent
non-author review is required before the final TASK13.1#6 acceptance decision.
