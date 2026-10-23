# Red Slaver A0 and Entangle — TASK-15

2026-10-23, isolated `feat/continue-red-slaver`. Started at root-authorized
`e9721b8` (Artifact Actor foundation); the genuine Effects/Inventory bridge
`80684bd` is a dependency, locally cherry-picked as `203fb84`. Root already owns
that dependency and should cherry-pick only this slice's final Red increment.
No game/MCP/live writes, original-PC execution or platform acceptance.

## Fixed source and trust boundary

These are community decompiled method observations from
[aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0](https://github.com/aeubanks/sts/tree/319009d5df0a82d9fb0f23cc22322286c6a87ec0),
read in full or the explicitly named complete methods. They are not official
open source, authenticated against a target PC binary, or an original runtime
oracle. SHA-256 hashes cover the fetched UTF-8 bytes.

| Source | SHA-256 | Relevant contract |
| --- | --- | --- |
| [SlaverRed.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/exordium/SlaverRed.java) | `2e92dfad2ddee766d9f95b45c028b80b5abae3e966eb3dff1656d60c253da7c4` | A0 HP46..50, Stab13, Scrape8 then Vulnerable1, firstTurn, usedEntangle, takeTurn and getMove. |
| [EntanglePower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/EntanglePower.java) | `7e56f0cfe75f79bd1013402b21f9d6c2a50853588c82adff3b39d9e1058c34e2` | Constructor amount1, DEBUFF; player end queues RemoveSpecificPowerAction, not a decrement or a new ApplyPower. |
| [AbstractCard.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/AbstractCard.java#L857) | `bcd472ececfd8ce4150ccd4eb6dd07a2e2dc43e139196fe00de34705cf1a2a61` | cardPlayable refuses ATTACK while player has Entangled; no corresponding restriction on skills/powers/potions. |
| [FirePotion.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/potions/FirePotion.java) | `61f3c422e9112c3f8cbd158c681df4724097e58cbe495d42e7431870dbfccc04` | Targeted 20 THORNS damage, a potion action rather than an attack card. |
| [AbstractPotion.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/potions/AbstractPotion.java#L396) | `10b76a57d36ae4714928fe4c21ce8f352e8c0739eaa675bed5f199480886d888` | canUse checks event exception, live monsters, unended turn and COMBAT room phase; it has no Entangled gate. |

Also independently read the same fixed
[AbstractMonster.setMove/rollMove/lastTwoMoves](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/AbstractMonster.java#L419):
setMove records selected moves, rollMove consumes aiRng.random(99), and
lastTwoMoves compares the last two entries. The candidate stores equivalent
last/current executed move history before selecting the next action. The fixed
queued RollMove/death chain is documented separately in
[QUEUED_ENEMY_ROLL_AFTER_DEATH](../rules/QUEUED_ENEMY_ROLL_AFTER_DEATH.md) and the
Artifact application chain in [TASK-15-sentries-ai](TASK-15-sentries-ai.md).

## A0 policy

The opening consumes one main integer roll but always selects Stab13. Later:

| State | Ordered decision |
| --- | --- |
| Net not yet used | roll >=75: Entangle. Otherwise Scrape8+Vulnerable1 unless last two are Scrape, in which case Stab13. |
| Net already used | roll >=55 and last two are not Stab: Stab13. Otherwise Scrape unless last two are Scrape, in which case Stab13. |

Thus 75 and 55 are conditional branch boundaries, not unconditional move weights
for every history. Net selection does not spend the flag: takeTurn does so when
the ApplyPower is queued, even if Artifact subsequently blocks it. Every action
queues RollMove. A Thorns-killed Red still consumes that roll if a teammate
survives; last-enemy death clears it, and poison death before action queues none.
The dead actor's chosen intent/history records queue consumption and never
revives it or permits another action. Scrape's already queued Vulnerable retains
the shared verified dead-source exception.

Implementation: `abyss_red_slaver_ai`, flat per-actor history/flag, bounded schema
references and source-derived data values. No source SFX/cosmetic MathUtils RNG
is routed into the gameplay stream. Actual runtime still uses the project's
shared 16-bit LCG for HP/AI/shuffle: repeatability is not original RNG parity.

## Entangle foundation and scope

- New `entangled` intensity state retains application count; `decay=none`
  avoids falsely clearing at monster round end or player start. Actor player
  owner end directly removes the whole state, including multiple applications.
  This is a removal event and never spends Artifact. An enemy carrying this raw
  setup state does not get the player-only removal hook.
- `Combat.canPlay` rejects attack cards with `entangled` before supported-effect,
  target or energy checks and before any payment, hand, event or RNG mutation.
  Skills and powers use their normal rules; potions keep their separate command
  path. Read-only callers see the same core preflight result.
- Entangle is a source-verified DEBUFF classification in Actor.applyPower.
  Artifact blocks the entire incoming application; the AI's used-net flag stays
  spent. Invalid/negative amounts and dead targets do not spend Artifact; zero
  incoming DEBUFF consumes Artifact under the existing finite application model.
  Raw addStatus/status APIs stay raw. Zero-valued Power-object existence is not
  modeled, matching the explicitly retained Artifact foundation boundary; the
  actual Red constructor supplies one. The zero-input case verifies only the
  incoming Artifact gate, not full zero-Entangle gameplay. In particular a raw
  zero count without Artifact does not block attacks in this candidate and must
  not be claimed equivalent to a present original zero-valued Power object.
- Removal composes with Flex's separate owner-end negative Strength application:
  Entangle removal itself consumes no Artifact, whereas a queued negative
  Strength can. The candidate does not certify all original Power priority,
  source hooks, immunity, animation, or nontransactional endTurn ordering.
- PR19 colors/layout/type are unchanged. Entangle uses the existing approved
  `103053` debuff icon through the shared theme and standard status text. This
  is deliberate icon reuse, not a claim of new custom art or platform display
  acceptance. No battle UI/controller files are changed by this increment.
- Effects/Inventory bridging belongs to the dependency. Its separate pending
  prospective-overflow review items are not fixed or certified by this Red slice.

## Red/green evidence

The first 26-group real-entry run on unchanged e9721b8 reported 25 failures:
missing HP sampling/rolls/third move/Entangle; one failure was a fixture's illegal
floor and was corrected to the existing encounter's actual legal floor four.
After the minimal rule change, the remaining genuine failure was the planned
real Artifact bridge dependency. Applying that bridge made the previously raw
application participate in Artifact correctly. A removal-only fixture was then
corrected to choose the next Stab, so an unrelated valid Scrape debuff would not
consume its retained Artifact and obscure what was being measured.

The final dedicated suite has 29 groups with source-literal expectations:
inclusive HP endpoints and exact requests, first Stab, 54/55/74/75/99, net
priority over two-Scrape fallback, both no-three histories, damage-before-power,
a natural Stab→net path, rejected attack full-state atomicity, allowed real
skills/power/fire potion, first player-end removal and multiple counts, Flex
composition, Artifact-blocked used net, zero/invalid/dead target, two independent
Red actors, single Artifact versus two nets, death/poison rolls, queued
Vulnerable and late permitted-skill failure preserving live references.

Schema adds 12 independent contract/negative cases, and packaging checks include
the new policy module. Focused command results are recorded in Backlog. Root
owns full composed check, separate bridge completion and platform acceptance;
TASK-15 strict/global/platform AC remain open.
