-- LOCAL source-action boundary regressions. Real Bloodletting/Hemokinesis
-- definitions; staged powers/piles and two explicitly labeled ABI fixtures.
-- Pinned aeubanks/sts 319009d5: Bloodletting queues LoseHP then GainEnergy;
-- CentennialPuzzle inserts Draw3 at TOP, never inside the current HP action.
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,A,H,Q,AQ,D=require('abyss_combat'),require('abyss_actor'),require('abyss_relic_hooks'),
 require('abyss_card_actions'),require('abyss_action_queue'),require('abyss_data')
local count,failed=0,0
local function eq(a,b,label)assert(a==b,(label or 'value')..': '..tostring(a)..' ~= '..tostring(b))end
local function test(name,fn)
 count=count+1;local ok,why=pcall(fn);if not ok then failed=failed+1 end
 print((ok and 'PASS 'or'FAIL ')..name..(ok and ''or': '..tostring(why)))
end
local function hooks(specs,fn)
 local saved={};for i,h in ipairs(specs)do saved[i]=h[1][h[2]];h[1][h[2]]=h[3](saved[i])end
 local ok,why=pcall(fn);for i,h in ipairs(specs)do h[1][h[2]]=saved[i]end;assert(ok,why)
end
local function unchanged(root)
 local saved={};local function visit(t)
  if type(t)~='table'or saved[t]then return end
  local values={};saved[t]=values;for k,v in pairs(t)do values[k]=v;visit(k);visit(v)end
 end;visit(root)
 return function()for t,values in pairs(saved)do
  for k,v in pairs(values)do eq(t[k],v,'original key '..tostring(k))end
  for k,v in pairs(t)do eq(v,values[k],'extra key '..tostring(k))end
 end end
end
local function card(s,id)
 local c={cardId=id,uid=s.nextUid,upgraded=false};s.nextUid=s.nextUid+1;return c
end
local function battle(mode,owned,id)
 local s=C.new(D,{seed=42,deck={},enemies={'cultist'},enableStances=mode=='stance',
  orbSlots=mode=='orb'and 0 or nil,orbRandomSeed=mode=='orb'and '42'or nil})
 H.bindBattle(s,owned or {'centennial_puzzle'})
 local c=card(s,id or 'bloodletting');s.hand={c};s.draw={};s.discard={}
 for _=1,6 do s.draw[#s.draw+1]=card(s,'defend')end
 return s,c
end
local function clear(s)
 eq(s.cardActions,nil);eq(s.actionQueue,nil);eq(s.pendingPlay,nil)
 eq(s.pendingChoice,nil);eq(s.drainingCardActions,nil);eq(s.resolvingCard,nil)
end
local function owner(s,mode)
 if mode=='native'then
  eq(s.actionQueue,nil,'no second action manager');eq(s.drainingCardActions,true)
  assert(type(s.cardActions)=='table');return s.cardActions
 end
 eq(s.cardActions,nil,'no second action manager');eq(s.drainingCardActions,nil)
 assert(type(s.actionQueue)=='table','reactive HP loss requires shared action owner')
 return s.actionQueue.actions
end
local function disposed(s,c)
 eq(s.cardInUse,nil);eq(#s.discard,1);eq(s.discard[1],c);clear(s)
end
for _,mode in ipairs({'native','stance','orb'})do
 test(mode..' real Bloodletting first-use Puzzle runs HP / TOP draw / energy / disposal',function()
  local s,c=battle(mode);local energy=s.energy;local trace={};local draws=0
  hooks({{H,'hpChanged',function(old)return function(state,actor,before)
   old(state,actor,before)
   if state==s and actor==s.player and before>actor.hp then
    eq(#s.hand,0,'draw cannot run in HP callback');eq(s.energy,energy)
    local actions=owner(s,mode);eq(actions[1].effect.op,'draw');eq(actions[1].effect.value,3)
    local tail=false;for i=2,#actions do if actions[i].effect and actions[i].effect.op=='energy'then tail=true end end
    assert(tail,'GainEnergy must remain a separate pending source action');trace[#trace+1]='hp'
   end
  end end},{C,'draw',function(old)return function(state,n)
   if state==s then
    owner(s,mode);eq(n,3);eq(s.energy,energy,'Puzzle draw before GainEnergy')
    eq(s.cardInUse,c);eq(#s.discard,0);draws=draws+1;trace[#trace+1]='draw'
   end;return old(state,n)
  end end},{C,'applyEffects',function(old)return function(state,effects,...)
   if state==s and effects[1].op=='energy'then
    eq(#effects,1);eq(draws,1);eq(s.cardInUse,c);eq(#s.discard,0);trace[#trace+1]='energy'
   end;return old(state,effects,...)
  end end}},function()assert(C.play(s,c.uid,1))end)
  eq(table.concat(trace,','),'hp,draw,energy');eq(s.player.hp,77);eq(s.energy,energy+2)
  eq(#s.hand,3);eq(#s.draw,3);assert(s.relicCombat.centennialUsed);disposed(s,c)
  Q.drain(C,s);clear(s);eq(#s.hand,3)
  local accepted,why=C.play(s,c.uid,1);eq(accepted,false);eq(why,'card_not_in_hand')
 end)
 for _,kind in ipairs({'no_relic','used_puzzle'})do
  test(mode..' '..kind..' preserves ordinary effectBatch fast path',function()
   local s,c=battle(mode,kind=='no_relic'and {}or nil)
   if kind=='used_puzzle'then s.relicCombat.centennialUsed=true end
   local batches,draws=0,0
   hooks({{C,'applyEffects',function(old)return function(state,effects,...)
    if state==s and #effects==2 and effects[1].op=='loseHp'and effects[2].op=='energy'then batches=batches+1 end
    return old(state,effects,...)
   end end},{C,'draw',function(old)return function(state,...)
    if state==s then draws=draws+1 end;return old(state,...)
   end end}},function()assert(C.play(s,c.uid,1))end)
   eq(batches,1,'unneeded boundary must not disable batching');eq(draws,0)
   eq(s.player.hp,77);eq(s.energy,5);disposed(s,c)
  end)
 end
 test(mode..' Rupture plus Puzzle retains both reactions and draw-before-energy',function()
  local s,c=battle(mode);A.applyPower(s,s.player,'rupture',1,s.player);local draws=0
  hooks({{C,'draw',function(old)return function(state,n)
   if state==s then owner(s,mode);eq(s.energy,3);draws=draws+1 end;return old(state,n)
  end end}},function()assert(C.play(s,c.uid,1))end)
  eq(draws,1);eq(s.player.statuses.strength,1);eq(s.energy,5);disposed(s,c)
 end)
 test(mode..' real HP payment bypasses Block; zero ABI HP loss cannot spend Puzzle',function()
  local s,c=battle(mode);s.player.block=50;assert(C.play(s,c.uid,1));eq(s.player.hp,77);eq(s.player.block,50)
  eq(#s.hand,3);disposed(s,c)
  s,c=battle(mode);s.catalog.cards.boundary_zero=C.copy(s.catalog.cards.bloodletting)
  s.catalog.cards.boundary_zero.id='boundary_zero';s.catalog.cards.boundary_zero.effects[1].value=0;c.cardId='boundary_zero'
  assert(C.play(s,c.uid,1));eq(s.player.hp,80);eq(#s.hand,0);eq(s.relicCombat.centennialUsed,nil)
  eq(s.energy,5);disposed(s,c)
 end)
 test(mode..' attack retaliation crosses same boundary; fully blocked retaliation does not trigger',function()
  for _,blocked in ipairs({false,true})do
   local s,c=battle(mode);s.catalog.cards.boundary_attack=C.copy(s.catalog.cards.strike)
   s.catalog.cards.boundary_attack.id='boundary_attack';s.catalog.cards.boundary_attack.cost=0
   s.catalog.cards.boundary_attack.effects={{op='damage',value=1},{op='energy',value=2}};c.cardId='boundary_attack'
   A.applyPower(s,s.enemies[1],'thorns',2,s.enemies[1]);s.player.block=blocked and 5 or 0
   local draws=0
   hooks({{C,'draw',function(old)return function(state,n)
    if state==s then owner(s,mode);eq(s.energy,3);draws=draws+1 end;return old(state,n)
   end end}},function()assert(C.play(s,c.uid,1))end)
   eq(draws,blocked and 0 or 1);eq(s.player.hp,blocked and 80 or 78)
   if blocked then eq(s.relicCombat.centennialUsed,nil)else eq(s.relicCombat.centennialUsed,true)end
   eq(s.energy,5);disposed(s,c)
  end
 end)
 test(mode..' lethal real Bloodletting stops energy/draw/disposal and clears both owners',function()
  local s,c=battle(mode);s.player.hp=3;A.applyPower(s,s.player,'rupture',1,s.player)
  assert(C.play(s,c.uid,1));eq(s.phase,'defeat');eq(s.player.hp,0);eq(s.energy,3)
  eq(#s.hand,0);eq(#s.draw,6);eq(#s.discard,0);eq(s.cardInUse,c);eq(s.player.statuses.strength,nil);clear(s)
  Q.drain(C,s);clear(s);eq(s.energy,3);eq(#s.draw,6);eq(#s.discard,0)
  local accepted=C.play(s,c.uid,1);eq(accepted,false)
 end)
 test(mode..' real Hemokinesis retains disposal after victory without repeating Puzzle',function()
  local s,c=battle(mode,nil,'hemokinesis');s.enemies[1].hp=1
  assert(C.play(s,c.uid,1));eq(s.phase,'victory');eq(s.player.hp,78);eq(#s.hand,3);eq(#s.draw,3);disposed(s,c)
  Q.drain(C,s);clear(s);eq(#s.hand,3);eq(#s.discard,1)
 end)
 for _,stage in ipairs({'hp','draw','energy','drained'})do
  test(mode..' original-table/RNG rollback after '..stage,function()
   local s,c=battle(mode);s.shuffleRng=require('abyss_sts_random').fromSeed('42')
   s.discard=s.draw;s.draw={};local check=unchanged(s);local injected=false
   local function fail()injected=true;error('boundary fault '..stage)end
   hooks({{H,'hpChanged',function(old)return function(state,actor,before)
    local result=old(state,actor,before);if stage=='hp'and state==s and actor==s.player and before>actor.hp then fail()end;return result
   end end},{C,'draw',function(old)return function(state,...)
    local result=old(state,...);if stage=='draw'and state==s then fail()end;return result
   end end},{C,'applyEffects',function(old)return function(state,effects,...)
    local result=old(state,effects,...)
    if stage=='energy'and state==s and effects[1].op=='energy'then fail()end;return result
   end end},{Q,'drain',function(old)return function(combat,state,...)
    local result=old(combat,state,...);if stage=='drained'and state==s and mode=='native'then fail()end;return result
   end end},{AQ,'run',function(old)return function(state,...)
    local result=old(state,...);if stage=='drained'and state==s and mode~='native'then fail()end;return result
   end end}},function()
    local ok,why=pcall(C.play,s,c.uid,1);assert(injected,'fault stage not reached')
    eq(ok,false);assert(tostring(why):find('boundary fault '..stage,1,true),tostring(why));check()
   end)
   assert(C.play(s,c.uid,1));eq(#s.hand,3);eq(s.energy,5);eq(s.discard[1],c);clear(s)
  end)
 end
end
print('HP_LOSS_ACTION_BOUNDARIES '..count..' passed='..(count-failed)..' failed='..failed)
assert(failed==0,'HP-loss source action boundaries failed')
