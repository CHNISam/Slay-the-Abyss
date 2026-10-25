-- Pure construction and real services inside an explicit component queue host.
-- This does not assert that Combat has integrated the new phase composition.
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local P=require('abyss_turn_powers')
local S=require('abyss_power_schedule')
local C=require('abyss_combat')
local A=require('abyss_actor')
local O=require('abyss_orbs')
local Q=require('abyss_action_queue')
local Build=require('abyss_build_actions')
local M=require('abyss_mantra')
local n=0
local function eq(a,b,why)assert(a==b,(why or 'value')..': '..tostring(a)..' ~= '..tostring(b))end
local function test(name,fn)fn();n=n+1;print('ok turn_power_plans '..n..' - '..name)end
local data=require('abyss_silent').withFoundationCards(require('abyss_data'))
for _,spec in ipairs({{'abyss_warrior_cards','withFoundationCards'},{'abyss_warrior_strength_cards','withCards'},{'abyss_shivs','withInfiniteBladesDefinition'},
 {'abyss_defect_cards','withFoundationCards'},{'abyss_defect_utility_cards','withCards'},{'abyss_orb_powers','withCards'},{'abyss_mantra','withCards'},
 {'abyss_silent_attack_cards','withCardDefinitions'},{'abyss_warrior_status_cards','withCards'},
 {'abyss_watcher_attack_cards','withCards'},{'abyss_watcher_flow_cards','withCards'},
 {'abyss_silent_tactics_cards','withCardDefinitions'}})do data=require(spec[1])[spec[2]](data)end
-- Explicit fixed-source metadata for the old family definition until its owner
-- supplies priority20; this test fixture does not modify repository definitions.
for _,def in ipairs(data.statuses.statuses)do if def.id=='draw_next_turn'then def.priority=20 end end
local function state(deck)
 return C.new(data,{seed=42,cardRandomSeed='42',deck=deck or {},enemies={'cultist','jaw_worm','jaw_worm'},orbSlots=3,enableStances=true})
end
local function recorded(actor,id)
 for _,entry in ipairs(actor.powerScheduleOrder or {})do if entry.id==id then return entry end end
end
local function apply(s,id,amount,actor)
 actor=actor or s.player;local before=rawget(actor.statuses,id);local known=recorded(actor,id)
 assert(A.applyPower(s,actor,id,amount,s.player))
 if not (before==nil and not known and recorded(actor,id))then S.recordApplied(s,actor,id,before)end
end
local function append(out,items)for _,v in ipairs(items)do out[#out+1]=v end end
local function ops(items)
 local out={};for _,a in ipairs(items)do out[#out+1]=a.effect.op end;return table.concat(out,',')
end
local function remove(s,id)
 s.player.statuses[id]=nil;S.remove(s,s.player,id)
end
-- These are host handlers for the NEW data contract. Effects are executed by
-- real Actor/Combat/Orb/Mantra/generation services; no service is replaced.
local function execute(s,items)
 Q.start(s,items)
 assert(Q.run(s,{allow=function(current)return current.player.hp>0 end,effect=function(current,a,queue)
  local e=a.effect
  if e.op=='orbStart'then
   local action=C.copy(e.action)
   if action.targetId then
    for _,enemy in ipairs(current.enemies)do if enemy.id==action.targetId then action.target=enemy;break end end
    action.targetId=nil
   end
   O.resolve(current,action,C)
  elseif e.op=='makeTempCard'then Build.makeCard(current,e)
  elseif e.op=='removeStatus' or e.op=='removeStatusPower' or e.op=='removeFlowPower'then remove(current,e.status)
  elseif e.op=='reduceFlowPower'then current.player.statuses[e.status]=current.player.statuses[e.status]-e.value
  elseif e.op=='loseEnergy'then current.energy=math.max(0,current.energy-e.value)
  elseif e.op=='turnPoison'then
   for _,enemy in ipairs(current.enemies)do
    if enemy.id==e.targetId and A.isActive(enemy) then
     local value=rawget(enemy.statuses,'poison')~=nil and e.value or e.newPowerAmount
     A.applyPower(current,enemy,'poison',value,current.player)
    end
   end
  elseif e.op=='applyMantra'then assert(M.apply(current,e.value,queue))
  elseif e.op=='removeMantra'then M.remove(current)
  elseif e.op=='changeStance'then require('abyss_stances').change(current,e.stance)
  else C.applyEffects(current,{e},current.player)end
  return true
 end}))
end
local function noObjects(value,s,seen)
 if type(value)~='table'then assert(type(value)~='function');return end
 assert(value~=s and value~=s.player,'actor leaked into action')
 for _,enemy in ipairs(s.enemies)do assert(value~=enemy,'enemy leaked into action')end
 assert(getmetatable(value)==nil,'non-data action')
 seen=seen or {};assert(not seen[value],'action cycle');seen[value]=true
 for k,v in pairs(value)do noObjects(k,s,seen);noObjects(v,s,seen)end
 seen[value]=nil
end

test('pre Powers preserve actual acquisition order and ordinary Plasma comes last',function()
 local s=state();apply(s,'energy_down',1);apply(s,'berserk',2);apply(s,'next_turn_block',4)
 O.channel(s,'plasma',C);local before=s.energy;local plan=P.prepareStart(s)
 eq(ops(plan),'loseEnergy,energy,block,removeStatus,orbStart');eq(s.energy,before);eq(s.player.block,0)
 execute(s,plan);eq(s.energy,before+2);eq(s.player.block,4);eq(s.player.statuses.next_turn_block,nil)
end)
for _,first in ipairs({'bias','loop'})do
 test(first..' acquisition freezes old Focus for both Power slots before execution',function()
  local s=state();s.player.statuses.focus=3;require('abyss_focus').sync(s);O.channel(s,'frost',C)
  apply(s,first,1);apply(s,first=='bias' and 'loop' or 'bias',1)
  local plan=P.prepareStart(s);eq(#plan,2);eq(s.player.statuses.focus,3)
  local orb=plan[first=='bias' and 2 or 1].effect;eq(orb.op,'orbStart');eq(orb.action.amount,5)
  execute(s,plan);eq(s.player.statuses.focus,2);eq(s.player.block,5)
 end)
end

test('Loop Dark growth is synchronous while queued Bias loss has not applied',function()
 local s=state();s.player.statuses.focus=1;require('abyss_focus').sync(s);O.channel(s,'dark',C)
 apply(s,'bias',1);apply(s,'loop',2);local plan=P.prepareStart(s)
 eq(s.orbs.balls[1].stored,20);eq(s.player.statuses.focus,1);eq(ops(plan),'gainStatus')
 execute(s,plan);eq(s.player.statuses.focus,nil);eq(s.orbs.balls[1].stored,20)
end)

test('legacy orb order is reused without inventing a relation to other Powers',function()
 local s=state();s.player.statuses.bias=1;s.player.statuses.loop=1;s.orbPowerOrder={'loop','bias'};O.channel(s,'frost',C)
 local plan=P.prepareStart(s);eq(ops(plan),'orbStart,gainStatus');eq(s.player.powerScheduleOrder,nil)
 s.player.statuses.berserk=1;eq(pcall(P.prepareStart,s),false)
end)

test('unknown multiple pre-Power order rejects before Dark constructor growth',function()
 local s=state();s.player.statuses.bias=1;s.player.statuses.loop=1;O.channel(s,'dark',C)
 eq(pcall(P.prepareStart,s),false);eq(s.orbs.balls[1].stored,6)
end)

test('generated Shiv and Smite execute later with real Accuracy and overflow rules',function()
 local deck={};for i=1,10 do deck[i]='defend'end
 local s=state(deck);while #s.hand<9 do s.hand[#s.hand+1]=table.remove(s.draw)end
 apply(s,'accuracy',4);apply(s,'infinite_blades',2);apply(s,'battle_hymn',1)
 local plan=P.prepareStart(s);eq(#s.hand,9);eq(#s.discard,0);execute(s,plan)
 eq(#s.hand,10);eq(#s.discard,2);eq(s.hand[10].cardId,'shiv');eq(s.hand[10].shivAccuracyBonus,4)
 eq(s.discard[1].cardId,'shiv');eq(s.discard[2].cardId,'smite');eq(s.discard[2].upgraded,false)
end)

test('Energized is immediate but its removal waits behind the complete pre queue',function()
 local s=state();apply(s,'berserk',2);apply(s,'energy_down',1);apply(s,'loop',1);apply(s,'energized',1)
 O.channel(s,'plasma',C);local pre=P.prepareStart(s);s.energy=3
 local recharge=P.onEnergyRecharge(s);eq(s.energy,4);eq(s.player.statuses.energized,1)
 local all={};append(all,pre);append(all,recharge);execute(s,all)
 eq(s.energy,7);eq(s.player.statuses.energized,nil)
end)

test('Collect creates Miracle plus and removes before ordinary Draw tries a full hand',function()
 local deck={};for i=1,12 do deck[i]='defend'end
 local s=state(deck);while #s.hand<9 do s.hand[#s.hand+1]=table.remove(s.draw)end
 apply(s,'collect',1);local remaining=#s.draw;local plan=P.onEnergyRecharge(s)
 eq(#s.hand,9);plan[#plan+1]={kind='effect',effect={op='draw',value=1}};execute(s,plan)
 eq(#s.hand,10);eq(#s.draw,remaining);eq(s.hand[10].cardId,'miracle');eq(s.hand[10].upgraded,true);eq(s.player.statuses.collect,nil)
end)

test('Collect above one schedules reduction without changing amount at construction',function()
 local s=state();apply(s,'collect',2);local plan=P.onEnergyRecharge(s)
 eq(ops(plan),'makeTempCard,reduceFlowPower');eq(s.player.statuses.collect,2);execute(s,plan)
 eq(s.player.statuses.collect,1);eq(s.hand[1].upgraded,true)
end)

test('Devotion constructor count advances before ordinary Draw and Mantra applies after it',function()
 local s=state({'defend','defend','defend','defend','defend','defend'})
 for _,c in ipairs(s.hand)do s.draw[#s.draw+1]=c end;s.hand={}
 apply(s,'devotion',2);local post=P.preparePostDraw(s)
 eq(s.mantraGained,2);eq(s.player.statuses.mantra,nil);eq(#s.hand,0)
 local all={{kind='effect',effect={op='draw',value=1}}};append(all,post);execute(s,all)
 eq(s.player.statuses.mantra,2);local frame
 for _,event in ipairs(s.events)do if event.kind=='mantra'then frame=event.frame end end
 assert(frame);eq(#frame.hand,1)
end)

test('Devotion direct Divinity branch constructs no Mantra or constructor counter',function()
 local s=state();apply(s,'devotion',10);local count=s.mantraGained
 local post=P.preparePostDraw(s);eq(ops(post),'changeStance');eq(s.mantraGained,count);execute(s,post)
 eq(s.player.stance,'Divinity');eq(s.player.statuses.mantra,nil)
end)

test('Noxious freezes amount and target IDs before later application',function()
 local s=state();apply(s,'noxious_fumes',4);local post=P.preparePostDraw(s)
 eq(#post,3);eq(post[1].effect.targetId,s.enemies[1].id);eq(post[1].triggerPower,'noxious_fumes')
 apply(s,'noxious_fumes',95);s.enemies[2].hp=0;A.applyPower(s,s.enemies[1],'artifact',1,s.enemies[1])
 execute(s,post);eq(s.enemies[1].statuses.artifact,0);eq(s.enemies[1].statuses.poison,nil)
 eq(s.enemies[2].statuses.poison,nil);eq(s.enemies[3].statuses.poison,4)
end)

test('Noxious construction preserves raw stack amount and separately caps new Power',function()
 local s=state();apply(s,'noxious_fumes',10000);A.applyPower(s,s.enemies[1],'poison',1,s.player)
 local post=P.preparePostDraw(s);eq(post[1].effect.value,10000);eq(post[1].effect.newPowerAmount,9999)
 execute(s,post);eq(s.enemies[1].statuses.poison,10001);eq(s.enemies[2].statuses.poison,9999)
end)

test('zero Noxious still constructs debuffs and consumes real Artifact',function()
 local s=state();apply(s,'noxious_fumes',0);A.applyPower(s,s.enemies[1],'artifact',1,s.enemies[1])
 local post=P.preparePostDraw(s);eq(#post,3);eq(post[1].effect.value,0);execute(s,post)
 eq(s.enemies[1].statuses.artifact,0);eq(s.enemies[1].statuses.poison,nil);eq(s.enemies[2].statuses.poison,0)
end)
for _,id in ipairs({'draw_next_turn','draw_card_next_turn'})do
 test(id..' priority twenty follows later acquired default-priority Demon Form',function()
  local s=state({'defend','defend','defend','defend','defend','defend'})
  apply(s,id,2);apply(s,'demon_form',3);local post=P.preparePostDraw(s)
  eq(post[1].effect.op,'gainStatus');eq(post[1].effect.status,'strength');eq(post[2].effect.op,'draw')
  execute(s,post);eq(s.player.statuses.strength,3);eq(s.player.statuses[id],nil)
 end)
end

test('Brutality acquisition order and player death stop a later Demon Form application',function()
 local s=state();apply(s,'brutality',1);apply(s,'demon_form',3);s.player.hp=1
 execute(s,P.preparePostDraw(s));eq(s.player.hp,0);eq(s.player.statuses.strength,nil)
end)

test('zero pre members retain source unconditional actions without family zero shortcuts',function()
 local s=state()
 for _,id in ipairs({'berserk','flame_barrier','next_turn_block','battle_hymn','energy_down','wrath_next_turn','bias'})do apply(s,id,0)end
 local pre=P.prepareStart(s)
 eq(ops(pre),'energy,removeStatusPower,block,removeStatus,makeTempCard,loseEnergy,changeStance,removeFlowPower,gainStatus')
 execute(s,pre);eq(s.player.stance,'Wrath');eq(s.player.statuses.flame_barrier,nil);eq(s.player.statuses.next_turn_block,nil)
 eq(s.player.statuses.wrath_next_turn,nil);eq(s.player.statuses.focus,0)
end)

test('zero recharge keeps both Energized callbacks and Collect once then remove',function()
 local s=state();for _,id in ipairs({'energized','energized_blue','collect'})do apply(s,id,0)end
 local energy=s.energy;local plan=P.onEnergyRecharge(s)
 eq(ops(plan),'removeStatus,removeStatus,makeTempCard,removeFlowPower');eq(s.energy,energy)
 execute(s,plan);eq(s.player.statuses.energized,nil);eq(s.player.statuses.energized_blue,nil)
 eq(s.player.statuses.collect,nil);eq(s.hand[1].cardId,'miracle');eq(s.hand[1].upgraded,true)
end)

test('zero post members retain Draw LoseHP removal and Mantra construction',function()
 local s=state();for _,id in ipairs({'brutality','devotion','draw_next_turn','draw_card_next_turn'})do apply(s,id,0)end
 local post=P.preparePostDraw(s)
 eq(ops(post),'draw,loseHp,applyMantra,draw,removeStatus,draw,removeFlowPower');eq(s.mantraGained,0)
 execute(s,post);eq(s.player.statuses.mantra,0);eq(s.player.statuses.draw_next_turn,nil);eq(s.player.statuses.draw_card_next_turn,nil)
end)

test('negative values and multiple unknown order are refused without inventing source sentinel objects',function()
 local s=state();s.player.statuses.wrath_next_turn=-1;eq(pcall(P.prepareStart,s),false)
 local t=state();t.player.statuses.brutality=1;t.player.statuses.demon_form=2;eq(pcall(P.preparePostDraw,t),false)
end)

test('dead player or finished battle creates no actions or constructor mutations',function()
 local s=state();apply(s,'loop',1);apply(s,'devotion',2);O.channel(s,'dark',C);s.player.hp=0
 eq(#P.prepareStart(s),0);eq(#P.onEnergyRecharge(s),0);eq(#P.preparePostDraw(s),0)
 eq(s.orbs.balls[1].stored,6);eq(s.mantraGained,nil)
end)

test('combined plans are plain action data and never contain actor identities',function()
 local s=state();for _,id in ipairs({'loop','bias','battle_hymn','energized','collect','devotion','noxious_fumes'})do apply(s,id,1)end
 O.channel(s,'lightning',C);local all=P.prepareStart(s);append(all,P.onEnergyRecharge(s));append(all,P.preparePostDraw(s))
 noObjects(all,s);Q.start(s,all);eq(#s.actionQueue.actions,#all)
end)
test('one real data queue composes pre recharge tail normal Draw and post plans',function()
 local deck={};for i=1,12 do deck[i]='defend'end
 local s=state(deck);for _,c in ipairs(s.hand)do s.draw[#s.draw+1]=c end;s.hand={}
 apply(s,'energy_down',1);apply(s,'berserk',2);apply(s,'collect',1);apply(s,'energized',1)
 apply(s,'demon_form',3);apply(s,'devotion',2);apply(s,'brutality',1)
 local hp=s.player.hp;local pre=P.prepareStart(s);s.energy=3
 local recharge=P.onEnergyRecharge(s);local post=P.preparePostDraw(s)
 eq(s.energy,4);eq(s.mantraGained,2);eq(#s.hand,0);eq(s.player.statuses.strength,nil)
 local all={};append(all,pre);append(all,recharge)
 all[#all+1]={kind='effect',effect={op='draw',value=2}};append(all,post);execute(s,all)
 eq(s.energy,5);eq(#s.hand,4);eq(s.hand[1].cardId,'miracle');eq(s.hand[1].upgraded,true)
 eq(s.player.statuses.strength,3);eq(s.player.statuses.mantra,2);eq(s.player.hp,hp-1)
 eq(s.player.statuses.collect,nil);eq(s.player.statuses.energized,nil)
 local frame;for _,event in ipairs(s.events)do if event.kind=='mantra'then frame=event.frame end end
 assert(frame);eq(#frame.hand,3)
end)
print('TURN_POWER_PLANS_PASS '..n)
