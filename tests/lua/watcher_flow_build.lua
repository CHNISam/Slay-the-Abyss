package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Flow=require('abyss_watcher_flow_cards')
local C=require('abyss_combat')
local Data=require('abyss_data')
local Profiles=require('abyss_character_profiles')
local count=0
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function test(name,fn)fn();count=count+1;print('ok watcher_flow_build '..count..' - '..name)end
local function prepared()
 local data=Profiles.prepare(Data,'watcher')
 for _,card in ipairs(data.cards.cards)do if card.id=='battle_hymn' then return data end end
 return Flow.withCards(data)
end
local function battle(deck,enemies)
 local s=C.new(prepared(),{seed=42,cardRandomSeed='42',enableStances=true,deck=deck or {'through_violence'},enemies=enemies or {'cultist'}})
 for _,m in ipairs(s.enemies)do m.hp=1000;m.maxHp=1000 end
 return s
end
local function find(pile,id)for _,c in ipairs(pile)do if c.cardId==id then return c end end;error('missing '..id)end
local function play(s,id,target)local ok,why=C.play(s,find(s.hand,id).uid,target or 1);assert(ok,why)end
local function fixtureDraw(s)
 for i=#s.hand,1,-1 do if s.hand[i].cardId=='defend_purple'then s.draw[#s.draw+1]=table.remove(s.hand,i)end end
end
test('eighteen source cards preserve aliases costs upgrades and detached data',function()
 local d=prepared();local map={};for _,c in ipairs(d.cards.cards)do map[c.id]=c end
 for _,id in ipairs({'battle_hymn','collect','fasting','fear_no_evil','indignation','like_water','pray','reach_heaven','study','talk_to_the_hand','tantrum','simmering_fury','wallop','wheel_kick','wreath_of_flame','pressure_points','flurry_of_blows','weave'})do
  local c=assert(map[id]);assert(c.name:find('[\128-\255]')and c.text and c.upgradeText);eq(c.color,'purple')
 end
 eq(map.fasting.sourceId,'Fasting2');eq(map.simmering_fury.sourceId,'Vengeance');eq(map.pressure_points.sourceId,'PathToVictory')
 eq(map.collect.cost,-1);eq(map.collect.costMode,'all_energy');eq(map.collect.effects[1].value,0);eq(map.collect.upgrade.effects[1].value,1)
 eq(map.battle_hymn.upgrade.innate,true);eq(map.study.cost,2);eq(map.study.upgrade.cost,1)
 eq(map.tantrum.shuffleBackIntoDrawPile,true);eq(map.tantrum.effects[1].times,3);eq(map.tantrum.upgrade.effects[1].times,4)
 local tv=map.through_violence;eq(tv.cost,0);eq(tv.effects[1].value,20);eq(tv.upgrade.effects[1].value,30);eq(tv.selfRetain,true);eq(tv.exhaust,true)
 assert(not pcall(Flow.withCards,d));eq(Data.cards.cards[1].id,'strike')
end)
test('normal damage snapshots remain independent of later stance and Strength',function()
 local s=battle();s.player.statuses.strength=2;s.player.stance='Wrath'
 local effect=Flow.prepareEffect(s,{op='fearNoEvil',value=8},s.enemies[1]);eq(effect.normalAmount,20)
 s.player.statuses.strength=20;s.player.stance='Calm';eq(effect.normalAmount,20)
 assert(not pcall(Flow.prepareEffect,s,{op='wallop',value=math.huge},s.enemies[1]))
end)
test('Fear No Evil plans damage before Calm and Indignation uses BOTTOM',function()
 local s=battle(nil,{'cultist','cultist'});local target=s.enemies[1]
 target.intents={{effects={{op='damage',value=0}}}};target.intentIndex=1
 local p=Flow.planEffect(s,{op='fearNoEvil',value=8,normalAmount=8},{target=target})
 eq(#p.top,2);eq(p.top[1].op,'damage');eq(p.top[2].stance,'Calm')
 p=Flow.planEffect(s,{op='indignation',value=3});eq(#p.top,0);eq(p.bottom[1].stance,'Wrath')
 s.player.stance='Wrath';p=Flow.planEffect(s,{op='indignation',value=5});eq(#p.bottom,2);eq(p.bottom[2].targetId,s.enemies[2].id)
end)
test('Collect X snapshot upgrade free flag cap and Chemical X guard',function()
 local s=battle();s.energy=3
 local p=Flow.planEffect(s,{op='collect',value=0},{energyOnUse=2});eq(p.bottom[1].value,2);eq(p.consumeAllEnergy,true);eq(s.energy,3)
 p=Flow.planEffect(s,{op='collect',value=1},{energyOnUse=0});eq(p.bottom[1].value,1)
 p=Flow.planEffect(s,{op='collect',value=0},{energyOnUse=0});eq(#p.bottom,0);eq(p.consumeAllEnergy,false)
 p=Flow.planEffect(s,{op='collect',value=1},{energyOnUse=2000,freeToPlayOnce=true});eq(p.bottom[1].value,999);eq(p.consumeAllEnergy,false)
 assert(not pcall(Flow.planEffect,s,{op='collect',value=0},{chemicalX=true}))
end)
test('energy recharge Collect creates one upgraded Miracle before reducing duration',function()
 local s=battle();s.player.statuses.collect=3
 local p=Flow.planHook(s,'collect','energy_recharge');eq(#p.bottom,2)
 eq(p.bottom[1].cardId,'miracle');eq(p.bottom[1].value,1);eq(p.bottom[1].upgraded,true);eq(p.bottom[2].op,'reduceFlowPower')
 s.player.statuses.collect=1;eq(Flow.planHook(s,'collect','energy_recharge').bottom[2].op,'removeFlowPower')
end)
test('Battle Hymn Fasting and Simmering Fury hooks preserve pre and post draw stages',function()
 local s=battle();s.player.statuses.battle_hymn=2;s.player.statuses.energy_down=1
 s.player.statuses.wrath_next_turn=1;s.player.statuses.draw_card_next_turn=3
 local p=Flow.planHook(s,'battle_hymn','turn_start');eq(p.bottom[1].cardId,'smite');eq(p.bottom[1].value,2)
 eq(Flow.planHook(s,'energy_down','turn_start').bottom[1].op,'loseEnergy')
 p=Flow.planHook(s,'wrath_next_turn','turn_start');eq(p.bottom[1].stance,'Wrath');eq(p.bottom[2].op,'removeFlowPower')
 p=Flow.planHook(s,'draw_card_next_turn','turn_start_post_draw');eq(p.bottom[1].op,'draw');eq(p.bottom[1].value,3);eq(p.bottom[2].op,'removeFlowPower')
 eq(#Flow.planHook(s,'draw_card_next_turn','turn_start').bottom,0)
end)
test('Like Water before end cards is fixed Block while Study end turn inserts Insight',function()
 local s=battle();s.player.statuses.like_water=5;s.player.statuses.study=2;s.player.statuses.dexterity=99
 eq(#Flow.planHook(s,'like_water','turn_end_pre_cards').bottom,0)
 s.player.stance='Calm';local p=Flow.planHook(s,'like_water','turn_end_pre_cards');eq(p.bottom[1].value,5);eq(p.bottom[1].fixed,true)
 p=Flow.planHook(s,'study','turn_end');eq(p.bottom[1].cardId,'insight');eq(p.bottom[1].value,2);eq(p.bottom[1].randomSpot,true)
end)
test('Vigor applies only to NORMAL and attack cleanup is a separate BOTTOM action',function()
 local s=battle();s.player.statuses.vigor=5
 eq(Flow.damageBonus(s,s.player,'NORMAL'),5);eq(Flow.damageBonus(s,s.player,'THORNS'),0);eq(Flow.damageBonus(s,s.player,'HP_LOSS'),0)
 local p=Flow.planUseCard(s,{type='attack'});eq(p.bottom[1].status,'vigor');eq(s.player.statuses.vigor,5)
 eq(#Flow.planUseCard(s,{type='skill'}).bottom,0);eq(#Flow.planUseCard(s,{type='attack',dontTriggerOnUseCard=true}).bottom,0)
end)
test('Talk to the Hand queues fixed Block even for fully blocked zero damage',function()
 local s=battle();local target=s.enemies[1];target.statuses.block_return=2
 local p=Flow.planAttacked(s,target,{damageType='NORMAL',source=s.player,damage=0})
 eq(p.top[1].value,2);eq(p.top[1].fixed,true)
 eq(#Flow.planAttacked(s,target,{damageType='THORNS',source=s.player}).top,0)
 eq(#Flow.planAttacked(s,target,{damageType='NORMAL',source=target}).top,0)
end)
test('Pressure Points plans HP loss for all marked enemies after application',function()
 local s=battle(nil,{'cultist','cultist'});s.enemies[1].statuses.mark=8;s.enemies[2].statuses.mark=11
 local p=Flow.planEffect(s,{op='triggerMarks',value=1});eq(#p.bottom,2)
 eq(p.bottom[1].op,'markLoseHp');eq(p.bottom[1].targetId,s.enemies[1].id);eq(p.bottom[2].value,11)
end)
test('recall callbacks preserve discard order and skip empty Scry eligibility',function()
 local s=battle({'flurry_of_blows','weave','flurry_of_blows'})
 s.discard=s.hand;s.hand={};s.player.stance='Wrath'
 local expected={};for _,c in ipairs(s.discard)do if c.cardId=='flurry_of_blows'then expected[#expected+1]=c.uid end end
 local p=Flow.planStanceChange(s,'Calm','Wrath');eq(#p.bottom,2);eq(p.bottom[1].uid,expected[1]);eq(p.bottom[2].uid,expected[2])
 eq(#Flow.planStanceChange(s,'Wrath','Wrath').bottom,0)
 eq(#Flow.planScry(s,false).bottom,0);eq(#Flow.planScry(s,true).bottom,1)
 local weave=find(s.discard,'weave');p=Flow.planEffect(s,{op='recallFlowCard',uid=weave.uid})
 eq(p.move.from,'discard');eq(p.move.to,'hand');eq(p.move.handHook,false)
end)
test('queued recall leaves full hand unchanged and tolerates a prior return of same UID',function()
 local deck={'weave'};for _=1,10 do deck[#deck+1]='defend_purple'end
 local s=battle(deck);local all={}
 for _,pile in ipairs({s.hand,s.draw})do for _,c in ipairs(pile)do all[#all+1]=c end end
 s.hand={};s.draw={};s.discard={}
 for _,c in ipairs(all)do local pile=c.cardId=='weave' and s.discard or s.hand;pile[#pile+1]=c end
 local weave=s.discard[1];eq(#s.hand,10)
 eq(Flow.planEffect(s,{op='recallFlowCard',uid=weave.uid}).move,nil);eq(#s.discard,1)
 -- Simulate the first of duplicate queued source callbacks having returned it.
 s.draw[#s.draw+1]=table.remove(s.hand);s.hand[#s.hand+1]=table.remove(s.discard)
 eq(Flow.planEffect(s,{op='recallFlowCard',uid=weave.uid}).move,nil)
end)
test('Tantrum disposal returns original UID and exhaust takes priority',function()
 local s=battle({'tantrum'});local c=s.hand[1];local p=Flow.disposalPlan(s,c,false)
 eq(p.uid,c.uid);eq(p.copy,false);eq(p.randomSpot,true);eq(p.to,'draw')
 eq(Flow.disposalPlan(s,c,true),nil)
end)
test('power cap plan distinguishes Like Water first constructor from later stacking',function()
 local s=battle();local p=Flow.applicationPlan(s,s.player,'like_water',2000);eq(p.after,2000)
 s.player.statuses.like_water=2000;p=Flow.applicationPlan(s,s.player,'like_water',1);eq(p.incoming,1);eq(p.after,999)
 p=Flow.applicationPlan(s,s.player,'collect',2000);eq(p.after,999)
 s.player.statuses.wrath_next_turn=1;p=Flow.applicationPlan(s,s.player,'wrath_next_turn',1);eq(p.after,1);eq(p.sourceSentinel,true)
 assert(not pcall(Flow.applicationPlan,s,s.player,'invented',1))
end)
test('Wallop followup uses actual HP lost and fixed Block',function()
 eq(#Flow.planWallop(0).top,0);local p=Flow.planWallop(3);eq(p.top[1].value,3);eq(p.top[1].fixed,true)
 assert(not pcall(Flow.planWallop,-1))
end)
test('Through Violence real basic and upgrade retain and exhaust with zero cost',function()
 for _,up in ipairs({false,true})do
  local s=battle({{cardId='through_violence',upgraded=up}});local c=s.hand[1]
  assert(C.endTurn(s));eq(s.hand[1],c);play(s,'through_violence')
  eq(s.enemies[1].hp,1000-(up and 30 or 20));eq(s.energy,3);eq(s.exhaust[1],c)
 end
end)
test('Wheel Kick real damage precedes draw and upgrades damage only',function()
 for _,up in ipairs({false,true})do
  local s=battle({{cardId='wheel_kick',upgraded=up},'defend_purple','defend_purple'});fixtureDraw(s)
  play(s,'wheel_kick');eq(s.enemies[1].hp,1000-(up and 20 or 15));eq(#s.hand,2);eq(s.energy,1)
 end
end)
test('Reach Heaven real generation stays unupgraded and source random insertion',function()
 local s=battle({{cardId='reach_heaven',upgraded=true},'defend_purple'});fixtureDraw(s)
 local top=s.draw[#s.draw].uid;play(s,'reach_heaven');eq(s.enemies[1].hp,985)
 local tv=find(s.draw,'through_violence');eq(tv.upgraded,false);eq(s.draw[#s.draw].uid,top)
end)
test('Pray real Mantra uses existing construction count and then generates Insight',function()
 local s=battle({{cardId='pray',upgraded=true}});play(s,'pray')
 eq(s.mantraGained,4);eq(s.player.statuses.mantra,4);eq(find(s.draw,'insight').upgraded,false)
end)
-- These are intentionally real integration checks. A host missing the new
-- op/hook must fail visibly; no mock interpreter or silent feature skipping.
test('Fear No Evil real damage then Calm only against an attack intent',function()
 local s=battle({'fear_no_evil'});s.enemies[1].intents={{effects={{op='damage',value=1}}}};s.enemies[1].intentIndex=1
 s.player.stance='Wrath';play(s,'fear_no_evil');eq(s.enemies[1].hp,984);eq(s.player.stance,'Calm')
end)
test('Fasting real Artifact blocks Energy Down after Strength and Dexterity',function()
 local s=battle({'fasting'});s.player.statuses.artifact=1;play(s,'fasting')
 eq(s.player.statuses.strength,3);eq(s.player.statuses.dexterity,3);eq(s.player.statuses.artifact or 0,0);eq(s.player.statuses.energy_down,nil)
end)
test('Wallop real overkill keeps last-enemy Block and ignores Dexterity',function()
 local s=battle({'wallop'});s.player.statuses.dexterity=10;s.enemies[1].hp=3
 play(s,'wallop');eq(s.player.block,3);eq(s.phase,'victory')
end)
test('Wallop TOP Block protects against this attack lethal Thorns retaliation',function()
 local s=battle({'wallop'});s.player.hp=4;s.enemies[1].statuses.thorns=7
 play(s,'wallop');eq(s.player.hp,4);eq(s.player.block,2);eq(s.enemies[1].hp,991);eq(s.phase,'player')
 -- A fully blocked hit gives no Wallop Block and the same Thorns remains fatal.
 s=battle({'wallop'});s.player.hp=4;s.enemies[1].statuses.thorns=7;s.enemies[1].block=9
 play(s,'wallop');eq(s.player.hp,0);eq(s.phase,'defeat')
end)
test('Pressure Points real Mark bypasses Block on every marked target',function()
 local s=battle({'pressure_points'},{'cultist','cultist'});s.enemies[1].block=100;s.enemies[2].block=100;s.enemies[2].statuses.mark=11
 play(s,'pressure_points');eq(s.enemies[1].hp,992);eq(s.enemies[1].block,100);eq(s.enemies[2].hp,989)
end)
test('Cut Through Fate selects final Weave then draws it before idempotent queued recall',function()
 local s=battle({'cut_through_fate','weave'});local weave=find(s.hand,'weave')
 for i,c in ipairs(s.hand)do if c==weave then s.draw[#s.draw+1]=table.remove(s.hand,i);break end end
 local nextUid=s.nextUid;play(s,'cut_through_fate');local pending=assert(s.pendingScry)
 eq(#pending.candidateUids,1);eq(pending.candidateUids[1],weave.uid)
 assert(C.chooseScry(s,{weave.uid},pending.token))
 eq(s.nextUid,nextUid);eq(find(s.hand,'weave'),weave);eq(s.pendingScry,nil);eq(s.actionQueue,nil)
 local copies=0
 for _,pile in ipairs({s.hand,s.draw,s.discard,s.exhaust})do for _,c in ipairs(pile)do if c.uid==weave.uid then copies=copies+1;eq(c,weave)end end end
 eq(copies,1);eq(#s.hand,1);eq(#s.draw,0);eq(find(s.discard,'cut_through_fate').cardId,'cut_through_fate')
end)
test('Scry existing discard Weave returns after native draw and UseCard cleanup',function()
 local s=battle({'nirvana','cut_through_fate','weave','defend_purple'});play(s,'nirvana');local weave=find(s.hand,'weave')
 for i=#s.hand,1,-1 do
  if s.hand[i]==weave then s.discard[#s.discard+1]=table.remove(s.hand,i)
  elseif s.hand[i].cardId=='defend_purple'then s.draw[#s.draw+1]=table.remove(s.hand,i)end
 end
 play(s,'cut_through_fate');local pending=assert(s.pendingScry)
 local blockAt,recallAt
 for i,a in ipairs(assert(s.actionQueue).actions)do
  local e=a.effect or {}
  if e.op=='block' and e.value==3 and e.fixed then blockAt=i end
  if e.op=='recallFlowCard' and e.uid==weave.uid then recallAt=i end
 end
 assert(blockAt and recallAt and blockAt<recallAt,'open Scry must queue Power hook before Weave BOTTOM recall')
 assert(C.chooseScry(s,{},pending.token))
 eq(find(s.hand,'weave'),weave);eq(#s.hand,2);eq(#s.discard,1)
 eq(s.discard[1].cardId,'cut_through_fate')
 local blockEvent
 for _,event in ipairs(s.events)do if event.kind=='block' then blockEvent=event end end
 eq(s.player.block,3);assert(blockEvent)
 for _,c in ipairs(blockEvent.frame.hand)do assert(c.uid~=weave.uid,'Weave must return after Nirvana Block')end
end)
test('Tantrum real Vigor boosts every hit before removal and returns same instance',function()
 local s=battle({'wreath_of_flame','tantrum'});local original=find(s.hand,'tantrum');play(s,'wreath_of_flame');play(s,'tantrum')
 eq(s.enemies[1].hp,976);eq(s.player.stance,'Wrath');eq(s.player.statuses.vigor,nil);eq(find(s.draw,'tantrum'),original)
end)
test('production Vigor is shared once with its existing Chinese name while conflicts reject',function()
 local out=Profiles.prepare(Data,'watcher')
 local amount,name=0
 for _,s in ipairs(Data.statuses.statuses)do if s.id=='vigor'then name=s.name end end
 for _,s in ipairs(out.statuses.statuses)do if s.id=='vigor'then amount=amount+1;eq(s.name,name)end end
 eq(amount,1)
 local bad=C.copy(Data)
 for _,s in ipairs(bad.statuses.statuses)do if s.id=='vigor'then s.stack='duration'end end
 assert(not pcall(Profiles.prepare,bad,'watcher'),'incompatible shared Vigor accepted')
end)
print('watcher_flow_build: '..count..' passed')
