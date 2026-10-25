package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C=require('abyss_combat')
local Q=require('abyss_action_queue')
local T=require('abyss_warrior_status_cards')
local W=require('abyss_warrior_cards')
local E=require('abyss_warrior_exhaust_cards')
local S=require('abyss_warrior_strength_cards')
local base=S.withCards(E.withCards(W.withFoundationCards(require('abyss_data'))))
local function freezeSource(root)
 local saved={}
 local function visit(t)
  if saved[t] then return end
  local values={};saved[t]=values
  for k,v in pairs(t) do values[k]=v;if type(v)=='table' then visit(v) end end
 end
 visit(root)
 return function()
  for t,values in pairs(saved) do
   for k,v in pairs(values) do assert(t[k]==v,'source data mutated') end
   for k,v in pairs(t) do assert(values[k]==v,'source data mutated') end
  end
 end
end
local unchanged=freezeSource(base)
local data=T.withCards(base)
local n=0
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function test(name,fn) fn();n=n+1;print('ok warrior status '..n..' - '..name) end
local function inst(id,up) return {cardId=id,upgraded=up} end
local function held(s,id) for _,c in ipairs(s.hand) do if c.cardId==id then return c end end;error('missing '..id) end
local function play(s,id,target) local ok,why=C.play(s,held(s,id).uid,target);assert(ok,why) end
local function battle(deck,enemies)
 local s=C.new(data,{seed=42,deck=deck or {},enemies=enemies or {'cultist'},cardRandomSeed='42'})
 for _,e in ipairs(s.enemies) do e.hp=200;e.maxHp=200 end;return s
end
local function arrange(s,ids)
 local all={};for _,p in ipairs({s.hand,s.draw,s.discard,s.exhaust}) do for _,c in ipairs(p) do all[#all+1]=c end end
 s.hand={};s.draw={};s.discard={};s.exhaust={}
 for _,id in ipairs(ids) do
  local found;for i,c in ipairs(all) do if c.cardId==id then found=table.remove(all,i);break end end
  s.hand[#s.hand+1]=assert(found)
 end
 for _,c in ipairs(all) do s.draw[#s.draw+1]=c end
end
local function detach(s,id)
 local c=held(s,id);for i,v in ipairs(s.hand) do if v==c then table.remove(s.hand,i);break end end
 s.cardInUse=c;return c
end
test('independent definitions prepare twelve candidates and normalize shared status cards',function()
 local ids,powerIds={},{}
 for _,d in ipairs(base.cards.cards) do ids[d.id]=true end
 for _,d in ipairs(base.statuses.statuses) do powerIds[d.id]=true end
 local missingCards,missingPowers=0,0
 for _,id in ipairs({'wild_strike','reckless_charge','intimidate','immolate','limit_break','sever_soul','second_wind','fiend_fire','flame_barrier','evolve','fire_breathing','blood_for_blood','wound','dazed','burn'}) do
  if not ids[id] then missingCards=missingCards+1 end
 end
 for _,id in ipairs({'flame_barrier','evolve','fire_breathing'}) do if not powerIds[id] then missingPowers=missingPowers+1 end end
 eq(#data.cards.cards,#base.cards.cards+missingCards)
 eq(#data.statuses.statuses,#base.statuses.statuses+missingPowers);eq(base.experimentalWarriorStatus,nil)
 local seen={};for _,d in ipairs(data.statuses.statuses) do assert(not seen[d.id],d.id);seen[d.id]=true end
 unchanged()
 local count={};for _,c in ipairs(data.cards.cards) do count[c.id]=(count[c.id] or 0)+1 end
 eq(count.wound,1);eq(count.dazed,1);eq(count.burn,1);eq(count.wild_strike,1)
 eq(pcall(T.withCards,data),false)
end)
test('Second Wind prepares card Block once and plans all reversed exhausts before fixed blocks',function()
 local s=battle({'second_wind','strike','defend','sentinel','combust','wound'})
 arrange(s,{'second_wind','strike','defend','sentinel','combust','wound'});detach(s,'second_wind')
 s.player.statuses.dexterity=2;s.player.statuses.frail=1
 local e=T.prepareEffect(s,{op='secondWind',value=5});eq(e.fixedBlock,5)
 local p=T.planEffect(s,e);eq(#p.top,8);eq(#p.bottom,0)
 local ids={'wound','combust','sentinel','defend'}
 for i=1,4 do eq(p.top[i].effect.op,'exhaustHand');eq(p.top[i].effect.uid,held(s,ids[i]).uid) end
 for i=5,8 do eq(p.top[i].effect.op,'block');eq(p.top[i].effect.value,5);eq(p.top[i].effect.fixed,true) end
 Q.start(s,p.top);eq(s.actionQueue.actions[1],p.top[1]) -- Data-only validation, not fake rule execution.
end)
test('Fiend Fire plans an original hand-count number of random exhausts before identical NORMAL snapshots',function()
 local s=battle({'fiend_fire','strike','defend','sentinel'});detach(s,'fiend_fire');s.player.statuses.strength=2
 local e=T.prepareEffect(s,{op='fiendFire',value=7},s.enemies[1]);eq(e.normalAmount,9)
 local p=T.planEffect(s,e);eq(#p.top,6)
 for i=1,3 do eq(p.top[i].effect.op,'exhaustRandomAny') end
 for i=4,6 do eq(p.top[i].effect.op,'damage');eq(p.top[i].effect.normalAmount,9);eq(p.top[i].effect.targetId,s.enemies[1].id) end
end)
test('Fiend Fire one-card exhaustion still consumes random(0) via the real Exhaust dispatcher',function()
 local s=battle({'fiend_fire','strike'});detach(s,'fiend_fire');local strike=s.hand[1]
 Q.start(s,{});assert(T.exhaustRandomAny(s,Q));eq(s.cardRandomRng.counter,1)
 eq(s.exhaust[1],strike);eq(#s.hand,0);assert(Q.run(s,{}))
end)
test('Limit Break plans signed and zero Strength while absent Strength does nothing',function()
 local s=battle();eq(#T.planEffect(s,{op='limitBreak'}).top,0)
 for _,strength in ipairs({-2,0,3}) do
  s.player.statuses.strength=strength;local p=T.planEffect(s,{op='limitBreak'})
  eq(#p.top,1);eq(p.top[1].effect.value,strength)
 end
 s.player.statuses.strength=-2;s.player.statuses.artifact=1
 local p=T.planEffect(s,{op='limitBreak'});Q.start(s,p.top)
 assert(Q.run(s,{effect=function(state,a) C.applyEffects(state,{a.effect},state.player,state.player) end}))
 eq(s.player.statuses.strength,-2);eq(s.player.statuses.artifact,0)
end)
test('Evolve and Fire Breathing plans retain acquisition order and different status/curse/NoDraw gates',function()
 for _,first in ipairs({'evolve','fire_breathing'}) do
  local s=battle({'wound','regret'});local second=first=='evolve' and 'fire_breathing' or 'evolve'
  assert(T.applyPower(s,first,first=='evolve' and 1 or 6));assert(T.applyPower(s,second,second=='evolve' and 1 or 6))
  local p=T.onDraw(s,held(s,'wound'));eq(#p.bottom,2);eq(p.bottom[1].effect.op,first=='evolve' and 'draw' or 'statusFireDamage')
  eq(#T.onDraw(s,held(s,'regret')).bottom,1)
  s.player.noDraw=true;p=T.onDraw(s,held(s,'wound'));eq(#p.bottom,1);eq(p.bottom[1].effect.op,'statusFireDamage')
 end
end)
test('Flame Barrier plans NORMAL nonself owner retaliation regardless of HP damage and removes next start',function()
 local s=battle();assert(T.applyPower(s,'flame_barrier',4));local enemy=s.enemies[1]
 local p=T.onAttacked(s,enemy,'NORMAL');eq(#p.top,1);eq(p.top[1].effect.value,4)
 eq(#T.onAttacked(s,enemy,'THORNS').top,0);eq(#T.onAttacked(s,enemy,'HP_LOSS').top,0)
 eq(#T.onAttacked(s,s.player,'NORMAL').top,0);eq(#T.onAttacked(s,nil,'NORMAL').top,0)
 eq(T.planHook(s,'flame_barrier','turn_start').bottom[1].effect.op,'removeStatusPower')
end)
test('Blood for Blood damage notification excludes exhaust and cardInUse and counts hits rather than HP amount',function()
 local deck={};for _=1,5 do deck[#deck+1]='blood_for_blood' end
 local s=battle(deck);local a=s.hand
 s.hand={a[1]};s.draw={a[2]};s.discard={a[3]};s.exhaust={a[4]};s.cardInUse=a[5]
 assert(T.onHpLost(s,7));eq(s.player.damagedThisCombat,1)
 for i=1,3 do eq(a[i].combatCost,3);eq(a[i].turnCost,3) end
 eq(a[4].combatCost,nil);eq(a[5].combatCost,nil);eq(T.onHpLost(s,0),false)
 eq(s.player.damagedThisCombat,1)
end)
test('Blood for Blood creation modes and a zero-cost upgrade preserve source cost semantics',function()
 local s=battle({'blood_for_blood'});local source=held(s,'blood_for_blood');source.combatCost=2;source.turnCost=0
 s.player.damagedThisCombat=3
 local c={uid=900,cardId='blood_for_blood',upgraded=false};assert(T.created(s,c,'make_copy'));eq(c.combatCost,1)
 local d={uid=901,cardId='blood_for_blood',upgraded=false};assert(T.created(s,d,'stat_equivalent',source));eq(d.combatCost,2);eq(d.turnCost,0)
 source.combatCost=0;source.turnCost=1;assert(T.onUpgrade(s,source));eq(source.combatCost,0);eq(source.turnCost,0)
end)
print('WARRIOR_STATUS_COMPONENT_PASS'..n)
for _,id in ipairs({'wild_strike','reckless_charge'}) do
 test('real '..id..' deals source damage then inserts the right status with source RNG',function()
  for _,up in ipairs({false,true}) do
   local s=battle({inst(id,up),'defend'});arrange(s,{id});play(s,id,1)
   eq(s.enemies[1].hp,200-(id=='wild_strike' and (up and 17 or 12) or (up and 10 or 7)))
   eq(#s.draw,2);local found=0;for _,c in ipairs(s.draw) do if c.cardId==(id=='wild_strike' and 'wound' or 'dazed') then found=found+1 end end
   eq(found,1);eq(s.cardRandomRng.counter,1)
  end
 end)
end
test('real Wild Strike into an empty draw pile creates Wound without consuming insertion RNG',function()
 local s=battle({'wild_strike'});play(s,'wild_strike',1);eq(#s.draw,1);eq(s.draw[1].cardId,'wound');eq(s.cardRandomRng.counter,0)
end)
test('real Intimidate applies Weak independently through Artifact and exhausts',function()
 for _,up in ipairs({false,true}) do
  local s=battle({inst('intimidate',up)},{'cultist','cultist'});s.enemies[1].statuses.artifact=1;play(s,'intimidate')
  eq(s.enemies[1].statuses.weak or 0,0);eq(s.enemies[1].statuses.artifact,0)
  eq(s.enemies[2].statuses.weak,up and 2 or 1);eq(#s.exhaust,1);eq(s.energy,3)
 end
end)
test('real Immolate adds Burn after nonlethal damage and final-kill cleanup cancels that tail',function()
 for _,up in ipairs({false,true}) do
  local s=battle({inst('immolate',up)});play(s,'immolate');eq(s.enemies[1].hp,up and 172 or 179)
  eq(s.discard[1].cardId,'burn');eq(s.discard[2].cardId,'immolate')
  local final=battle({inst('immolate',up)});final.enemies[1].hp=1;play(final,'immolate')
  eq(final.phase,'victory');eq(#final.discard,1);eq(final.discard[1].cardId,'immolate')
 end
end)
test('real Limit Break doubles signed Strength and only the upgrade avoids self-exhaust',function()
 for _,up in ipairs({false,true}) do
  for _,str in ipairs({-2,3}) do
   local s=battle({inst('limit_break',up)});s.player.statuses.strength=str;play(s,'limit_break')
   eq(s.player.statuses.strength,str*2);eq(#s.exhaust,up and 0 or 1);eq(#s.discard,up and 1 or 0)
  end
 end
end)
test('real Sever Soul exhausts all nonattacks before its original NORMAL damage',function()
 for _,up in ipairs({false,true}) do
  local s=battle({inst('sever_soul',up),'strike','defend','dazed','evolve'})
  arrange(s,{'sever_soul','strike','defend','dazed','evolve'});play(s,'sever_soul',1)
  eq(s.enemies[1].hp,up and 178 or 184);eq(#s.exhaust,3);eq(#s.hand,1);eq(s.hand[1].cardId,'strike')
  eq(s.exhaust[1].cardId,'evolve');eq(s.exhaust[2].cardId,'dazed');eq(s.exhaust[3].cardId,'defend')
 end
end)
test('real Second Wind applies card Block modifiers once per nonattack and preserves Attack hand cards',function()
 for _,up in ipairs({false,true}) do
  local s=battle({inst('second_wind',up),'strike','defend','dazed','evolve'})
  s.player.statuses.dexterity=2;s.player.statuses.frail=1;play(s,'second_wind')
  eq(s.player.block,up and 18 or 15);eq(#s.exhaust,3);eq(#s.hand,1);eq(s.hand[1].cardId,'strike')
 end
end)
test('real Fiend Fire exhausts its whole other hand randomly and hits once per snapshot card',function()
 for _,up in ipairs({false,true}) do
  local s=battle({inst('fiend_fire',up),'strike','defend','sentinel'});play(s,'fiend_fire',1)
  eq(s.enemies[1].hp,up and 170 or 179);eq(#s.exhaust,4);eq(#s.hand,0)
  eq(s.cardRandomRng.counter,3);eq(s.energy,3);eq(s.exhaust[4].cardId,'fiend_fire')
 end
end)
test('real Flame Barrier retaliates through full Block and expires before the following player turn',function()
 for _,up in ipairs({false,true}) do
  local s=battle({inst('flame_barrier',up)});assert(C.endTurn(s));local hp=s.player.hp
  play(s,'flame_barrier');assert(C.endTurn(s));eq(s.player.hp,hp);eq(s.enemies[1].hp,up and 194 or 196)
  eq(s.player.statuses.flame_barrier or 0,0)
 end
end)
test('real Evolve and Fire Breathing draw tails run after the originating draw and disposal',function()
 for _,up in ipairs({false,true}) do
  local s=battle({inst('evolve',up),inst('fire_breathing',up),'shrug_it_off','dazed','strike'})
  arrange(s,{'evolve','fire_breathing','shrug_it_off'})
  for i,c in ipairs(s.draw) do if c.cardId=='dazed' then table.remove(s.draw,i);s.draw[#s.draw+1]=c;break end end
  play(s,'evolve');play(s,'fire_breathing');s.player.statuses.strength=20;play(s,'shrug_it_off')
  eq(s.enemies[1].hp,up and 190 or 194);eq(#s.hand,up and 3 or 2);eq(s.player.block,8)
 end
end)
for _,first in ipairs({'evolve','fire_breathing'}) do
 test('real status draw Power order controls whether extra draw survives the final kill with '..first..' first',function()
  local s=battle({'evolve','fire_breathing','shrug_it_off','dazed','strike'})
  arrange(s,{'evolve','fire_breathing','shrug_it_off'});s.enemies[1].hp=6
  for i,c in ipairs(s.draw) do if c.cardId=='dazed' then table.remove(s.draw,i);s.draw[#s.draw+1]=c;break end end
  play(s,first);play(s,first=='evolve' and 'fire_breathing' or 'evolve');play(s,'shrug_it_off')
  eq(s.phase,'victory');eq(#s.hand,first=='evolve' and 2 or 1)
 end)
end
test('real Blood for Blood drops one cost per positive enemy HP hit and pays the reduced upgrade cost',function()
 for _,up in ipairs({false,true}) do
  local s=battle({inst('blood_for_blood',up)});local c=held(s,'blood_for_blood')
  C.damage(s,s.enemies[1],s.player,3,true);C.damage(s,s.enemies[1],s.player,1,true)
  eq(C.cardDefinition(s,c).cost,up and 1 or 2);eq(s.player.damagedThisCombat,2)
  play(s,'blood_for_blood',1);eq(s.enemies[1].hp,up and 178 or 182);eq(s.energy,up and 2 or 1)
 end
end)
test('real fully blocked and zero enemy damage do not reduce Blood for Blood',function()
 local s=battle({'blood_for_blood'});local c=held(s,'blood_for_blood');s.player.block=10
 C.damage(s,s.enemies[1],s.player,3,true);C.damage(s,s.enemies[1],s.player,0,true)
 eq(s.player.hp,s.player.maxHp);eq(C.cardDefinition(s,c).cost,4);eq(s.player.damagedThisCombat or 0,0)
end)
for _,first in ipairs({'flame_barrier','thorns'}) do
 test('real Flame Barrier and potion Thorns retaliate in reverse TOP order with '..first..' acquired first',function()
  local s=battle({'flame_barrier'});assert(C.endTurn(s)) -- Cultist now has an actual attack intent.
  local bronze
  for _,potion in ipairs(data.potions.potions) do if potion.id=='liquid_bronze' then bronze=potion end end
  assert(bronze)
  local function thorns() assert(require('abyss_inventory').apply(s,bronze.effects)) end
  if first=='flame_barrier' then play(s,'flame_barrier');thorns() else thorns();play(s,'flame_barrier') end
  local start=#s.events+1;local hp=s.player.hp;assert(C.endTurn(s))
  local hits={}
  for i=start,#s.events do
   local event=s.events[i]
   if event.kind=='status_damage' and event.detail.source==s.player.id and event.detail.target==s.enemies[1].id then
    hits[#hits+1]=event.detail.amount
   end
  end
  eq(#hits,2);eq(hits[1],first=='flame_barrier' and 3 or 4);eq(hits[2],first=='flame_barrier' and 4 or 3)
  eq(s.player.hp,hp);eq(s.enemies[1].hp,193)
  eq(s.player.statuses.flame_barrier or 0,0);eq(s.player.statuses.thorns,3)
  for _,entry in ipairs(s.player.powerScheduleOrder) do assert(entry.id~='flame_barrier','removed Barrier must leave the source schedule') end
 end)
end
local function voidBattle(deck,hand)
 local mixed=T.withCards(require('abyss_defect_utility_cards').withCards(base))
 local s=C.new(mixed,{seed=42,deck=deck,enemies={'cultist'},cardRandomSeed='42'})
 s.enemies[1].hp=200;s.enemies[1].maxHp=200;arrange(s,hand);s.energy=3;return s
end
for _,first in ipairs({'evolve','fire_breathing'}) do
 test('real paused Warcry retains native disposal then Void energy then draw-Power acquisition order with '..first..' first',function()
  local s=voidBattle({'evolve','fire_breathing','warcry','void','strike','defend'},
   {'evolve','fire_breathing','warcry','strike','defend'})
  play(s,first);play(s,first=='evolve' and 'fire_breathing' or 'evolve')
  local warcry=held(s,'warcry');play(s,'warcry');local choice=assert(s.pendingHandChoice)
  eq(s.energy,1);eq(s.cardInUse,warcry) -- Void has been drawn; its queued energy loss has NOT executed.
  local useIndex
  for i,a in ipairs(s.actionQueue.actions) do if a.kind=='useCard' then useIndex=i;break end end
  assert(useIndex);eq(#s.actionQueue.actions,useIndex+3)
  local expected={'voidEnergy',first=='evolve' and 'draw' or 'statusFireDamage',first=='evolve' and 'statusFireDamage' or 'draw'}
  for i,op in ipairs(expected) do eq(s.actionQueue.actions[useIndex+i].effect.op,op) end
  assert(C.chooseHand(s,{held(s,'defend').uid},choice.token))
  eq(s.energy,0);eq(#s.hand,3);eq(s.enemies[1].hp,194);eq(s.exhaust[1],warcry)
  local fire
  for _,event in ipairs(s.events) do
   if event.kind=='damage' and event.detail.target==s.enemies[1].id then fire=event end
  end
  assert(fire);eq(fire.frame.energy,0);eq(fire.frame.exhaust[1].uid,warcry.uid)
  eq(#fire.frame.hand,first=='evolve' and 3 or 2)
 end)
end
test('real Battle Trance queues Void before both draw Powers then NoDraw blocks only the later Evolve draw',function()
 local s=voidBattle({'evolve','fire_breathing','battle_trance','void','strike','defend'},
  {'evolve','fire_breathing','battle_trance'})
 play(s,'evolve');play(s,'fire_breathing');local trace={};local push=Q.pushBottom
 -- Instrumentation records AFTER the real enqueue call. No rule handler,
 -- card callback, action result or execution order is replaced.
 Q.pushBottom=function(state,a)
  push(state,a)
  if state==s then trace[#trace+1]={op=a.effect and a.effect.op,noDraw=s.player.noDraw,energy=s.energy} end
 end
 local ok,why=pcall(play,s,'battle_trance');Q.pushBottom=push;assert(ok,why)
 eq(#trace,3);eq(trace[1].op,'voidEnergy');eq(trace[2].op,'draw');eq(trace[3].op,'statusFireDamage')
 for _,entry in ipairs(trace) do eq(entry.noDraw,false);eq(entry.energy,1) end
 eq(s.energy,0);eq(s.player.noDraw,true);eq(#s.hand,3);eq(#s.draw,0)
 eq(#s.discard,1);eq(s.discard[1].cardId,'battle_trance');eq(s.enemies[1].hp,194)
 local fire
 for _,event in ipairs(s.events) do if event.kind=='damage' and event.detail.target==s.enemies[1].id then fire=event end end
 assert(fire);eq(fire.frame.player.noDraw,true);eq(fire.frame.energy,0);eq(#fire.frame.hand,3)
 eq(fire.frame.discard[1].cardId,'battle_trance')
end)
print('WARRIOR_STATUS_BUILD_PASS'..n)
