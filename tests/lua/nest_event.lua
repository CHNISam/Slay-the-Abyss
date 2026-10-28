local Nest=require('abyss_nest_event')
local Run,C,R=require('abyss_run'),require('abyss_combat'),require('abyss_sts_random')
local Data,Hooks=require('abyss_data'),require('abyss_relic_hooks')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b)
 if a==b then return end;eq(type(a),type(b))
 if type(a)~='table'then eq(a,b);return end
 for k,v in pairs(a)do same(v,b[k])end
 for k in pairs(b)do assert(a[k]~=nil,'unexpected '..tostring(k))end
end
local function snapshot(r)return C.copy(r,{[r.data]=r.data})end
local base=Run.new(Data,'42',{experimental=true,campaign=true})
local function fixture()
 local r=snapshot(base);r.phase,r.act,r.gold='node',2,100
 r.nodeFlow={type='event',event={id='nest'}};Nest.prepare(r,r.nodeFlow.event);return r
end
local function choose(r,choice,uid)
 return Run.transaction(r,function(staged)return Nest.choose(staged,staged.nodeFlow,choice,uid)end)
end
local function reject(r,choice,uid,reason)
 local before=snapshot(r);local owners={}
 for k,v in pairs(r)do if type(v)=='table'then owners[k]=v end end
 local event=r.nodeFlow.event;local ok,why=choose(r,choice,uid)
 eq(ok,false);eq(why,reason or 'invalid_event_choice');same(r,before)
 for k,v in pairs(owners)do eq(r[k],v)end;eq(r.nodeFlow.event,event)
end
local function ready(r)assert(choose(r,'continue'));eq(r.nodeFlow.event.stage,'choice')end
local count,failures=0,{}
local function test(name,fn)
 local ok,why=pcall(fn)
 if ok then count=count+1;print('PASS nest '..count..' '..name)
 else failures[#failures+1]=name..': '..tostring(why);print('FAIL '..failures[#failures])end
end

test('three screens keep intro inert and separate result Leave from the reward',function()
 local r=fixture();local before=snapshot(r);local e=r.nodeFlow.event
 eq(e.stage,'intro');local options=Nest.options(r,e);eq(#options,1);eq(options[1].choice,'continue')
 options[1].choice='gold';same(r,before)
 ready(r);eq(r.gold,100);eq(r.hp,80);eq(#r.deck,10);eq(r.nextDeckUid,11)
 local choices=Nest.options(r,r.nodeFlow.event);eq(#choices,2)
 eq(choices[1].choice,'gold');eq(choices[2].choice,'dagger');eq(choices[2].cardId,'ritual_dagger')
 for _,name in ipairs({'eventRng','miscRng','cardRng','treasureRng'})do same(r[name],before[name])end
 local ok,status=choose(r,'gold');assert(ok);eq(status,'pending');eq(r.nodeFlow.event.stage,'result');eq(r.phase,'node')
 eq(#Nest.options(r,r.nodeFlow.event),1);eq(Nest.options(r,r.nodeFlow.event)[1].choice,'leave')
 before=snapshot(r);ok,status=choose(r,'leave');assert(ok);eq(status,'complete');same(r,before)
end)
test('wrong stage malformed choices and any UID refuse without changing live owners',function()
 local r=fixture()
 for _,choice in ipairs({'gold','dagger','leave','',1,false,{}})do reject(r,choice)end;reject(r,nil)
 for _,uid in ipairs({0,11,'11',false,{}})do reject(r,'continue',uid)end
 ready(r);reject(r,'continue');reject(r,'leave');reject(r,'gold',11);reject(r,'dagger',11)
 assert(choose(r,'dagger'));reject(r,'dagger');reject(r,'gold');reject(r,'continue');reject(r,'leave',11)
 r.nodeFlow.event.stage='unknown';same(Nest.options(r,r.nodeFlow.event),{});reject(r,'leave')
end)
test('gold is exactly99 and uses permanent Ectoplasm rules without obtaining a card',function()
 for _,relics in ipairs({{}, {'ectoplasm'}, {'Ectoplasm'}, {'ceramic_fish'}})do
  local r=fixture();r.relics=relics;local before=snapshot(r);ready(r);assert(choose(r,'gold'))
  local blocked=relics[1]=='ectoplasm' or relics[1]=='Ectoplasm'
  eq(r.gold,blocked and 100 or 199);eq(r.nodeFlow.event.goldGained,blocked and 0 or 99)
  eq(r.hp,80);same(r.deck,before.deck);eq(r.nextDeckUid,11)
  for _,name in ipairs({'eventRng','miscRng','cardRng','treasureRng'})do same(r[name],before[name])end
  reject(r,'gold')
 end
 local r=fixture();ready(r);r.gold=2147483600;reject(r,'gold',nil,'transaction_failed')
 r=fixture();ready(r);local gain=Run.gainGold
 Run.gainGold=function(staged,value)gain(staged,value);R.randomInt(staged.miscRng,99);error('intentional Nest gold failure')end
 local ok,why=pcall(reject,r,'gold',nil,'transaction_failed');Run.gainGold=gain;assert(ok,why)
 assert(choose(r,'gold'));eq(r.gold,199);eq(r.miscRng.counter,0)
end)
test('fresh dagger preparation precedes damage and real obtain hooks see post-cost health and UID',function()
 local r=fixture();r.relics={'ceramic_fish','toxic_egg'};ready(r)
 local prepare,on=Run.prepareCard,Hooks.onObtainCard;local sequence={}
 Run.prepareCard=function(staged,id,options)
  sequence[#sequence+1]='prepare';eq(staged.hp,80);eq(id,'ritual_dagger');eq(options,nil)
  return prepare(staged,id,options)
 end
 Hooks.onObtainCard=function(staged,card,definition,api)
  sequence[#sequence+1]='obtain';eq(staged.hp,74);eq(#staged.deck,10);eq(card.uid,11)
  eq(card.cardId,'ritual_dagger');eq(card.upgraded,false)
  return on(staged,card,definition,api)
 end
 local ok,why=choose(r,'dagger');Run.prepareCard,Hooks.onObtainCard=prepare,on
 assert(ok,why);same(sequence,{'prepare','obtain'});eq(r.hp,74);eq(r.gold,109)
 eq(#r.deck,11);eq(r.nextDeckUid,12);eq(r.deck[11].uid,11);eq(r.deck[11].cardId,'ritual_dagger')
 eq(r.deck[11].upgraded,false);eq(r.nodeFlow.event.obtainedCardUid,11);eq(r.nodeFlow.event.hpLost,6)
 local definition;for _,d in ipairs(r.data.cards.cards)do if d.id=='ritual_dagger'then definition=d end end
 eq(definition.type,'attack');eq(definition.effects[1].damage,15)
end)
test('fatal damage and Fairy revival finish before the dagger is obtained',function()
 for _,spec in ipairs({{false,{},0},{true,{},24},{true,{'sacred_bark'},48},{true,{'mark_of_bloom'},0}})do
  local r=fixture();r.hp=1;r.relics=spec[2];if spec[1]then assert(Run.obtainPotion(r,'fairy_in_a_bottle'))end;ready(r)
  local on,seen=Hooks.onObtainCard,false
  Hooks.onObtainCard=function(staged,card,definition,api)
   seen=true;eq(staged.hp,spec[3]);return on(staged,card,definition,api)
  end
  local ok,why=choose(r,'dagger');Hooks.onObtainCard=on;assert(ok,why);assert(seen)
  eq(r.hp,spec[3]);eq(#r.deck,11);eq(r.nodeFlow.event.stage,'result');eq(r.nodeFlow.event.hpLost,1)
  eq(r.potions[1],spec[1] and spec[3]==0 and 'fairy_in_a_bottle' or nil)
 end
end)
test('NORMAL damage uses permanent Tungsten and ignores retained battle powers and health',function()
 local r=fixture();r.relics={'tungsten_rod'}
 r.combat={player={hp=1,maxHp=999,block=999,statuses={intangible=1}},relics={'mark_of_bloom'},potionInventory={}}
 local old=C.copy(r.combat);ready(r);assert(choose(r,'dagger'));eq(r.hp,75);eq(r.nodeFlow.event.hpLost,5);same(r.combat,old)
 -- The leaf must propagate a future/current shared NORMAL-damage refusal.
 r=fixture();ready(r);local damage=Run.eventNormalDamage
 Run.eventNormalDamage=function()return false,'event_damage_content_unavailable'end
 local ok,why=pcall(reject,r,'dagger',nil,'event_damage_content_unavailable');Run.eventNormalDamage=damage;assert(ok,why)
end)
test('missing card and invalid allocated UID refuse atomically and later valid retry obtains once',function()
 local r=fixture();ready(r);r.data=C.copy(r.data)
 for i=#r.data.cards.cards,1,-1 do if r.data.cards.cards[i].id=='ritual_dagger'then table.remove(r.data.cards.cards,i)end end
 reject(r,'dagger',nil,'card_content_unavailable');eq(r.hp,80)
 for _,uid in ipairs({0,1,1.5,'11'})do
  r=fixture();ready(r);r.nextDeckUid=uid;reject(r,'dagger',nil,'invalid_deck_uid')
  r.nextDeckUid=11;assert(choose(r,'dagger'));eq(r.hp,74);eq(#r.deck,11);eq(r.nextDeckUid,12)
 end
end)
test('late card hook failure rolls back damage Fairy slot gold and UID then retries successfully',function()
 local r=fixture();r.hp=1;r.relics={'ceramic_fish'};assert(Run.obtainPotion(r,'fairy_in_a_bottle'));ready(r)
 local on,observed=Hooks.onObtainCard
 Hooks.onObtainCard=function(staged,card,definition,api)
  local result,why=on(staged,card,definition,api)
  observed={hp=staged.hp,gold=staged.gold,potion=staged.potions[1]};R.randomInt(staged.miscRng,99)
  if result then error('intentional Nest acquire failure')end;return result,why
 end
 local ok,why=pcall(reject,r,'dagger',nil,'transaction_failed');Hooks.onObtainCard=on;assert(ok,why)
 same(observed,{hp=24,gold=109});assert(choose(r,'dagger'));eq(r.hp,24);eq(r.gold,109)
 eq(r.potions[1],nil);eq(#r.deck,11);eq(r.nextDeckUid,12);eq(r.miscRng.counter,0)
end)
test('forced missing attack-upgrade capability refuses dagger but never blocks gold',function()
 -- Private forced owners exercise an explicit implementation boundary, not a
 -- claim that the source event excludes Molten Egg or that it stays unsupported.
 for _,id in ipairs({'molten_egg','Molten Egg 2'})do
  local r=fixture();r.relics={id};ready(r);reject(r,'dagger',nil,'event_obtain_content_unavailable')
  assert(choose(r,'gold'));eq(r.gold,199)
 end
end)
test('four source classes acquire one distinct permanent UID without spending gameplay RNG',function()
 for _,character in ipairs({'ironclad','silent','defect','watcher'})do
  local r=Run.new(Data,'42',{experimental=true,campaign=true,character=character})
  r.phase,r.act='node',2;r.nodeFlow={type='event',event={id='nest'}};Nest.prepare(r,r.nodeFlow.event)
  local before=snapshot(r);local countBefore=#r.deck;ready(r);assert(choose(r,'dagger'))
  eq(#r.deck,countBefore+1);eq(r.deck[#r.deck].uid,before.nextDeckUid);eq(r.deck[#r.deck].cardId,'ritual_dagger')
  eq(r.hp,before.hp-6);eq(r.nextDeckUid,before.nextDeckUid+1)
  for _,name in ipairs({'eventRng','miscRng','cardRng','treasureRng'})do same(r[name],before[name])end
 end
end)
assert(#failures==0,table.concat(failures,'\n'))
print('NEST_EVENT '..count..' passed')
