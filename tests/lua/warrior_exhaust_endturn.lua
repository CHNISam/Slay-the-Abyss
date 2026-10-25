package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C=require('abyss_combat')
local R=require('abyss_sts_random')
local W=require('abyss_warrior_cards')
local E=require('abyss_warrior_exhaust_cards')
local Retained=require('abyss_retained_cards')
local Corruption=require('abyss_corruption')
local Events=require('abyss_events')
local data=Retained.withCards(E.withCards(W.withFoundationCards(require('abyss_data'))))
local n=0
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function test(name,fn) fn();n=n+1;print('ok warrior exhaust endturn '..n..' - '..name) end
local function held(s,id)
 for _,c in ipairs(s.hand) do if c.cardId==id then return c end end
 error('missing '..id)
end
local function play(s,id)
 local ok,reason=C.play(s,held(s,id).uid);assert(ok,reason)
end
local function battle(deck)
 local s=C.new(data,{seed=42,deck=deck,enemies={'cultist'},cardRandomSeed='42'})
 s.energy=20;return s
end
-- Only fixture positions are changed; every UID comes from Combat.new.
local function arrange(s,ids)
 local all={}
 for _,pile in ipairs({s.hand,s.draw,s.discard,s.exhaust}) do
  for _,card in ipairs(pile) do all[#all+1]=card end
 end
 s.hand={};s.draw={};s.discard={};s.exhaust={}
 for _,id in ipairs(ids) do
  local found
  for i,card in ipairs(all) do if card.cardId==id then found=table.remove(all,i);break end end
  s.hand[#s.hand+1]=assert(found,'missing fixture card '..id)
 end
 for _,card in ipairs(all) do s.draw[#s.draw+1]=card end
end
local function event(s,kind,from)
 for i=from or 1,#s.events do if s.events[i].kind==kind then return s.events[i],i end end
 error('missing event '..kind)
end
local function makeDiscardSkill(s)
 C.applyEffects(s,{{op='makeTempCardInDiscard',card='defend',value=1}},s.player,s.player)
 return s.discard[#s.discard]
end
local function freeze(root)
 local saved,pending={}, {root}
 while #pending>0 do
  local t=table.remove(pending)
  if not saved[t] then
   local entries={};saved[t]=entries
   for k,v in pairs(t) do entries[k]=v;if type(v)=='table' then pending[#pending+1]=v end end
  end
 end
 return function()
  for t,entries in pairs(saved) do
   for k,v in pairs(entries) do eq(t[k],v) end
   for k,v in pairs(t) do eq(entries[k],v) end
  end
 end
end
test('Dazed and Carnage each trigger FNP and DE at end turn without asserting their random order',function()
 local s=battle({'feel_no_pain','dark_embrace','dazed','carnage','strike','defend'})
 arrange(s,{'feel_no_pain','dark_embrace','dazed','carnage'})
 play(s,'feel_no_pain');play(s,'dark_embrace')
 local dazed,carnage=held(s,'dazed'),held(s,'carnage');local first=#s.events+1
 assert(C.endTurn(s));eq(s.turn,2);eq(s.phase,'player')
 eq(#s.exhaust,2);local seen={};for _,c in ipairs(s.exhaust) do seen[c]=true end
 assert(seen[dazed] and seen[carnage]);eq(#s.hand,2)
 local blocks,total=0,0
 for i=first,#s.events do
  local e=s.events[i]
  if e.kind=='block' and e.detail.source==s.player.id then
   blocks=blocks+1;total=total+e.detail.amount;eq(#e.frame.exhaust,2)
  end
 end
 eq(blocks,2);eq(total,6);eq(s.player.block,0)
 eq(s.cardRandomRng.counter,0) -- No assertion about Java Collections.shuffle's separate randomness.
end)
for _,firstPower in ipairs({'feel_no_pain','dark_embrace'}) do
 test('single Ethereal preserves Power acquisition order with '..firstPower..' first',function()
  local s=battle({'feel_no_pain','dark_embrace','dazed','strike'})
  arrange(s,{'feel_no_pain','dark_embrace','dazed'})
  local other=firstPower=='feel_no_pain' and 'dark_embrace' or 'feel_no_pain'
  play(s,firstPower);play(s,other);local first=#s.events+1
  assert(C.endTurn(s));local b=event(s,'block',first)
  eq(b.detail.amount,3);eq(#b.frame.hand,firstPower=='feel_no_pain' and 0 or 1)
 end)
end
test('retained cards return before DE draws while their queued cost reduction remains after those tails',function()
 local s=battle({'feel_no_pain','dark_embrace','dazed','sands_of_time','strike'})
 arrange(s,{'feel_no_pain','dark_embrace','dazed','sands_of_time'})
 play(s,'feel_no_pain');play(s,'dark_embrace')
 local sand=held(s,'sands_of_time');local first=#s.events+1
 assert(C.endTurn(s))
 local restore,ri=event(s,'retain',first);local block,bi=event(s,'block',first)
 local reduced,ci=event(s,'retained_cost',first);local enemy,ei=event(s,'enemy_turn',first)
 assert(ri<bi and bi<ci and ci<ei)
 eq(#restore.frame.hand,1);eq(restore.frame.hand[1].uid,sand.uid)
 eq(#block.frame.hand,1);eq(#reduced.frame.hand,2);eq(#enemy.frame.hand,2)
 eq(sand.combatCost,3);eq(sand.turnCost,3);eq(sand.retainedCostReduction,1)
 eq(s.hand[1],sand);eq(C.cardDefinition(s,sand).cost,3)
end)
test('restoring nine retained cards leaves one hand slot for a two-card DE draw',function()
 local deck={'feel_no_pain','dark_embrace','dark_embrace','dazed','strike','strike','strike','strike'}
 for _=1,9 do deck[#deck+1]='windmill_strike' end
 local s=battle(deck);arrange(s,{'feel_no_pain','dark_embrace','dark_embrace'})
 play(s,'feel_no_pain');play(s,'dark_embrace');play(s,'dark_embrace')
 local hand={'dazed'};for _=1,9 do hand[#hand+1]='windmill_strike' end
 arrange(s,hand);local first=#s.events+1
 assert(C.endTurn(s));local block=event(s,'block',first);local enemy=event(s,'enemy_turn',first)
 eq(#block.frame.hand,9);eq(#enemy.frame.hand,10);eq(#enemy.frame.draw,3)
 eq(#s.hand,10);eq(#s.draw,3);eq(s.player.statuses.dark_embrace,2)
 for _,card in ipairs(s.hand) do
  if card.cardId=='windmill_strike' then eq(card.retainedDamageBonus,4);eq(card.retainedTurn,1) end
 end
end)
test('real Battle Trance NoDraw is removed before Ethereal and allows end-turn DE',function()
 local s=battle({'feel_no_pain','dark_embrace','battle_trance','dazed','carnage'})
 play(s,'feel_no_pain');play(s,'dark_embrace');play(s,'battle_trance')
 eq(s.player.noDraw,true);local first=#s.events+1
 assert(C.endTurn(s));local enemy=event(s,'enemy_turn',first)
 local removed,ri=event(s,'no_draw_removed',first);local exhausted,xi=event(s,'exhaust',first)
 assert(ri<xi);eq(removed.frame.player.noDraw,false);eq(exhausted.frame.player.noDraw,false)
 eq(#enemy.frame.hand,1);eq(enemy.frame.hand[1].cardId,'battle_trance')
 eq(#enemy.frame.exhaust,2);eq(#enemy.frame.discard,0)
 local amount=0
 for i=first,#s.events do local e=s.events[i];if e.kind=='block' then amount=amount+e.detail.amount end end
 eq(amount,6);eq(s.player.noDraw,false)
 eq(#s.hand,1);eq(s.hand[1].cardId,'battle_trance') -- Already drawn by DE before enemy actions.
end)
test('lethal Regret stops before NoDraw removal and preserves the original card in use',function()
 local s=battle({'feel_no_pain','dark_embrace','battle_trance','regret','dazed','carnage'})
 arrange(s,{'feel_no_pain','dark_embrace','battle_trance','regret','dazed','carnage'})
 play(s,'feel_no_pain');play(s,'dark_embrace');play(s,'battle_trance')
 local regret,dazed,carnage=held(s,'regret'),held(s,'dazed'),held(s,'carnage')
 eq(s.player.noDraw,true);s.player.hp=3;local first=#s.events+1
 assert(C.endTurn(s));eq(s.player.hp,0);eq(s.phase,'defeat');eq(s.turn,1)
 eq(s.player.noDraw,true);eq(s.cardInUse,regret);eq(s.cardInUse.uid,regret.uid)
 eq(#s.exhaust,0);eq(#s.discard,1);eq(s.discard[1].cardId,'battle_trance')
 eq(#s.hand,2);local remaining={};for _,c in ipairs(s.hand) do remaining[c]=true end
 assert(remaining[dazed] and remaining[carnage])
 for i=first,#s.events do
  local kind=s.events[i].kind
  assert(kind~='no_draw_removed' and kind~='exhaust' and kind~='enemy_turn','death must stop later cleanup')
 end
end)
test('post-reset DE draws get temporary zero cost that survives the following start turn',function()
 local s=battle({'corruption','dark_embrace','dazed'})
 play(s,'corruption');play(s,'dark_embrace')
 local fresh=makeDiscardSkill(s);eq(fresh.combatCost,nil);eq(fresh.turnCost,nil)
 local first=#s.events+1;assert(C.endTurn(s));local enemy=event(s,'enemy_turn',first)
 eq(#enemy.frame.hand,1);eq(enemy.frame.hand[1].uid,fresh.uid);eq(enemy.frame.hand[1].turnCost,0)
 eq(s.hand[1],fresh);eq(fresh.turnCost,0);eq(fresh.combatCost,nil)
 assert(Corruption.remove(s));eq(C.cardDefinition(s,fresh).cost,0)
 assert(C.endTurn(s));eq(fresh.turnCost,nil);eq(fresh.combatCost,nil);eq(C.cardDefinition(s,fresh).cost,1)
end)
test('removing Corruption retains old combat reductions through end-turn reset',function()
 local s=battle({'corruption','dark_embrace','defend'})
 local old=held(s,'defend');play(s,'corruption');play(s,'dark_embrace')
 eq(old.combatCost,0);assert(Corruption.remove(s));eq(C.cardDefinition(s,old).cost,0)
 assert(C.endTurn(s));eq(old.turnCost,nil);eq(old.combatCost,0);eq(C.cardDefinition(s,old).cost,0)
 local before=s.energy;play(s,'defend');eq(s.energy,before)
 eq(s.discard[1],old);eq(#s.exhaust,0) -- The removed Power no longer forces Skill exhaust.
end)
test('Corruption preserves a positive energy threshold while actual Skill payment stays free',function()
 local s=battle({'corruption','defend'});local defend=held(s,'defend');play(s,'corruption')
 -- A supported instance-cost override models a positive modifier after the
 -- constructor scan. It is not a replacement card/effect implementation.
 defend.turnCost=2;s.energy=1
 local ok,reason=C.canPlay(s,defend.uid);eq(ok,false);eq(reason,'insufficient_energy')
 eq(C.play(s,defend.uid),false);eq(s.energy,1);eq(s.hand[1],defend)
 s.energy=2;assert(C.canPlay(s,defend.uid));assert(C.play(s,defend.uid))
 eq(s.energy,2);eq(s.player.block,5);eq(s.exhaust[1],defend)
end)
test('advanced end-turn failure restores original costs, cards, piles, RNG and nested graph before retry',function()
 local s=battle({'dark_embrace','feel_no_pain','corruption','sands_of_time','dazed'})
 play(s,'dark_embrace');play(s,'feel_no_pain');play(s,'corruption')
 local sand,dazed=held(s,'sands_of_time'),held(s,'dazed');sand.turnCost=2
 local fresh=makeDiscardSkill(s);s.shuffleRng=R.fromSeed('9001')
 local hand,draw,discard,exhaust,events=s.hand,s.draw,s.discard,s.exhaust,s.events
 local rng,primitive=s.shuffleRng,s.shuffleRng.primitive
 local originalTurn=s.turn;local originalCounter=R.snapshot(rng).counter
 local unchanged=freeze(s);local emit=Events.emit;local observed=false
 Events.emit=function(state,kind,detail)
  local result=emit(state,kind,detail)
  if state==s and kind=='retained_cost' then
   observed=true
   eq(sand.combatCost,3);eq(sand.retainedCostReduction,1)
   eq(fresh.turnCost,0);eq(#s.exhaust,1);eq(s.exhaust[1],dazed)
   assert(R.snapshot(rng).counter>originalCounter,'real DE reshuffle must have executed before the fault')
   error('warrior end-turn fault after real retained cost action')
  end
  return result
 end
 local called,reason=pcall(C.endTurn,s);Events.emit=emit
 eq(called,false);assert(observed);assert(tostring(reason):find('warrior end-turn fault',1,true))
 unchanged();eq(s.hand,hand);eq(s.draw,draw);eq(s.discard,discard);eq(s.exhaust,exhaust);eq(s.events,events)
 eq(s.shuffleRng,rng);eq(rng.primitive,primitive);eq(R.snapshot(rng).counter,originalCounter)
 eq(s.turn,originalTurn);eq(s.phase,'player');eq(s.actionQueue,nil);eq(s.retainedCards,nil)
 eq(sand.turnCost,2);eq(sand.combatCost,nil);eq(sand.retainedTurn,nil)
 eq(fresh.turnCost,nil);eq(fresh.combatCost,nil)
 local first=#s.events+1;assert(C.endTurn(s));eq(s.turn,originalTurn+1)
 eq(sand.combatCost,3);eq(sand.retainedCostReduction,1);eq(s.exhaust[1],dazed)
 local blocks=0;for i=first,#s.events do if s.events[i].kind=='block' then blocks=blocks+1 end end
 eq(blocks,1);eq(s.actionQueue,nil)
end)
print('WARRIOR_EXHAUST_ENDTURN_PASS'..n)
