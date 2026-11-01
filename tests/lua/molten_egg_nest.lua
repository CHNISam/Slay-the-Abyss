-- Controlled event/health boundaries with real Nodes/Run, not natural play.
local H=dofile('tests/helpers/act2_event_ui.lua')
local Run,Nodes,Hooks=H.Run,H.Nodes,H.Hooks
local eq,same=H.eq,H.same
for _,spec in ipairs({{80,'none',74},{1,'none',0},{1,'fairy',24},{1,'tail',40}})do
 local r,m=H.fixture('nest');assert(Run.obtainRelic(r,'Molten Egg 2'));assert(Run.obtainRelic(r,'CeramicFish'))
 if spec[2]=='fairy'then assert(Run.obtainPotion(r,'fairy_in_a_bottle'))
 elseif spec[2]=='tail'then assert(Run.obtainRelic(r,'lizard_tail'))end
 r.hp=spec[1];assert(Nodes.chooseEvent(r,'continue'))
 local uid,gold=r.nextDeckUid,r.gold;local rng=H.Copy({r.eventRng,r.miscRng,r.cardRng,r.treasureRng})
 local on,seen=Hooks.onObtainCard,false
 Hooks.onObtainCard=function(staged,card,definition,api)
  eq(staged.hp,spec[3]);eq(card.upgraded,false)
  local ok,why=on(staged,card,definition,api);eq(card.upgraded,true);eq(card.upgrades,1);seen=true;return ok,why
 end
 local caught,ok,why=pcall(Nodes.chooseEvent,r,'dagger');Hooks.onObtainCard=on;assert(caught and ok,why);assert(seen)
 eq(r.hp,spec[3]);eq(r.gold,gold+9);eq(r.nextDeckUid,uid+1)
 local card=r.deck[#r.deck];eq(card.uid,uid);eq(card.cardId,'ritual_dagger');eq(card.upgraded,true);eq(card.upgrades,1)
 same({r.eventRng,r.miscRng,r.cardRng,r.treasureRng},rng)
 if spec[3]==0 then eq(r.phase,'defeat');eq(r.nodeFlow.complete,true)
 else
  assert(Nodes.chooseEvent(r,'leave'));eq(r.phase,'map')
  -- The fixture staged Act2 before entry; build that chapter's unchanged
  -- source queue, then use the next real map-room command, not an Act1 ID.
  r.encounters=require('abyss_encounter_queue').new(r.runSeed,2)
  local nextNode=assert(H.Map.available(m)[1]);for _,node in ipairs(m.nodes)do if node.id==nextNode.id then node.type='combat'end end
  assert(Nodes.enter(r,m,nextNode.id))
  local found;for _,pile in ipairs({r.combat.hand,r.combat.draw,r.combat.discard})do for _,c in ipairs(pile)do if c.deckUid==uid then found=c end end end
  assert(found and found.upgraded);eq(found.upgrades,1)
  local d=require('abyss_combat').cardDefinition(r.combat,found);eq(d.effects[1].damage,15);eq(d.effects[1].value,5)
 end
end
-- Failure occurs after the real damage/revival + Egg/Ceramic Fish callbacks.
do
 local r,m=H.fixture('nest');assert(Run.obtainRelic(r,'molten_egg'));assert(Run.obtainRelic(r,'ceramic_fish'))
 assert(Run.obtainPotion(r,'fairy_in_a_bottle'));r.hp=1;assert(Nodes.chooseEvent(r,'continue'))
 local on,seen=Hooks.onObtainCard,false
 Hooks.onObtainCard=function(staged,card,definition,api)
  local ok,why=on(staged,card,definition,api);assert(ok,why);eq(staged.hp,24);eq(card.upgraded,true);eq(card.upgrades,1);seen=true
  error('NEST_MOLTEN_LATE_OBTAIN_FAULT')
 end
 local caught,why=pcall(H.unchanged,r,m,function()return Nodes.chooseEvent(r,'dagger')end);Hooks.onObtainCard=on
 assert(caught,why);assert(seen);assert(Nodes.chooseEvent(r,'dagger'));eq(r.hp,24);eq(r.potions[1],nil)
 eq(r.deck[#r.deck].upgraded,true);eq(r.deck[#r.deck].upgrades,1)
end
print('MOLTEN_EGG_NEST_PASS real post-cost upgraded dagger, fatal/Fairy/Tail ordering, next-battle growth5 and full late rollback')
