package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,P,D,A=require('abyss_combat'),require('abyss_character_profiles'),require('abyss_data'),require('abyss_card_actions')
local function battle()
 local s=C.new(P.prepare(D,'watcher'),{seed=1,cardRandomSeed='1',enableStances=true,deck={'empty_body'},enemies={'cultist'}})
 s.enemies[1].hp=1000;s.enemies[1].maxHp=1000;return s
end
local function add(s,id)local c=A.fresh(C,s,id);C.queueCard(s,c,{append=true,randomTarget=true});return c end
for _,early in ipairs({'conclude','vault'})do for _,after in ipairs({'empty_fist','wheel_kick','wish'})do
 local s=battle();add(s,early);local canceled=add(s,after);canceled.freeToPlayOnce=true
 A.enqueue(s,{op='draw',value=0});A.drain(C,s)
 assert(s.turn==2 and #s.cardsPlayedThisCombat==1,'PressEndTurn must clear waiting autoplay before another use')
 assert(not s.pendingChoice and not s.pendingPlay and not s.actionQueue)
 assert(s.enemies[1].hp==(early=='conclude' and 988 or 1000),'canceled attack must not deal damage')
 assert(not canceled.freeToPlayOnce and not canceled.dontTriggerOnUseCard,'canceled UseCard clears once-only fields')
end end
local lethal=battle();lethal.enemies[1].hp=10;add(lethal,'conclude');add(lethal,'empty_fist');A.drain(C,lethal)
assert(lethal.phase=='victory' and lethal.turn==1 and #lethal.cardsPlayedThisCombat==1)
local dead=battle();dead.player.hp=1;dead.enemies[1].statuses.thorns=1;add(dead,'conclude');add(dead,'empty_fist');A.drain(C,dead)
assert(dead.phase=='defeat' and dead.turn==1 and #dead.cardsPlayedThisCombat==1)
local paused=battle();local chosen=A.fresh(C,paused,'conclude');paused.draw={chosen}
add(paused,'omniscience');add(paused,'wish');A.drain(C,paused);local p=assert(paused.pendingPileChoice)
assert(C.choosePile(paused,{chosen.uid},p.token,p.generation));local w=assert(paused.pendingChoice)
assert(w.kind=='wish' and paused.turn==1,'pre-existing queued Wish precedes newly appended Omni target')
assert(C.chooseCard(paused,w.token,1));assert(paused.turn==2 and #paused.cardsPlayedThisCombat==3)
assert(paused.enemies[1].hp==985,'Wish strength applies to exactly one Conclude; Omni purge copy is canceled')
assert(not paused.pendingChoice and not paused.pendingPlay and not paused.queuedCards)
print('WATCHER_EARLY_TURN_QUEUE_ORDER source action/card priority, three canceled successors, death/victory and two resumed choices passed')
