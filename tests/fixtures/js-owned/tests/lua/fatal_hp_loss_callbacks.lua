-- Independent source oracle, not the former known-gap characterization.
-- aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0:
-- AbstractPlayer.damage:1420-1474, RupturePower.wasHPLost:31-35,
-- CentennialPuzzle.wasHPLost:35-41, FairyPotion.use:32-39;
-- Bloodletting.use:25-27 / Hemokinesis.use:31-36. Community decompile,
-- not certified original-PC execution. Exact lethal costs avoid overkill claims.
-- Power then relic TOP insertion precedes Fairy; execution is Draw3, Strength2,
-- captured card tail, disposal. Bloom consumes Puzzle's trigger but executes none.
-- DeathScreen suspends the original manager; this test DOES NOT certify host
-- death queue retention equivalence or change its existing terminal policy.
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,A,H,Q,AQ,D,F,R=require('abyss_combat'),require('abyss_actor'),require('abyss_relic_hooks'),
 require('abyss_card_actions'),require('abyss_action_queue'),require('abyss_data'),
 require('abyss_potion_fairy'),require('abyss_sts_random')
local I=require('abyss_inventory')
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
local function battle(mode,id,bloom)
 local s=C.new(D,{seed=42,deck={},enemies={'cultist'},enableStances=mode=='shared',
  orbSlots=mode=='orb'and 0 or nil,orbRandomSeed=mode=='orb'and '42'or nil})
 H.bindBattle(s,bloom and {'centennial_puzzle','mark_of_bloom'}or {'centennial_puzzle'})
 A.applyPower(s,s.player,'rupture',2,s.player)
 local c=card(s,id or 'bloodletting');s.hand={c};s.draw={};s.discard={}
 for _=1,6 do s.draw[#s.draw+1]=card(s,'defend')end
 s.player.hp=id=='hemokinesis'and 2 or 3;s.player.maxHp=80
 s.enemies[1].hp=200;s.enemies[1].maxHp=200
 s.potionInventory={[1]='fairy_in_a_bottle',[3]='dexterity'};s.potionCapacity=3
 return s,c
end
local function clear(s)
 eq(s.cardActions,nil);eq(s.actionQueue,nil);eq(s.pendingPlay,nil);eq(s.pendingChoice,nil)
 eq(s.drainingCardActions,nil);eq(s.resolvingCard,nil)
end
local function queue(s,mode)
 if mode=='native'then eq(s.actionQueue,nil);return s.cardActions end
 eq(s.cardActions,nil);return s.actionQueue and s.actionQueue.actions
end
local function eventCount(s,kind)
 local n=0;for _,e in ipairs(s.events)do if e.kind==kind then n=n+1 end end;return n
end
for _,mode in ipairs({'native','shared','orb'})do
 for _,id in ipairs({'bloodletting','hemokinesis'})do
  for _,bloom in ipairs({false,true})do
   test(mode..' '..id..(bloom and ' Bloom' or ' Fairy')..' source oracle',function()
    local s,c=battle(mode,id,bloom);local inventory=s.potionInventory;local trace={}
    local beforeFairy,planned,drawStrength,tailStrength
    hooks({{Q,'enqueueReaction',function(old)return function(state,e,top)
     if state==s then
      eq(top,true);trace[#trace+1]=e.op=='draw'and 'planDraw'or 'planStrength'
     end;return old(state,e,top)
    end end},{F,'fatal',function(old)return function(state)
     if state==s then
      trace[#trace+1]='fairy';beforeFairy=s.relicCombat.centennialUsed
      local q=queue(s,mode);planned=q and q[1].effect.op..','..q[2].effect.op
     end;return old(state)
    end end},{C,'draw',function(old)return function(state,n)
     if state==s then
      eq(n,3);eq(s.cardInUse,c);eq(#s.discard,0);eq(s.energy,id=='bloodletting'and 3 or 2)
      drawStrength=s.player.statuses.strength or 0;trace[#trace+1]='draw'
     end;return old(state,n)
    end end},{A,'applyPower',function(old)return function(state,target,status,n,source,...)
     if state==s and status=='strength'then
      eq(n,2);eq(target,s.player);eq(source,s.player);eq(#s.hand,3);eq(s.cardInUse,c)
      trace[#trace+1]='strength'
     end;return old(state,target,status,n,source,...)
    end end},{C,'applyEffects',function(old)return function(state,effects,...)
     if state==s and (effects[1].op=='energy'or effects[1].op=='damage')then
      eq(#effects,1);eq(s.cardInUse,c);eq(#s.discard,0)
      tailStrength=s.player.statuses.strength;trace[#trace+1]='tail'
     end;return old(state,effects,...)
    end end}},function()assert(C.play(s,c.uid,1))end)
    eq(s.player.hp,bloom and 0 or 24);eq(s.potionInventory,inventory,'physical inventory owner')
    eq(inventory[1],bloom and 'fairy_in_a_bottle'or nil);eq(inventory[2],nil);eq(inventory[3],'dexterity')
    eq(s.relicCombat.centennialUsed,true,'Puzzle consumed by actual lethal loss')
    eq(beforeFairy,true,'relic callback precedes Fairy');eq(planned,'draw,gainStatus')
    eq(s.player.damagedThisCombat,1);eq(eventCount(s,'hp_loss'),1)
    eq(eventCount(s,'potion_revive'),bloom and 0 or 1)
    eq(s.enemies[1].hp,not bloom and id=='hemokinesis'and 185 or 200,'captured damage excludes new Strength')
    eq(s.energy,bloom and (id=='bloodletting'and 3 or 2)or (id=='bloodletting'and 5 or 2))
    eq(s.player.statuses.strength or 0,bloom and 0 or 2);eq(#s.hand,bloom and 0 or 3);eq(#s.draw,bloom and 6 or 3)
    eq(#s.discard,bloom and 0 or 1);eq(s.cardInUse,bloom and c or nil)
    if bloom then eq(s.phase,'defeat');eq(drawStrength,nil);eq(tailStrength,nil)
    else eq(s.discard[1],c);eq(drawStrength,0);eq(tailStrength,2)end
    eq(table.concat(trace,','),'planStrength,planDraw,fairy'..(bloom and ''or ',draw,strength,tail'))
    clear(s);local check=unchanged(s);Q.drain(C,s);Q.drain(C,s);check()
   end)
  end
 end
 for _,kind in ipairs({'null','enemy'})do
  test(mode..' '..kind..' owner lethal revival fires Puzzle but not Rupture',function()
   local s=battle(mode);s.player.hp=2;local inserted={}
   if mode~='native'then AQ.start(s,{})end
   hooks({{Q,'enqueueReaction',function(old)return function(state,e,top)
    if state==s then eq(top,true);inserted[#inserted+1]=e.op end;return old(state,e,top)
   end end}},function()
    if kind=='null'then s.player.statuses.poison=2;A.startTurnEffects(s,s.player)
    else A.damage(s,s.enemies[1],s.player,2,true)end
   end)
   eq(s.player.hp,24);eq(s.potionInventory[1],nil);eq(s.relicCombat.centennialUsed,true)
   eq(table.concat(inserted,','),'draw');eq(s.player.damagedThisCombat,1);eq(s.player.statuses.strength,nil)
   if mode=='native'then Q.drain(C,s)else AQ.run(s,{
    effect=function(state,item)C.applyEffects(state,{item.effect},state.player);return true end})end
   eq(#s.hand,4);eq(#s.draw,3);eq(s.player.statuses.strength,nil);clear(s)
  end)
 end
 test(mode..' Fairy loss discounts actual Blood for Blood cost exactly once',function()
  local s,c=battle(mode);local b=card(s,'blood_for_blood');s.hand[#s.hand+1]=b
  assert(C.play(s,c.uid,1));eq(s.player.damagedThisCombat,1)
  eq(b.costReduction,1);eq(b.combatCost,3);eq(b.turnCost,3);eq(C.cardDefinition(s,b).cost,3)
  eq(s.relicCombat.centennialUsed,true);eq(#s.hand,4);clear(s)
 end)
 test(mode..' heal-only hooks update Red Skull without consuming Puzzle',function()
  local s=battle(mode);H.bindBattle(s,{'centennial_puzzle','red_skull'});s.player.hp=20
  H.battleStart(s,'red_skull');eq(s.player.statuses.strength,3)
  local notified=0
  hooks({{H,'wasHpLost',function(old)return function(...)
   notified=notified+1;return old(...)
  end end}},function()
   if mode=='native'then Q.enqueue(s,{op='heal',value=30});Q.drain(C,s)
   else AQ.start(s,{{kind='effect',effect={op='heal',value=30}}});AQ.run(s,{
    effect=function(state,item)C.applyEffects(state,{item.effect},state.player);return true end})end
   eq(s.player.hp,50);eq(s.player.statuses.strength,0);eq(s.relicCombat.redSkullActive,false)
   assert(I.apply(s,{{op='increaseMaxHp',value=4}}));eq(s.player.hp,54);eq(s.player.maxHp,84)
   H.battleStart(s,'blood_vial');eq(s.player.hp,56)
   A.addStatus(s.player,'regen',2);A.endTurn(s,s.player);eq(s.player.hp,58)
  end)
  eq(notified,0);eq(s.relicCombat.centennialUsed,nil);eq(s.player.damagedThisCombat,nil)
  eq(s.potionInventory[1],'fairy_in_a_bottle');eq(eventCount(s,'hp_loss'),0);clear(s)
 end)
 for _,stage in ipairs({'fairy','draw'})do
  test(mode..' rollback after real '..stage..' then successful real retry',function()
   local s,c=battle(mode);s.shuffleRng=R.fromSeed('42');s.discard=s.draw;s.draw={}
   local oldNative,oldShared=s.cardActions,s.actionQueue
   local check=unchanged(s);local marker={stage=stage};local injected=false
   local function fail()
    eq(s.player.hp,24);eq(s.potionInventory[1],nil);eq(s.relicCombat.centennialUsed,true)
    assert(queue(s,mode),'existing owner must hold pending reactions/tail')
    injected=true;error(marker)
   end
   hooks({{F,'fatal',function(old)return function(state)
    local result=old(state);if state==s and stage=='fairy'then eq(result,true);fail()end;return result
   end end},{C,'draw',function(old)return function(state,...)
    local result=old(state,...);if state==s and stage=='draw'then
     eq(#s.hand,3);eq(s.shuffleRng.counter,1,'real reshuffle consumed its stream');fail()
    end;return result
   end end}},function()
    local ok,why=pcall(C.play,s,c.uid,1);eq(injected,true);eq(ok,false);eq(why,marker,'original error identity')
    check();eq(s.cardActions,oldNative);eq(s.actionQueue,oldShared)
   end)
   assert(C.play(s,c.uid,1));eq(s.player.hp,24);eq(s.potionInventory[1],nil)
   eq(s.relicCombat.centennialUsed,true);eq(s.player.damagedThisCombat,1);eq(s.player.statuses.strength,2)
   eq(s.shuffleRng.counter,1);eq(#s.hand,3);eq(s.energy,5);eq(s.cardInUse,nil);eq(s.discard[1],c);clear(s)
  end)
 end
end
-- The legacy Guardian disposal callback has no hpChanged call of its own.
-- Exercise its existing actual-loss notifier, without certifying its full queue order.
test('real Guardian Sharp Hide public play consumes Puzzle once, never Rupture',function()
 local s=C.new(D,{seed=42,deck={},enemies={'guardian'}})
 C.damage(s,s.player,s.enemies[1],30,true);assert(C.endTurn(s))
 eq(s.enemies[1].statuses.sharp_hide,3);eq(s.player.hp,80)
 H.bindBattle(s,{'centennial_puzzle'});A.applyPower(s,s.player,'rupture',2,s.player)
 local c=card(s,'strike');s.hand={c};s.draw={};s.discard={}
 for _=1,6 do s.draw[#s.draw+1]=card(s,'defend')end
 local draws=0
 hooks({{C,'draw',function(old)return function(state,n)
  if state==s then draws=draws+1;eq(n,3)end;return old(state,n)
 end end}},function()assert(C.play(s,c.uid,1))end)
 eq(s.player.hp,77);eq(s.player.damagedThisCombat,1);eq(s.relicCombat.centennialUsed,true)
 eq(s.player.statuses.strength,nil);eq(draws,1);eq(#s.hand,3);eq(#s.draw,3)
 eq(s.discard[1],c);eq(s.cardInUse,nil);clear(s)
end)
print('FATAL_HP_LOSS_CALLBACKS '..count..' passed='..(count-failed)..' failed='..failed)
assert(failed==0,'fatal HP-loss source oracle failed')
