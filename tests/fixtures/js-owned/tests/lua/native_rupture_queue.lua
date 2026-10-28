-- LOCAL queue-boundary regressions, not original-PC execution. Real native
-- Bloodletting/Hemokinesis definitions; explicitly staged Powers and piles.
-- aeubanks/sts@319009d5: Powers.wasHPLost precedes relics.wasHPLost;
-- Rupture and Puzzle each insert TOP actions, so Draw3 precedes Strength.
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
local function card(s,id,up)
 local c={cardId=id,uid=s.nextUid,upgraded=up or false};s.nextUid=s.nextUid+1;return c
end
local function battle(mode,id,up)
 local s=C.new(D,{seed=42,deck={},enemies={'cultist'},enableStances=mode=='shared',
  orbSlots=mode=='orb'and 0 or nil,orbRandomSeed=mode=='orb'and '42'or nil})
 H.bindBattle(s,{'centennial_puzzle'})
 A.applyPower(s,s.player,'rupture',2,s.player)
 A.applyPower(s,s.player,'artifact',2,s.player)
 local c=card(s,id or 'bloodletting',up);s.hand={c};s.draw={};s.discard={}
 for _=1,6 do s.draw[#s.draw+1]=card(s,'defend')end
 s.enemies[1].hp=200;s.enemies[1].maxHp=200
 return s,c
end
local function clear(s)
 eq(s.cardActions,nil);eq(s.actionQueue,nil);eq(s.pendingPlay,nil);eq(s.pendingChoice,nil)
 eq(s.drainingCardActions,nil);eq(s.resolvingCard,nil)
end
local function actions(s,mode)
 if mode=='native'then
  eq(s.actionQueue,nil,'no second action manager');eq(s.drainingCardActions,true)
  assert(type(s.cardActions)=='table');return s.cardActions
 end
 eq(s.cardActions,nil,'no second action manager');eq(s.drainingCardActions,nil)
 assert(type(s.actionQueue)=='table','shared owner required');return s.actionQueue.actions
end
local function disposed(s,c)
 eq(s.cardInUse,nil);eq(#s.discard,1);eq(s.discard[1],c);clear(s)
end
for _,mode in ipairs({'native','shared','orb'})do
 for _,id in ipairs({'bloodletting','hemokinesis'})do
  test(mode..' real '..id..' both upgrades insert Power then relic; drain Draw then Strength then tail',function()
   for _,up in ipairs({false,true})do
    local s,c=battle(mode,id,up);local d=C.cardDefinition(s,c);local trace,insertions={},{}
    local energy=s.energy-d.cost;local tail=id=='bloodletting'and 'energy'or 'damage'
    hooks({{Q,'enqueueReaction',function(old)return function(state,e,top)
     if state==s and mode=='native'and (e.op=='draw'or e.op=='gainStatus'and e.status=='strength')then
      eq(top,true);insertions[#insertions+1]=e.op
     end;return old(state,e,top)
    end end},{AQ,'pushTop',function(old)return function(state,item)
     if state==s and mode~='native'then insertions[#insertions+1]=item.effect.op end
     return old(state,item)
    end end},{H,'hpChanged',function(old)return function(state,actor,before)
     local result=old(state,actor,before)
     if state==s and actor==s.player and before>actor.hp then
      eq(s.player.statuses.strength,nil,'no synchronous Strength in HP callback')
      eq(#s.hand,0);eq(s.energy,energy);local q=actions(s,mode)
      eq(q[1].effect.op,'draw');eq(q[2].effect.op,'gainStatus');eq(q[2].effect.status,'strength')
      eq(q[2].effect.value,2);eq(q[2].effect.kind,nil,'native effect is not an action envelope')
      if mode=='native'then eq(q[2].source,s.player);eq(q[2].target,nil)end
      trace[#trace+1]='hp'
     end;return result
    end end},{C,'draw',function(old)return function(state,n)
     if state==s then
      actions(s,mode);eq(n,3);eq(s.player.statuses.strength,nil,'Puzzle precedes Rupture')
      eq(s.cardInUse,c);eq(#s.discard,0);eq(s.energy,energy);trace[#trace+1]='draw'
     end;return old(state,n)
    end end},{A,'applyPower',function(old)return function(state,target,status,n,source,...)
     if state==s and status=='strength'then
      eq(target,s.player);eq(source,s.player);eq(n,2);eq(s.cardInUse,c);eq(#s.discard,0)
      eq(#s.hand,3,'Rupture Power must run after Puzzle draw');eq(s.player.statuses.artifact,2);trace[#trace+1]='strength'
     end;return old(state,target,status,n,source,...)
    end end},{C,'applyEffects',function(old)return function(state,effects,...)
     if state==s and effects[1].op==tail then
      eq(s.player.statuses.strength,2);eq(#effects,1);trace[#trace+1]='tail'
     end;return old(state,effects,...)
    end end}},function()assert(C.play(s,c.uid,1))end)
    eq(table.concat(insertions,','),'gainStatus,draw','Power callback inserts before relic')
    eq(table.concat(trace,','),'hp,draw,strength,tail','reverse TOP order')
    eq(s.player.hp,80-d.effects[1].value);eq(s.player.statuses.strength,2);eq(s.player.statuses.artifact,2)
    eq(s.enemies[1].statuses.strength,nil);eq(s.enemies[1].hp,id=='hemokinesis'and 200-d.effects[2].value or 200)
    eq(s.energy,energy+(id=='bloodletting'and d.effects[2].value or 0));eq(s.player.damagedThisCombat,1)
    eq(s.relicCombat.centennialUsed,true);disposed(s,c)
    local check=unchanged(s);Q.drain(C,s);Q.drain(C,s);check()
   end
  end)
 end
 test(mode..' absent and already-used Puzzle still queue Rupture before the source tail',function()
  for _,kind in ipairs({'absent','used'})do
   local s,c=battle(mode);if kind=='absent'then H.bindBattle(s,{})else s.relicCombat.centennialUsed=true end
   local hp=false;local str=false
   hooks({{H,'hpChanged',function(old)return function(state,actor,before)
    old(state,actor,before);if state==s and actor==s.player and before>actor.hp then
     hp=true;eq(s.player.statuses.strength,nil);eq(actions(s,mode)[1].effect.op,'gainStatus')
    end
   end end},{A,'applyPower',function(old)return function(state,target,status,...)
    if state==s and status=='strength'then eq(hp,true);eq(s.energy,3);str=true end
    return old(state,target,status,...)
   end end}},function()assert(C.play(s,c.uid,1))end)
   eq(str,true);eq(s.player.statuses.strength,2);eq(#s.hand,0);eq(s.energy,5);disposed(s,c)
  end
 end)
 test(mode..' first-use Puzzle and HP-loss/BloodForBlood counters remain once per actual loss',function()
  local s,c=battle(mode);local b=card(s,'blood_for_blood');s.draw[#s.draw+1]=b
  assert(C.play(s,c.uid,1));eq(s.player.damagedThisCombat,1);eq(b.costReduction,1);eq(b.combatCost,3);eq(b.turnCost,3)
  local nextCard=card(s,'bloodletting');s.hand[#s.hand+1]=nextCard
  assert(C.play(s,nextCard.uid,1));eq(s.player.damagedThisCombat,2);eq(b.costReduction,2);eq(b.combatCost,2);eq(b.turnCost,2)
  eq(s.player.statuses.strength,4);eq(#s.hand,3);eq(s.relicCombat.centennialUsed,true);clear(s)
 end)
 test(mode..' actual zero/blocked/non-self/unknown-owner damage cannot queue Rupture',function()
  for _,kind in ipairs({'zero','blocked','enemy','unknown','nonplayer'})do
   local s=battle(mode);local n=kind=='zero'and 0 or 2
   if kind=='blocked'then s.player.block=9 end
   local target=kind=='nonplayer'and s.enemies[1]or s.player
   local source=s.player;if kind=='unknown'then source=nil elseif kind=='enemy'then source=s.enemies[1]end
   -- Explicit low-level ABI boundary: owner starts an existing action queue.
   if mode~='native'then AQ.start(s,{})end
   if kind=='unknown'then
    -- Poison's real status-tick callback explicitly has a null damage owner.
    target.statuses.poison=n;A.startTurnEffects(s,target)
   else A.damage(s,source,target,n)end
   eq(s.player.statuses.strength,nil)
   local q;if mode=='native'then q=s.cardActions else q=s.actionQueue.actions end
   for _,item in ipairs(q or {})do assert(item.effect.op~='gainStatus','ineligible Rupture')end
   local loss=target==s.player and kind~='zero'and kind~='blocked'
   eq(s.player.damagedThisCombat,loss and 1 or nil)
   eq(s.relicCombat.centennialUsed,loss and true or nil)
   if mode=='native'then Q.drain(C,s)else
    AQ.run(s,{effect=function(state,item)C.applyEffects(state,{item.effect},state.player);return true end})
   end
   eq(s.player.statuses.strength,nil);clear(s)
  end
 end)
 test(mode..' lethal real Bloodletting keeps limbo, cancels reactions/tails and cannot replay',function()
  local s,c=battle(mode);s.player.hp=3;assert(C.play(s,c.uid,1))
  eq(s.player.hp,0);eq(s.phase,'defeat');eq(s.player.statuses.strength,nil);eq(s.energy,3)
  eq(s.player.damagedThisCombat,1);eq(#s.hand,0);eq(#s.draw,6);eq(#s.discard,0);eq(s.cardInUse,c);clear(s)
  Q.drain(C,s);Q.drain(C,s);eq(s.cardInUse,c);eq(s.player.statuses.strength,nil);eq(s.energy,3)
  local check=unchanged(s);eq(C.play(s,c.uid,1),false);check()
 end)
 test(mode..' victory clears queued ApplyPower/Draw but keeps original disposal',function()
  local s,c=battle(mode,'hemokinesis');s.enemies[1].hp=1
  -- A real Puzzle draw can kill the final monster through Fire Breathing;
  -- Rupture ApplyPower is already pending, and is not retained after victory.
  require('abyss_warrior_status_cards').applyPower(s,'fire_breathing',6)
  s.draw={card(s,'burn')};assert(C.play(s,c.uid,1));eq(s.phase,'victory')
  eq(s.player.statuses.strength,2,'Rupture precedes BOTTOM on-draw fire')
  disposed(s,c);local check=unchanged(s);Q.drain(C,s);check()
  s,c=battle(mode);s.enemies[1].hp=0
  if mode~='native'then AQ.start(s,{})end
  require('abyss_hp_loss').notify(s,s.player,s.player,1)
  local q;if mode=='native'then q=s.cardActions else q=s.actionQueue.actions end
  eq(s.player.statuses.strength,nil,'ended combat must not mutate Strength synchronously');assert(q,'ApplyPower must be queued');eq(q[1].effect.op,'gainStatus')
  if mode=='native'then Q.drain(C,s)else
   AQ.run(s,{allow=function(state)return not C.outcome(state)end,
    effect=function()error('ended combat applied a Power')end})
  end
  eq(s.player.statuses.strength,nil);clear(s)
 end)
 for _,stage in ipairs({'queued','draw','strength','disposal'})do
  test(mode..' complete original-table/RNG rollback after '..stage,function()
   local s,c=battle(mode);s.shuffleRng=require('abyss_sts_random').fromSeed('42');s.discard=s.draw;s.draw={}
   local check=unchanged(s);local marker={stage=stage};local injected=false
   local function fail()injected=true;error(marker)end
   hooks({{H,'hpChanged',function(old)return function(state,actor,before)
    local result=old(state,actor,before);if state==s and actor==s.player and before>actor.hp and stage=='queued'then fail()end
    return result
   end end},{C,'draw',function(old)return function(state,...)
    local result=old(state,...);if state==s and stage=='draw'then fail()end;return result
   end end},{A,'applyPower',function(old)return function(state,target,status,...)
    local result=old(state,target,status,...);if state==s and status=='strength'and stage=='strength'then fail()end;return result
   end end},{C,'disposeCard',function(old)return function(state,...)
    local result=old(state,...);if state==s and stage=='disposal'then fail()end;return result
   end end},{AQ,'run',function(old)return function(state,...)
    local result=old(state,...);if state==s and mode~='native'and stage=='disposal'then fail()end;return result
   end end}},function()
    local ok,why=pcall(C.play,s,c.uid,1);eq(injected,true);eq(ok,false);eq(why,marker,'same error identity');check()
   end)
   assert(C.play(s,c.uid,1));eq(s.player.statuses.strength,2);eq(s.player.damagedThisCombat,1);eq(#s.hand,3);disposed(s,c)
  end)
 end
end
-- Explicit native continuation ABI: callbacks enqueue while a choice owns the
-- action boundary; neither nested nor repeated drains may resolve prematurely.
test('native pending choice and reentrant drain preserve exactly one queued Strength',function()
 local s=battle('native');local token={token=17,op='exhaustChoose'};s.pendingChoice=token
 A.damage(s,s.player,s.player,1);eq(s.player.statuses.strength,nil)
 eq(#s.cardActions,2);eq(s.cardActions[1].effect.op,'draw');eq(s.cardActions[2].effect.op,'gainStatus')
 local check=unchanged(s);Q.drain(C,s);eq(s.pendingChoice,token);check()
 s.pendingChoice=nil;local applied=0
 hooks({{A,'applyPower',function(old)return function(state,target,status,...)
  if state==s and status=='strength'then applied=applied+1;Q.drain(C,s);eq(applied,1)end
  return old(state,target,status,...)
 end end}},function()Q.drain(C,s)end)
 eq(applied,1);eq(s.player.statuses.strength,2);clear(s);Q.drain(C,s);eq(applied,1)
end)
for _,mode in ipairs({'shared','orb'})do
 test(mode..' paused existing owner retains callbacks until a single resume',function()
  local s=battle(mode);AQ.start(s,{})
  A.damage(s,s.player,s.player,1);eq(s.player.statuses.strength,nil)
  local q=s.actionQueue;eq(#q.actions,2);eq(q.actions[1].effect.op,'draw');eq(q.actions[2].effect.op,'gainStatus')
  -- Explicit shared continuation ABI, not a fabricated card definition.
  q.paused=true;q.current={kind='effect',effect={op='draw',value=0}};s.pendingScry={token=23}
  local check=unchanged(s);eq(AQ.run(s,{}),'pause');eq(AQ.run(s,{}),'pause');check()
  s.pendingScry=nil
  AQ.resume(s,{effect=function(state,item)
   if item.effect.op=='draw'then eq(s.player.statuses.strength,nil)else eq(#s.hand,4)end
   C.applyEffects(state,{item.effect},state.player);return true
  end})
  eq(s.player.statuses.strength,2);clear(s);check=unchanged(s);Q.drain(C,s);Q.drain(C,s);check()
 end)
end
print('NATIVE_RUPTURE_QUEUE '..count..' passed='..(count-failed)..' failed='..failed)
assert(failed==0,'native Rupture callback ordering failed')
