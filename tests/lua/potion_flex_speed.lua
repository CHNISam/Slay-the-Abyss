package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,A=require('abyss_run'),require('abyss_combat'),require('abyss_actor')
local Data=require('abyss_data')
local base=Run.new(Data,42)
local first,last=...
first,last=first or 1,last or 3
assert(first>=1 and last<=11 and first<=last,'invalid budget slice')
local count,registered=0,0
local specs={{'flex_potion','strength','temporaryStrength','lose_strength'},
 {'speed_potion','dexterity','temporaryDexterity','lose_dexterity'}}
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function same(a,b)
 eq(type(a),type(b));if type(a)~='table' then eq(a,b);return end
 for k,v in pairs(a) do same(v,b[k]) end
 for k in pairs(b) do assert(a[k]~=nil,'unexpected '..tostring(k)) end
end
local function test(name,fn)
 registered=registered+1;if registered<first or registered>last then return end
 fn();count=count+1;print('ok Flex Speed '..registered..' - '..name)
end
local function battle(ids)
 local run=C.copy(base)
 for _,id in ipairs(ids) do assert(Run.obtainPotion(run,id)) end
 assert(Run.startCombat(run,'cultist_solo'));return run
end
local function refused(run,slot,reason)
 local before=C.copy(run);local root,potions=run.combat,run.potions
 local ok,why=Run.usePotion(run,slot);eq(ok,false);eq(why,reason)
 same(run,before);eq(root,run.combat);eq(potions,run.potions)
end
test('real Run preview and second-slot use add five, spend one bottle only, then restore original signed stat',function()
 for _,v in ipairs(specs) do
  local run=battle({'fire_potion',v[1],'block_potion'});local s=run.combat
  C.addStatus(s.player,v[2],-2);local before=C.copy(run);local view=Run.potionView(run)[2]
  assert(view.canUse and not view.needTarget);same(run,before)
  local energy=s.energy;assert(Run.usePotion(run,2));eq(s.player.statuses[v[2]],3);eq(s.player[v[3]],5)
  eq(s.energy,energy);eq(run.potions[1],'fire_potion');eq(run.potions[3],'block_potion')
  refused(run,2,'empty_potion_slot');assert(Run.endTurn(run));eq(s.player.statuses[v[2]],-2);eq(s.player[v[3]],0)
  assert(Run.endTurn(run));eq(s.player.statuses[v[2]],-2)
 end
end)
test('Artifact obtained before either potion blocks only the delayed-loss DEBUFF after positive gain',function()
 for _,v in ipairs(specs) do
  local run=battle({'ancient_potion',v[1]});local s=run.combat
  assert(Run.usePotion(run,1));local start=#s.events;assert(Run.usePotion(run,2))
  eq(s.player.statuses[v[2]],5);eq(s.player.statuses.artifact,0);eq(s.player[v[3]] or 0,0)
  local gain,blocked
  for i=start+1,#s.events do
   local e=s.events[i];if e.kind=='status' and e.detail.status==v[2] then gain=i end
   if e.kind=='status' and e.detail.blockedStatus==v[4] then blocked=i end
  end
  assert(gain and blocked and gain<blocked);assert(Run.endTurn(run));eq(s.player.statuses[v[2]],5)
 end
end)
test('Artifact obtained after delayed loss blocks the negative Power at turn end and debt is removed once',function()
 for _,v in ipairs(specs) do
  local run=battle({v[1],'ancient_potion'});local s=run.combat
  assert(Run.usePotion(run,1));assert(Run.usePotion(run,2));eq(s.player[v[3]],5)
  assert(Run.endTurn(run));eq(s.player.statuses[v[2]],5);eq(s.player[v[3]],0);eq(s.player.statuses.artifact,0)
  assert(Run.endTurn(run));eq(s.player.statuses[v[2]],5)
 end
end)
test('same potion stacks debt, while a separately blocked new loss leaves old debt intact',function()
 for _,v in ipairs(specs) do
  local run=battle({v[1],v[1],'ancient_potion'});local s=run.combat
  assert(Run.usePotion(run,1));assert(Run.usePotion(run,2));eq(s.player[v[3]],10)
  assert(Run.endTurn(run));eq(s.player.statuses[v[2]],0);eq(s.player[v[3]],0)
  run=battle({v[1],'ancient_potion',v[1]});s=run.combat
  assert(Run.usePotion(run,1));assert(Run.usePotion(run,2));assert(Run.usePotion(run,3))
  eq(s.player.statuses[v[2]],10);eq(s.player[v[3]],5);eq(s.player.statuses.artifact,0)
  assert(Run.endTurn(run));eq(s.player.statuses[v[2]],5)
 end
end)
test('mixed delayed losses retain first application order; later Artifact protects the first stat',function()
 for _,ids in ipairs({{'speed_potion','flex_potion'},{'flex_potion','speed_potion'}}) do
  local run=battle({ids[1],ids[2],'ancient_potion'});local s=run.combat
  assert(Run.usePotion(run,1));local firstFrame=s.events[#s.events].frame
  assert(Run.usePotion(run,2));assert(Run.usePotion(run,3))
  eq(#firstFrame.player.temporaryPowerOrder,1)
  assert(Run.endTurn(run));eq(s.player.statuses.artifact,0)
  local first=ids[1]=='speed_potion' and 'dexterity' or 'strength'
  local second=first=='strength' and 'dexterity' or 'strength'
  eq(s.player.statuses[first],5);eq(s.player.statuses[second],0)
  eq(s.player.temporaryPowerOrder,nil)
 end
 local run=battle({'ancient_potion','speed_potion','flex_potion'});local s=run.combat
 assert(Run.usePotion(run,1));assert(Run.usePotion(run,2));assert(Run.usePotion(run,3))
 local ok,slot=Run.obtainPotion(run,'speed_potion');assert(ok);assert(Run.usePotion(run,slot))
 ok,slot=Run.obtainPotion(run,'ancient_potion');assert(ok);assert(Run.usePotion(run,slot))
 assert(Run.endTurn(run));eq(s.player.statuses.strength,5);eq(s.player.statuses.dexterity,5)
end)
test('stacking existing LoseDexterity does not move it behind newly introduced LoseStrength',function()
 local run=battle({'speed_potion','flex_potion','speed_potion'});local s=run.combat
 assert(Run.usePotion(run,1));assert(Run.usePotion(run,2));assert(Run.usePotion(run,3))
 local ok,slot=Run.obtainPotion(run,'ancient_potion');assert(ok);assert(Run.usePotion(run,slot))
 assert(Run.endTurn(run));eq(s.player.statuses.dexterity,10);eq(s.player.statuses.strength,0)
end)
test('signed caps do not reduce the source delayed-loss amount',function()
 for _,v in ipairs(specs) do
  local run=battle({v[1]});local s=run.combat;C.addStatus(s.player,v[2],998)
  assert(Run.usePotion(run,1));eq(s.player.statuses[v[2]],999);eq(s.player[v[3]],5)
  assert(Run.endTurn(run));eq(s.player.statuses[v[2]],994)
 end
end)
test('real Strike and Defend receive five additional damage or block, then return to base next turn',function()
 local source=C.copy(Data);source.cards.starter_deck.cards={'strike','defend','defend','defend','defend'}
 local prepared=Run.new(source,42)
 for _,v in ipairs(specs) do
  local run=C.copy(prepared);assert(Run.obtainPotion(run,v[1]));assert(Run.startCombat(run,'cultist_solo'))
  local s=run.combat;assert(Run.usePotion(run,1));local cardId=v[2]=='strength' and 'strike' or 'defend'
  for turn=1,2 do
   local uid;for _,card in ipairs(s.hand) do if card.cardId==cardId then uid=card.uid;break end end
   local hp=s.enemies[1].hp;assert(Run.play(run,uid,1))
   if cardId=='strike' then eq(hp-s.enemies[1].hp,turn==1 and 11 or 6)
   else eq(s.player.block,turn==1 and 10 or 5) end
   if turn==1 then assert(Run.endTurn(run)) end
  end
 end
end)
test('real Flex card and Flex Potion share one LoseStrength debt and restore together',function()
 -- A fresh legal deck gives the existing card to Run.play; no synthetic effect invocation.
 local source=C.copy(Data);source.cards.starter_deck.cards={'flex','defend','defend','defend','defend'}
 local run=Run.new(source,42);assert(Run.obtainPotion(run,'flex_potion'));assert(Run.startCombat(run,'cultist_solo'));local s=run.combat
 local uid;for _,card in ipairs(s.hand) do if card.cardId=='flex' then uid=card.uid end end
 assert(Run.play(run,uid));assert(Run.usePotion(run,1));eq(s.player.statuses.strength,7);eq(s.player.temporaryStrength,7)
 assert(Run.endTurn(run));eq(s.player.statuses.strength,0)
end)
test('runs own independent delayed loss and status views expose temporary Dexterity',function()
 local a,b=battle({'speed_potion'}),battle({'speed_potion'});assert(Run.usePotion(a,1))
 eq(b.combat.player.temporaryDexterity,nil);eq(b.combat.player.statuses.dexterity or 0,0)
 local found;for _,row in ipairs(A.statusView(a.combat.player)) do if row.id=='dexterity' then found=row end end
 assert(found);eq(found.temporary,5)
 assert(Run.endTurn(a));assert(Run.usePotion(b,1));eq(b.combat.player.statuses.dexterity,5)
 for _,v in ipairs(specs) do
  local run=battle({v[1]});C.addStatus(run.combat.player,v[2],-5);assert(Run.usePotion(run,1))
  local visible;for _,row in ipairs(A.statusView(run.combat.player)) do if row.id==v[2] then visible=row end end
  assert(visible,'zero net stat must not hide its delayed loss');eq(visible.amount,0);eq(visible.temporary,5)
  assert(Run.endTurn(run));eq(run.combat.player.statuses[v[2]],-5)
 end
end)
test('invalid use and unblocked debt overflow are atomic; Artifact-blocked nonexistent debt does not overflow',function()
 for _,v in ipairs(specs) do
  local run=battle({v[1]});refused(run,0,'invalid_potion_slot');refused(run,1.5,'invalid_potion_slot')
  run.combat.phase='enemy';refused(run,1,'not_player_turn');run.combat.phase='player'
  run.phase='map';refused(run,1,'not_in_combat');run.phase='combat'
  run.combat.player[v[3]]=2147483647;refused(run,1,'potion_effect_failed')
  assert(Run.obtainPotion(run,'ancient_potion'));assert(Run.usePotion(run,2));assert(Run.usePotion(run,1))
  eq(run.combat.player[v[3]],2147483647);eq(run.combat.player.statuses[v[2]],5)
 end
end)
assert(registered==11,'all original cases must remain registered')
assert(count==last-first+1,'each selected case must execute')
print('LUA_POTION_FLEX_SPEED_PASS '..count)
