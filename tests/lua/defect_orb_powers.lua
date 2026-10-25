package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C=require('abyss_combat')
local O=require('abyss_orbs')
local F=require('abyss_focus')
local P=require('abyss_orb_powers')
local data=P.withCards(require('abyss_defect_cards').withFoundationCards(require('abyss_data')))
local n=0
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function test(name,fn)fn();n=n+1;print('ok '..n..' '..name)end
local function setup(cards)
 return C.new(data,{seed=42,orbSlots=3,orbRandomSeed='17',deck=cards or {'loop'},enemies={'jaw_worm','jaw_worm'}})
end
local function uid(s,id)for _,c in ipairs(s.hand)do if c.cardId==id then return c.uid end end;error('missing '..id)end
local function ch(s,k)assert(O.channel(s,k,C))end
for _,up in ipairs({false,true})do
 local tag=up and '+' or ''
 test('Loop'..tag..' adds source stacks and no immediate passive',function()
  local s=setup({{cardId='loop',upgraded=up}});ch(s,'frost');assert(C.play(s,uid(s,'loop')))
  eq(s.energy,2);eq(s.player.block,0);eq(s.player.statuses.loop,up and 2 or 1);eq(#s.discard,0)
  assert(C.endTurn(s));eq(s.player.block,up and 4 or 2)
 end)
 test('Loop'..tag..' only first Dark grows synchronously',function()
  local s=setup({{cardId='loop',upgraded=up}});ch(s,'dark');ch(s,'dark');O.setFocus(s,2)
  assert(C.play(s,uid(s,'loop')));assert(C.endTurn(s))
  eq(s.orbs.balls[1].stored,up and 30 or 22);eq(s.orbs.balls[2].stored,14)
 end)
 test('Loop'..tag..' Plasma triggers before opening draw plus normal Plasma once',function()
  local s=setup({{cardId='loop',upgraded=up},'strike'});ch(s,'plasma');assert(C.play(s,uid(s,'loop')))
  assert(C.endTurn(s));eq(s.energy,up and 6 or 5);eq(#s.hand,1)
  local found=false
  for _,e in ipairs(s.events)do
   if e.kind=='orb_effect' and e.detail.orb=='plasma' and e.frame.turn==2 then eq(#e.frame.hand,0);found=true end
  end
  assert(found,'Plasma did not execute in pre-draw phase')
 end)
 test('Electrodynamics'..tag..' source cost and correct channel count',function()
  local s=setup({{cardId='electrodynamics',upgraded=up}});s.player.statuses.artifact=1
  assert(C.play(s,uid(s,'electrodynamics')));eq(s.energy,1);eq(s.player.statuses.electrodynamics,1)
  eq(s.player.statuses.artifact,1);eq(#s.orbs.balls,up and 3 or 2);eq(#s.discard,0)
 end)
 test('Electrodynamics'..tag..' applied before full-slot overflow hits all without RNG',function()
  local s=setup({{cardId='electrodynamics',upgraded=up}});for i=1,3 do ch(s,'lightning')end
  local h1,h2=s.enemies[1].hp,s.enemies[2].hp;local counter=s.cardRandomRng.counter
  assert(C.play(s,uid(s,'electrodynamics')));local hits=up and 3 or 2
  eq(s.enemies[1].hp,h1-8*hits);eq(s.enemies[2].hp,h2-8*hits);eq(s.cardRandomRng.counter,counter);eq(#s.orbs.balls,3)
 end)
end
for _,biasFirst in ipairs({false,true})do
 local label=biasFirst and 'Bias then Loop' or 'Loop then Bias'
 test(label..' Frost snapshots old Focus but event order follows acquisition',function()
  local s=setup({'loop','biased_cognition'});ch(s,'frost');O.setFocus(s,2)
  if biasFirst then assert(C.play(s,uid(s,'biased_cognition')));assert(C.play(s,uid(s,'loop')))
  else assert(C.play(s,uid(s,'loop')));assert(C.play(s,uid(s,'biased_cognition')))end
  eq(s.player.statuses.focus,6);assert(C.endTurn(s));eq(s.player.statuses.focus,5);eq(s.player.block,8)
  local found=false
  for _,e in ipairs(s.events)do
   if e.kind=='block' and e.frame.turn==2 then eq(e.detail.amount,8);eq(e.frame.player.statuses.focus,biasFirst and 5 or 6);found=true end
  end
  assert(found)
 end)
 test(label..' Dark growth happens before queued Focus reduction',function()
  local s=setup({'loop','biased_cognition'});ch(s,'dark');O.setFocus(s,2)
  if biasFirst then C.play(s,uid(s,'biased_cognition'));C.play(s,uid(s,'loop'))
  else C.play(s,uid(s,'loop'));C.play(s,uid(s,'biased_cognition'))end
  assert(C.endTurn(s));eq(s.orbs.balls[1].stored,30);eq(s.player.statuses.focus,5)
 end)
end

test('Loop lightning uses old Focus even when Bias action is ahead',function()
 local s=setup({'biased_cognition','loop'});ch(s,'lightning');C.play(s,uid(s,'biased_cognition'));C.play(s,uid(s,'loop'))
 assert(C.endTurn(s));eq(s.player.statuses.focus,3)
 local found=false;for _,e in ipairs(s.events)do if e.kind=='damage' and e.frame.turn==2 then eq(e.detail.amount+e.detail.blocked,7);found=true end end;assert(found)
end)
test('Electro passive skips dead enemies without card random draws or normal attack retaliation',function()
 local s=setup({'electrodynamics'});C.play(s,uid(s,'electrodynamics'));local hp=s.player.hp
 s.player.statuses.strength=50;s.player.statuses.weak=2
 for _,e in ipairs(s.enemies)do e.statuses.thorns=20;e.statuses.vulnerable=3;e.statuses.angry=2 end
 local h1,h2=s.enemies[1].hp,s.enemies[2].hp;local counter=s.cardRandomRng.counter
 O.endTurn(s,C);eq(s.enemies[1].hp,h1-6);eq(s.enemies[2].hp,h2-6);eq(s.player.hp,hp);eq(s.cardRandomRng.counter,counter)
 eq(s.enemies[1].statuses.strength or 0,0)
end)
test('AOE action snapshots mode and never requires RNG even after Electro is removed',function()
 local s=setup({'electrodynamics'});C.play(s,uid(s,'electrodynamics'))
 local a=O.preparePassive(s,1,'end');s.player.statuses.electrodynamics=0;s.cardRandomRng=nil
 local h1,h2=s.enemies[1].hp,s.enemies[2].hp;assert(O.resolve(s,a,C));eq(s.enemies[1].hp,h1-3);eq(s.enemies[2].hp,h2-3)
end)
test('non-AOE action stays random if Electro is obtained only after construction',function()
 local s=setup({'loop'});ch(s,'lightning');local a=O.preparePassive(s,1,'end')
 P.apply(s,'electrodynamics',1);local h1,h2=s.enemies[1].hp,s.enemies[2].hp
 O.resolve(s,a,C);eq((h1-s.enemies[1].hp)+(h2-s.enemies[2].hp),3);eq(s.cardRandomRng.counter,1)
end)
test('full overflow kills all and clears subsequent channel actions',function()
 local s=setup({'electrodynamics'});for i=1,3 do ch(s,'lightning')end
 for _,e in ipairs(s.enemies)do e.hp=1 end
 assert(C.play(s,uid(s,'electrodynamics')));eq(s.phase,'victory');eq(#s.orbs.balls,2);eq(s.cardRandomRng.counter,0)
end)
test('Power phase killing final enemy clears later Plasma energy and Bias loss',function()
 local s=setup({'loop','biased_cognition','electrodynamics'});ch(s,'lightning');ch(s,'plasma')
 C.play(s,uid(s,'loop'));C.play(s,uid(s,'biased_cognition'));P.apply(s,'electrodynamics',1)
 for _,e in ipairs(s.enemies)do e.hp=1 end
 -- Directly run the source pre-draw Power phase to isolate victory clearing.
 s.energy=3;P.startTurnPower(s,C);eq(s.player.statuses.focus,4);eq(s.energy,3)
end)
test('new Loop after existing Bias restores acquisition order on failed card',function()
 local s=setup({'loop','biased_cognition'});C.play(s,uid(s,'biased_cognition'))
 local order=s.orbPowerOrder;eq(order[1],'bias')
 s.catalog.cards.loop.effects[2]={op='channelOrb',orb='bad',value=1};local before=#s.events
 assert(not pcall(C.play,s,uid(s,'loop')));eq(s.orbPowerOrder,order);eq(#order,1);eq(s.player.statuses.loop,nil);eq(#s.events,before)
end)
test('unknown dual Power history refuses without guessing or growing Dark',function()
 local s=setup({'loop'});ch(s,'dark');s.player.statuses.loop=1;s.player.statuses.bias=1
 assert(not pcall(P.startTurnPower,s,C));eq(s.orbs.balls[1].stored,6)
end)
test('single legacy Bias fixture may run without history; dual history never inferred',function()
 local s=setup({'loop'});O.setFocus(s,4);s.player.statuses.bias=1;assert(P.startTurnPower(s,C));eq(s.player.statuses.focus,3)
end)
test('stacking Loop does not change earliest acquisition position',function()
 local s=setup({'loop','loop','biased_cognition'});C.play(s,uid(s,'loop'));C.play(s,uid(s,'biased_cognition'));C.play(s,uid(s,'loop'))
 eq(#s.orbPowerOrder,2);eq(s.orbPowerOrder[1],'loop');eq(s.orbPowerOrder[2],'bias');eq(s.player.statuses.loop,2)
end)
test('zero occupied slots and dead players cannot produce extra passive effects',function()
 local s=setup({'loop'});C.play(s,uid(s,'loop'));assert(P.startTurnPower(s,C));eq(s.energy,2)
 ch(s,'plasma');s.player.hp=0;eq(P.startTurnPower(s,C),false);eq(s.energy,2)
end)
test('AOE skips an already dead slot while hitting every remaining enemy',function()
 local s=C.new(data,{seed=42,orbSlots=3,orbRandomSeed='17',deck={'electrodynamics'},enemies={'jaw_worm','jaw_worm','jaw_worm'}})
 C.play(s,uid(s,'electrodynamics'));s.enemies[2].hp=0
 local h1,h3=s.enemies[1].hp,s.enemies[3].hp;local count=s.cardRandomRng.counter
 O.endTurn(s,C);eq(s.enemies[1].hp,h1-6);eq(s.enemies[2].hp,0);eq(s.enemies[3].hp,h3-6);eq(s.cardRandomRng.counter,count)
end)
test('positive Loop does not consume Artifact and preserves source boolean Electro stacking',function()
 local s=setup({'loop'});s.player.statuses.artifact=1;assert(C.play(s,uid(s,'loop')))
 eq(s.player.statuses.artifact,1);P.apply(s,'electrodynamics',1);P.apply(s,'electrodynamics',1);eq(s.player.statuses.electrodynamics,1)
end)
print('DEFECT_ORB_POWERS_PASS '..n)
