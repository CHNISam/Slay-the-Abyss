-- Real production commands at controlled room boundaries, not a natural playthrough.
local C,Run,Map,Nodes=require('abyss_combat'),require('abyss_run'),require('abyss_map'),require('abyss_nodes')
local Data,Pool,R,Unknown=require('abyss_data'),require('abyss_event_pool'),require('abyss_sts_random'),require('abyss_unknown')
local Hooks=require('abyss_relic_hooks')
local base=Run.new(Data,'42',{experimental=true,campaign=true,campaignProfile='competition-two-act'})
local baseMap=Map.generate(base.data,'42',2)
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b)
 if a==b then return end;eq(type(a),type(b));if type(a)~='table'then eq(a,b);return end
 for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil,'missing '..tostring(k))end
end
local function snap(r)return C.copy(r,{[r.data]=r.data})end
local function fixture(options)
 options=options or {};local r=options.character and Run.new(Data,'42',{experimental=true,campaign=true,campaignProfile='full-source',character=options.character}) or snap(base)
 r.act,r.floor=2,17;r.unknown.pools=Pool.new('full',false,2)
 r.maxHp=options.maxHp or 80;r.hp=options.hp or r.maxHp
 if options.deck then r.deck=C.copy(options.deck);r.nextDeckUid=100 end
 if options.relics then r.relics=C.copy(options.relics)end
 local m=C.copy(baseMap);local n=Map.available(m)[1]
 for _,v in ipairs(m.nodes)do if v.id==n.id then v.type='event';v.eventId=not options.unentered and 'vampires' or nil end end
 if not options.unentered then local ok,why=Nodes.enter(r,m,n.id);assert(ok,why)end
 return r,m,n.id
end
local function reject(r,choice,uid,reason)
 local before=snap(r);local deck,flow,relics=r.deck,r.nodeFlow,r.relics
 local ok,why=Nodes.chooseEvent(r,choice,uid);eq(ok,false);if reason then eq(why,reason)end
 same(r,before);eq(r.deck,deck);eq(r.nodeFlow,flow);eq(r.relics,relics)
end
local count=0
local function test(name,fn)fn();count=count+1;print('PASS vampires '..count..' '..name)end

test('public event admission and cached health cost do not mutate detached views',function()
 for _,row in ipairs({{1,0},{2,1},{3,1},{50,16},{75,23},{80,24},{16777217,5033165},{2147483647,644245120}})do
  local r,m=fixture({maxHp=row[1]});local before=snap(r);local e=Nodes.view(r,m).node.event
  eq(e.hpLoss,row[2]);eq(#e.options,2);eq(e.options[1].choice,'accept');eq(e.options[2].choice,'leave')
  e.hpLoss=999;e.options[1].choice='bad';same(r,before)
 end
 eq(Pool.contentId.Vampires,'vampires')
end)
test('accept removes upgraded and bottled starter strikes only, reverse order then five fresh Bites',function()
 local r=fixture({deck={{uid=1,cardId='strike'},{uid=2,cardId='bash'},{uid=3,cardId='strike',upgraded=true},
  {uid=4,cardId='perfected_strike'},{uid=5,cardId='strike',inBottleFlame=true},{uid=6,cardId='defend'}}})
 local before=snap(r);assert(Nodes.chooseEvent(r,'accept'));eq(r.maxHp,56);eq(r.hp,56);eq(#r.deck,8)
 for i,uid in ipairs({2,4,6})do eq(r.deck[i].uid,uid)end
 same(r.nodeFlow.event.removedCardUids,{5,3,1})
 for i=4,8 do eq(r.deck[i].cardId,'bite');eq(r.deck[i].uid,96+i);assert(not r.deck[i].upgraded)end
 eq(r.nextDeckUid,105);eq(r.phase,'node');eq(r.nodeFlow.event.stage,'result')
 for _,key in ipairs({'eventRng','cardRng','miscRng','treasureRng','relicPool'})do same(r[key],before[key])end
 reject(r,'accept',nil,'invalid_event_choice');assert(Nodes.chooseEvent(r,'leave'));eq(r.phase,'map')
 reject(r,'leave',nil,'no_pending_node')
end)
test('zero starters and empty deck still receive exactly five; lower HP is not healed',function()
 for _,deck in ipairs({{},{{uid=1,cardId='bash'}}})do
  local r=fixture({deck=deck,hp=10});assert(Nodes.chooseEvent(r,'accept'));eq(r.hp,10);eq(r.maxHp,56);eq(#r.deck,#deck+5)
 end
 local r=fixture({maxHp=1,deck={}});assert(Nodes.chooseEvent(r,'accept'));eq(r.maxHp,1);eq(r.hp,1);eq(#r.deck,5)
end)
test('cached cost survives actual Fruit Juice and does not reprice on click',function()
 local r=fixture();r.potions={'fruit_juice'};assert(Run.usePotion(r,1));eq(r.maxHp,85)
 assert(Nodes.chooseEvent(r,'accept'));eq(r.maxHp,61);eq(r.hp,61);eq(r.nodeFlow.event.hpLoss,24)
end)
test('cached blood vial option removes only that relic with no health cost and retains order',function()
 local r,m=fixture({relics={'burning_blood','blood_vial','molten_egg'},hp=37})
 local e=Nodes.view(r,m).node.event;eq(#e.options,3);eq(e.options[2].choice,'give_vial');eq(e.options[3].choice,'leave')
 assert(Nodes.chooseEvent(r,'give_vial'));same(r.relics,{'burning_blood','molten_egg'});eq(r.hp,37);eq(r.maxHp,80)
 eq(r.nodeFlow.event.lostRelicId,'blood_vial')
 for _,card in ipairs(r.deck)do if card.cardId=='bite'then eq(card.upgraded,true);eq(card.upgrades,1)end end
 reject(r,'give_vial',nil,'invalid_event_choice')
end)
test('vial admission is cached but current ownership is checked; illegal payloads reject',function()
 local r=fixture();reject(r,'give_vial',nil,'event_condition_unmet');reject(r,'accept',7,'invalid_event_choice')
 r.relics[#r.relics+1]='blood_vial';reject(r,'give_vial',nil,'event_condition_unmet')
 local s=fixture({relics={'blood_vial'}});s.relics={};reject(s,'give_vial',nil,'event_condition_unmet')
end)
test('decline has a separate result page with unchanged resources and no extra reward',function()
 local r=fixture();local before=snap(r);assert(Nodes.chooseEvent(r,'leave'));eq(r.phase,'node');eq(r.nodeFlow.event.stage,'result')
 for _,key in ipairs({'deck','hp','maxHp','relics','eventRng','cardRng','miscRng','nextDeckUid'})do same(r[key],before[key])end
 reject(r,'accept',nil,'invalid_event_choice');assert(Nodes.chooseEvent(r,'leave'));eq(r.phase,'map')
end)
test('late fourth obtain refusal and exception roll back both cost choices, all removals, UIDs and RNG',function()
 for _,choice in ipairs({'accept','give_vial'})do for _,throws in ipairs({false,true})do
  local r=fixture({relics={'blood_vial','molten_egg'}});local original=Hooks.onObtainCard;local n=0
  Hooks.onObtainCard=function(staged,card,definition,api)
   n=n+1;local ok,why=original(staged,card,definition,api)
   if n==4 then if throws then error('vampires injected late obtain')end;return false,'vampires_late_refusal'end
   return ok,why
  end
  local ok,why=pcall(reject,r,choice);Hooks.onObtainCard=original;assert(ok,why)
  assert(Nodes.chooseEvent(r,choice));eq(r.nodeFlow.event.stage,'result')
 end end
end)
test('full unchanged source pool draws Vampires and consumes only original entry RNG',function()
 local r,m,id=fixture({unentered=true});local counter
 for n=0,127 do
  local nextRng=R.atCounter(r.eventSeed,n)
  if Unknown.advancePc(Unknown.newPc(),R.randomFloat(nextRng),{})=='event'then
   local chosen=Pool.draw(Pool.new('full',false,2),{floor=18,gold=r.gold,act=2,hp=80,relicCount=#r.relics,elapsedSeconds=0,cursed=false},R.atCounter(r.eventSeed,nextRng.counter))
   if chosen=='Vampires'then counter=n;break end
  end
 end
 assert(counter);r.eventRng=R.atCounter(r.eventSeed,counter);assert(Nodes.enter(r,m,id))
 eq(r.nodeFlow.event.originalId,'Vampires');eq(#r.unknown.pools.act,12);eq(r.eventRng.counter,counter+1)
 eq(r.nodeFlow.selectionRng.counter,counter+3);local before=snap(r)
 assert(Nodes.chooseEvent(r,'accept'));assert(Nodes.chooseEvent(r,'leave'));eq(r.phase,'map')
 for _,key in ipairs({'eventRng','cardRng','miscRng','treasureRng'})do same(r[key],before[key])end
end)
test('exchanged Bites function in the next real encounter and surrendered Blood Vial no longer heals',function()
 for _,choice in ipairs({'accept','give_vial'})do
  local r=fixture({relics={'blood_vial'},hp=20});assert(Nodes.chooseEvent(r,choice));assert(Nodes.chooseEvent(r,'leave'))
  local bites={};for _,card in ipairs(r.deck)do if card.cardId=='bite'then bites[#bites+1]=C.copy(card)end end
  r.deck=bites;r.floor=19;r.encounters=require('abyss_encounter_queue').new(r.runSeed,2)
  assert(Run.startRoomCombat(r,'normal'));local state=r.combat
  eq(state.player.hp,choice=='accept' and 22 or 20);eq(state.player.maxHp,choice=='accept' and 56 or 80)
  local uid;for _,card in ipairs(state.hand)do if card.cardId=='bite'then uid=card.uid;break end end;assert(uid)
  local hp=state.player.hp;assert(C.play(state,uid,1));eq(state.player.hp,hp+2)
 end
end)
test('existing four canonical source starter tags work while unresolved original tags reject atomically',function()
 for _,row in ipairs({{'ironclad',5},{'silent',5},{'defect',4},{'watcher',4}})do
  local r=fixture({character=row[1]});assert(Nodes.chooseEvent(r,'accept'));eq(#r.nodeFlow.event.removedCardUids,row[2])
  eq(#r.nodeFlow.event.obtainedCardUids,5)
 end
 local r=fixture({character='HT'});reject(r,'accept',nil,'starter_tags_unresolved')
 assert(Nodes.chooseEvent(r,'leave'));assert(Nodes.chooseEvent(r,'leave'));eq(r.phase,'map')
end)
print('VAMPIRES_EVENT '..count..' passed')
