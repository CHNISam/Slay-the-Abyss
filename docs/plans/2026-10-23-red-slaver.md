# Red Slaver A0 and Entangle

Goal: replace the current fixed Red Slaver cycle with the fixed-source A0 policy,
including its actual once-only Entangle. No Weak substitution or game acceptance.

Architecture: independent `abyss_red_slaver_ai` policy, enemy-owned flat history
and used-net flag, existing AI dispatch and queued-roll boundary. Entangle is a
real DEBUFF Power, checked by Combat.canPlay for attack cards, intercepted by
Actor.applyPower/Artifact, and removed directly at the player's first owner end.
Raw status mutation remains separate; removal is not another ApplyPower.

Tech stack: Lua/JSON/schema, independent Fengari real-entry tests, checked PR19
status art. Start at e9721b8 with applyPower; do not change Effects/Inventory's
concurrent bridge. Root explicitly authorized isolated Actor/Combat changes.

Fixed community source (not authenticated original-PC source): aeubanks/sts
319009d5df0a82d9fb0f23cc22322286c6a87ec0, read 2026-10-23:

- `monsters/exordium/SlaverRed.java`, SHA256
  `2e92dfad2ddee766d9f95b45c028b80b5abae3e966eb3dff1656d60c253da7c4`:
  A0 HP46..50; Stab13; Scrape8 then Vulnerable1. Initial getMove ignores the
  already-consumed main roll and always Stabs. Before net use, roll>=75 selects
  Entangle; otherwise Scrape unless the last two were Scrape, then Stab. After
  net use, roll>=55 selects Stab unless last two were Stab; fallback Scrape
  unless last two Scrape, then Stab. takeTurn queues RollMove after every move.
  usedEntangle becomes true when net action is queued, even if Artifact blocks it.
- `powers/EntanglePower.java`, SHA256
  `7e56f0cfe75f79bd1013402b21f9d6c2a50853588c82adff3b39d9e1058c34e2`:
  constructor amount1, DEBUFF; atEndOfTurn(isPlayer) queues removal only for true.
- `cards/AbstractCard.java`, SHA256
  `bcd472ececfd8ce4150ccd4eb6dd07a2e2dc43e139196fe00de34705cf1a2a61`:
  hasEnoughEnergy L857 rejects ATTACK when the player has Entangled. Skills, powers
  and potions are not blocked by this card-type check.

1. Write real Combat/Run tests, first observe red: HP endpoints/main roll,
   74/75 and54/55 branches, both no-three histories, one net even after blocked
   application, two independent actors, death/poison/queued roll and rollback.
2. Add minimum Entangle state and Artifact classification; reject attacks before
   payment/mutation and clear at player end, never at monster round-end or player
   start. Test no repeated/later-turn lock, skill/potion allowed, dead target and
   Artifact interactions. Reuse an approved existing status icon.
3. Add policy/data/schema and real isolated regression checks. Existing bridge
   may be composed later by root; do not broaden unsupported Power hooks.
4. Record fixed sources, targeted results and remaining original RNG/platform
   limits, update Backlog CLI, independent Conventional Commit; no push/full check.

Louse was assessed as a fallback, but CurlUp also needs missing infrastructure:
its source triggers once only on positive nonlethal NORMAL attack damage, queues
block/removal, and differs from poison/Thorns. It is not an honest zero-dependency
alternative; Red's explicitly authorized minimal Entangle foundation is chosen.
