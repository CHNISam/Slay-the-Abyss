package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local R,D,C,N,Map,P,S=require('abyss_run'),require('abyss_data'),require('abyss_combat'),require('abyss_nodes'),require('abyss_map'),require('abyss_relic_pool'),require('abyss_sts_random')
local count,failed=0,0
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function test(name,fn)local ok,why=pcall(fn);if ok then count=count+1;print('PASS reported relic '..name)else failed=failed+1;print('FAIL reported relic '..name..': '..tostring(why))end end
local function front(r,tier,id)
 local q=r.relicPool.queues[tier]
 for i,v in ipairs(q)do if v==id then table.remove(q,i);break end end
 table.insert(q,1,id)
end
local function event(r)
 local m=Map.generate(D,42);local id=Map.available(m)[1].id
 for _,n in ipairs(m.nodes)do if n.id==id then n.type='event';n.eventId='big_fish' end end
 assert(N.enter(r,m,id));return m
end
test('event box grants its original Helix identity and Regret exactly once',function()
 local r=R.new(D,42);front(r,'rare','FossilizedHelix')
 -- Find a real rarity roll selecting rare, preserving the selected identity.
 for i=0,99 do local pool=P.restore(P.snapshot(r.relicPool),r.relicPool.catalog);pool.rng=S.atCounter(r.eventSeed,i);if P.rollTier(pool,'event')=='rare'then r.relicPool.rng=S.atCounter(r.eventSeed,i);break end end
 event(r);local cards=#r.deck;local ok,why=N.chooseEvent(r,'box');assert(ok,why)
 eq(r.nodeFlow.event.relicOffer.sourceId,'FossilizedHelix');eq(r.relics[#r.relics],'fossilized_helix')
 eq(#r.deck,cards+1);eq(r.deck[#r.deck].cardId,'regret');eq(N.chooseEvent(r,'box'),false)
 assert(N.chooseEvent(r,'leave'));eq(r.phase,'map')
end)
test('Helix obtained through Run blocks one positive HP loss each combat',function()
 local r=R.new(D,42);assert(R.obtainRelic(r,'FossilizedHelix'));assert(R.startCombat(r,'cultist_solo'))
 local s=r.combat;local hp=s.player.hp;eq(s.player.statuses.buffer,1)
 s.player.block=10;C.damage(s,s.enemies[1],s.player,6,true);eq(s.player.hp,hp);eq(s.player.statuses.buffer,1)
 s.player.block=0;C.damage(s,s.enemies[1],s.player,6,true);eq(s.player.hp,hp);eq(s.player.statuses.buffer,nil)
 C.damage(s,s.enemies[1],s.player,6,true);eq(s.player.hp,hp-6)
 r.phase='map';assert(R.startCombat(r,'cultist_solo'));eq(r.combat.player.statuses.buffer,1)
end)
test('Helix does not alter noncombat HP loss',function()
 local r=R.new(D,42);assert(R.obtainRelic(r,'FossilizedHelix'));local hp=r.hp
 event(r);assert(R.eventDamage(r,6));eq(r.hp,hp-6)
end)
test('Pantograph heals 25 only at a Boss opening and respects Bloom',function()
 for _,blocked in ipairs({false,true})do
  local r=R.new(D,42);assert(R.obtainRelic(r,'Pantograph'));r.hp=20
  if blocked then r.relics[#r.relics+1]='mark_of_bloom' end
  assert(R.startCombat(r,'cultist_solo'));eq(r.combat.player.hp,20)
  r.phase='map';r.floor=16
  local id;for _,e in ipairs(r.data.enemies.encounters)do if e.tier=='boss'and e.minFloor<=16 and e.maxFloor>=16 then id=e.id;break end end
  assert(id);assert(R.startCombat(r,id));eq(r.combat.player.hp,blocked and 20 or 45)
 end
end)
test('Magic Flower modifies Meat and Burning Blood once while victory room is still combat',function()
 for _,case in ipairs({{40,false,67},{41,false,50},{40,true,40}})do
  local r=R.new(D,42);assert(R.obtainRelic(r,'Meat on the Bone'));assert(R.obtainRelic(r,'Magic Flower'))
  if case[2]then assert(R.obtainRelic(r,'Mark of the Bloom'))end
  r.hp=case[1];assert(R.startCombat(r,'cultist_solo'));r.combat.enemies[1].hp=1
  local card;for _,c in ipairs(r.combat.hand)do if c.cardId=='strike'then card=c;break end end
  assert(card);assert(R.play(r,card.uid,1));eq(r.phase,'reward');eq(r.hp,case[3])
  eq(R.play(r,card.uid,1),false);eq(r.hp,case[3])
 end
 local r=R.new(D,42);assert(R.obtainRelic(r,'Magic Flower'));r.hp=10
 eq(R.heal(r,6),6);eq(r.hp,16)
end)
test('Unceasing Top draws after the real last-card action queue drains',function()
 local r=R.new(D,42);assert(R.obtainRelic(r,'Unceasing Top'));assert(R.startCombat(r,'cultist_solo'))
 local s=r.combat;local strike
 for _,card in ipairs(s.hand)do if card.cardId=='strike'then strike=card;break end end
 assert(strike and #s.draw>0)
 local drawn=s.draw[1];s.hand={strike};s.draw={drawn};s.discard={}
 local hp=s.enemies[1].hp
 assert(R.play(r,strike.uid,1));eq(r.phase,'combat');assert(s.enemies[1].hp<hp)
 eq(#s.hand,1);eq(s.hand[1].uid,drawn.uid);eq(#s.draw,0)
end)
test('Unceasing Top does not draw before Time Eater forces the twelfth-card turn end',function()
 for _,advanced in ipairs({false,true})do
  local s=C.new(D,{seed=42,enemies={'time_eater'},deck={'strike','defend','strike','defend','strike','defend'},
   enableStances=advanced,beforeFirstTurn=function(state)
    require('abyss_relic_hooks').bindBattle(state,{'unceasing_top'},{});return true
   end})
  local enemy=s.enemies[1];enemy.statuses.time_warp=11
  for i,intent in ipairs(enemy.intents)do if intent.id=='ripple'then enemy.intentIndex=i end end
  local strike;for _,card in ipairs(s.hand)do if card.cardId=='strike'then strike=card;break end end
  assert(strike and #s.draw>0);s.hand={strike};s.draw={s.draw[1]};s.discard={}
  local draw=C.draw;local earlyDraws=0
  C.draw=function(state,n)
   local before=#state.hand;local result=draw(state,n)
   if state==s and state.turn==1 then earlyDraws=earlyDraws+math.max(0,#state.hand-before)end
   return result
  end
  local ok,result=pcall(C.play,s,strike.uid,1);C.draw=draw
  assert(ok,result);assert(result);eq(s.turn,2);eq(earlyDraws,0)
 end
end)
assert(failed==0,tostring(failed)..' reported relic failures')
print('REPORTED_RELIC_FAILURES_PASS '..count)
