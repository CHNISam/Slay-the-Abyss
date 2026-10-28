-- Real card/queue paths; HP, physical hands and modifier identities are controlled.
-- Magic Flower/Sacred Bark here are existing health-contract fixtures, not natural obtains.
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,D,A,Cards,Hooks=require('abyss_run'),require('abyss_combat'),require('abyss_data'),require('abyss_actor'),require('abyss_card_actions'),require('abyss_relic_hooks')
local count=0
local function eq(a,b,label)assert(a==b,(label or '')..': '..tostring(a)..' ~= '..tostring(b))end
local function test(name,fn)fn();count=count+1;print('PASS independent Tail action '..count..' '..name)end
local function setup(id,advanced,maxHp,hp,fairy)
 local run=Run.new(D,42)
 assert(Run.obtainRelic(run,'Lizard Tail'));assert(Run.obtainRelic(run,'Red Skull'))
 if fairy then assert(Run.obtainPotion(run,'fairy_in_a_bottle'))end
 run.maxHp,run.hp=maxHp,hp -- controlled health, actual legal obtains above.
 assert(Run.startCombat(run,'cultist_solo'))
 local s=run.combat;s.experimentalMechanics=advanced
 if advanced then s.player.stance='Neutral'end
 assert(not s.catalog.cards[id].runNativeABI and not s.catalog.cards[id].silentFinalCard)
 local card=Cards.fresh(C,s,id);s.hand={card};s.draw={};s.discard={};s.energy=20
 s.enemies[1].hp,s.enemies[1].maxHp=1000,1000
 assert(not Hooks.owns(s,'centennial_puzzle')and not s.player.statuses.rupture)
 return run,s,card
end
local function order(s,start,artifact)
 local minus,plus,heal
 for i=start+1,#s.events do
  local e=s.events[i]
  if e.kind=='heal'or e.kind=='potion_revive'then heal=heal or i end
  if e.kind=='status'and e.detail.target==s.player.id then
   if artifact and e.detail.status=='artifact'and e.detail.blockedStatus=='strength'then minus=i end
   if not artifact and e.detail.status=='strength'and e.detail.amount==-3 then minus=i end
   if e.detail.status=='strength'and e.detail.amount==3 then plus=i end
  end
 end
 assert(heal and minus and plus and heal<minus and minus<plus,'heal then source TOP -3 then +3 required')
 return plus
end

test('Hemokinesis Tail/Flower TOP changes precede captured damage in native and forced paths',function()
 for _,advanced in ipairs({false,true})do for _,artifact in ipairs({false,true})do
  local _,s,card=setup('hemokinesis',advanced,3,2)
  s.relics[#s.relics+1]='magic_flower';if artifact then A.applyPower(s,s.player,'artifact',1,s.player)end
  local start=#s.events
  assert(C.play(s,card.uid,1));eq(s.player.hp,2);eq(s.relicCounters.lizard_tail,-2)
  eq(s.relicCombat.redSkullActive,false);eq(s.player.statuses.strength or 0,artifact and 3 or 0)
  local plus=order(s,start,artifact);local damage
  for i=start+1,#s.events do local e=s.events[i]
   if e.kind=='damage'and e.detail.target==s.enemies[1].id then damage=i;eq(e.detail.amount,15,'source use-time attack snapshot')end
  end
  assert(damage and plus<damage,'bloodied TOP actions must drain before subsequent Hemokinesis damage')
  eq(s.enemies[1].hp,985);assert(not s.actionQueue and not s.cardActions)
 end end
end)

test('Offering Bark Fairy precedes Tail and both TOP changes precede real draw',function()
 for _,advanced in ipairs({false,true})do for _,artifact in ipairs({false,true})do
  local _,s,card=setup('offering',advanced,10,6,true)
  s.relics[#s.relics+1]='sacred_bark';if artifact then A.applyPower(s,s.player,'artifact',1,s.player)end
  for _=1,3 do s.draw[#s.draw+1]=Cards.fresh(C,s,'defend')end
  local start=#s.events
  -- Draw has no standalone event; observe the actual call and delegate unchanged.
  local draw,calls=C.draw,0
  C.draw=function(state,n,...)
   if state==s then calls=calls+1;eq(n,3);order(s,start,artifact)end
   return draw(state,n,...)
  end
  local called,result=pcall(C.play,s,card.uid);C.draw=draw;assert(called,result);assert(result)
  eq(s.player.hp,6);eq(s.potionInventory[1],nil);eq(s.relicCounters.lizard_tail,-1)
  eq(s.relicCombat.redSkullActive,false);eq(s.player.statuses.strength or 0,artifact and 3 or 0)
  order(s,start,artifact);eq(calls,1);eq(#s.hand,3);eq(#s.exhaust,1);eq(s.exhaust[1],card)
 end end
end)

test('dead final Heart retains fatal Beat and revival clears bloodied without a living enemy',function()
 for _,advanced in ipairs({false,true})do
  local run=Run.new(D,42);assert(Run.obtainRelic(run,'lizard_tail'));assert(Run.obtainRelic(run,'red_skull'))
  local s=C.new(D,{seed=42,enemies={'corrupt_heart'},deck={},hp=1,maxHp=3,enableStances=advanced})
  Hooks.bindBattle(s,run.relics,run.relicCounters);Hooks.battleStart(s,'red_skull')
  s.relics[#s.relics+1]='magic_flower';s.potionInventory={};s.potionCapacity=2
  A.applyPower(s,s.player,'artifact',1,s.player)
  local card=Cards.fresh(C,s,'strike');s.hand={card};s.enemies[1].hp=1
  local start=#s.events
  local enqueue,planned=Cards.enqueueReaction,0
  Cards.enqueueReaction=function(state,effect,...)
   if state==s and effect.op=='gainStatus'and effect.status=='strength'and effect.value==-3 then
    planned=planned+1;eq(s.enemies[1].hp,0,'callback occurs with no living enemy')
   end
   return enqueue(state,effect,...)
  end
  local called,result=pcall(C.play,s,card.uid,1);Cards.enqueueReaction=enqueue;assert(called,result);assert(result)
  eq(s.enemies[1].hp,0);eq(s.player.hp,2)
  eq(s.relicCounters.lizard_tail,-2);eq(s.relicCombat.redSkullActive,false)
  eq(planned,1,'onNotBloodied still constructs its source TOP action')
  -- Fixed ApplyPowerAction.java:63-66 cancels construction when all monsters
  -- are basically dead. Do not invent retained Strength or consume Artifact.
  -- SHA256 f64ce8511f961a1990f1909e2c55654fa6dbf1dc2f4f1f3d3a7156c2ec2a9d47.
  eq(s.player.statuses.artifact,1);eq(s.player.statuses.strength,3)
  eq(C.outcome(s),'victory');eq(s.discard[1],card)
  local death,beat,heal
  for i=start+1,#s.events do local e=s.events[i]
   if e.kind=='damage'and e.detail.target==s.enemies[1].id then death=i end
   if e.kind=='status_damage'and e.detail.target==s.player.id then beat=i end
   if e.kind=='heal'and e.detail.relic=='lizard_tail'then heal=i end
  end
  assert(death and beat and heal and death<heal and death<beat,'last-card damage and retained Beat must actually execute')
 end
end)

test('real paused Omniscience continuation publishes spent counter to Run immediately',function()
 local run=Run.new(D,42,{experimental=true,character='watcher'})
 assert(Run.obtainRelic(run,'lizard_tail'));assert(Run.startCombat(run,'cultist_solo'))
 -- Controlled Heart encounter boundary, using genuine constructors/opening
 -- ownership and a real Watcher choice; this is not a natural Act4 route.
 run.maxHp,run.hp=7,1
 local s=C.new(run.data,{seed=42,enemies={'corrupt_heart'},deck={},hp=1,maxHp=7,enableStances=true,
  beforeOpeningDraw=function(state)Hooks.bindBattle(state,run.relics,run.relicCounters);return true end})
 run.combat=s;s.combatGeneration=run.combatGeneration;s.potionInventory={};s.potionCapacity=2
 local omni,selected=Cards.fresh(C,s,'omniscience'),Cards.fresh(C,s,'empty_fist')
 s.hand={omni};s.draw={selected};s.discard={};s.energy=20
 assert(Run.play(run,omni.uid));local choice=assert(s.pendingPileChoice)
 eq(run.relicCounters.lizard_tail,-1);eq(s.relicCounters.lizard_tail,-1)
 assert(not Run.choosePile(run,{selected.uid},choice.token+1,choice.generation))
 eq(run.relicCounters.lizard_tail,-1);eq(s.pendingPileChoice,choice)
 assert(Run.choosePile(run,{selected.uid},choice.token,choice.generation))
 assert(s.player.hp>0 and not s.pendingPileChoice and not s.actionQueue)
 eq(run.phase,'combat');eq(s.relicCounters.lizard_tail,-2);eq(run.relicCounters.lizard_tail,-2)
end)
print('LIZARD_TAIL_ACTION_ORDER_PASS '..count..' groups; controlled offline, not natural/platform evidence')
