-- Integration probe only: exact PR266 shared revive + PR267 Nest leaf/dispatch.
-- Controlled HP and next-map-node setup; no natural acquisition or platform claim.
local H=dofile('tests/helpers/act2_event_ui.lua')
local Run,Nodes,Hooks=H.Run,H.Nodes,H.Hooks
local eq,same=H.eq,H.same
local count=0
local function test(name,fn)fn();count=count+1;print('PASS Nest/Tail '..count..' '..name)end
local function nextNest(r,m)
 local nextNode=assert(H.Map.available(m)[1],'next controlled map node')
 for _,node in ipairs(m.nodes)do if node.id==nextNode.id then node.type,node.eventId='event','nest'end end
 assert(Nodes.enter(r,m,nextNode.id));eq(r.nodeFlow.event.id,'nest');eq(r.nodeFlow.event.stage,'intro')
end
local function ready(r)
 r.hp=1;assert(Nodes.chooseEvent(r,'continue'));eq(r.nodeFlow.event.stage,'choice')
end
local function daggerObserved(r,hp,counter)
 local on=Hooks.onObtainCard;local seen=false;local deckCount,uid=#r.deck,r.nextDeckUid
 Hooks.onObtainCard=function(staged,card,definition,api)
  seen=true;eq(staged.hp,hp);eq(staged.relicCounters.lizard_tail,counter)
  eq(#staged.deck,deckCount);eq(card.uid,uid);eq(card.cardId,'ritual_dagger')
  return on(staged,card,definition,api)
 end
 local caught,ok,why=pcall(Nodes.chooseEvent,r,'dagger');Hooks.onObtainCard=on
 assert(caught,ok);assert(ok,why);assert(seen,'real permanent acquire hook must run after revival')
 eq(r.hp,hp);eq(r.relicCounters.lizard_tail,counter);eq(#r.deck,deckCount+1)
 eq(r.deck[#r.deck].cardId,'ritual_dagger');eq(r.deck[#r.deck].uid,uid);eq(r.nextDeckUid,uid+1)
 eq(r.nodeFlow.event.hpLost,1);eq(r.nodeFlow.event.obtainedCardUid,uid)
 return why
end

test('real Nodes keeps first fatal Tail result then second fatal obtains before defeat',function()
 local r,m=H.fixture('nest');assert(Run.obtainRelic(r,'Lizard Tail'));eq(r.relicCounters.lizard_tail,-1)
 local firstUid=r.nextDeckUid
 ready(r);eq(daggerObserved(r,40,-2),'pending');eq(r.phase,'node');eq(r.nodeFlow.event.stage,'result')
 eq(r.nodeFlow.complete,false);assert(Nodes.chooseEvent(r,'leave'));eq(r.phase,'map')
 nextNest(r,m);ready(r);eq(daggerObserved(r,0,-2),'defeat');eq(r.phase,'defeat');eq(r.nodeFlow.complete,true)
 eq(r.deck[#r.deck-1].uid,firstUid);eq(r.deck[#r.deck].uid,firstUid+1)
 H.unchanged(r,m,function()return Nodes.chooseEvent(r,'leave')end)
end)

test('real Nodes consumes two physical Fairies before Tail and ignores retained battle owner',function()
 local r,m=H.fixture('nest');assert(Run.obtainRelic(r,'lizard_tail'))
 assert(Run.obtainPotion(r,'fairy_in_a_bottle'));assert(Run.obtainPotion(r,'fairy_in_a_bottle'))
 r.combat={player={hp=0,maxHp=999,block=999,statuses={intangible=1}},relics={'mark_of_bloom'},relicCounters={lizard_tail=-2},potionInventory={}}
 local old=H.Copy(r.combat)
 for pass=1,3 do
  if pass>1 then nextNest(r,m)end;ready(r)
  eq(daggerObserved(r,pass<3 and 24 or 40,pass<3 and -1 or -2),'pending');eq(r.phase,'node')
  eq(r.potions[1],nil);eq(r.potions[2],pass==1 and 'fairy_in_a_bottle' or nil);same(r.combat,old)
  assert(Nodes.chooseEvent(r,'leave'));eq(r.phase,'map')
 end
end)

test('Mark blocks every heal without consuming Tail or Fairy but fatal dagger remains permanent',function()
 for _,mark in ipairs({'mark_of_bloom','Mark of the Bloom'})do
  local r,m=H.fixture('nest');assert(Run.obtainRelic(r,'lizard_tail'));assert(Run.obtainRelic(r,mark))
  assert(Run.obtainPotion(r,'fairy_in_a_bottle'));ready(r)
  local heal,calls=Run.heal,0;Run.heal=function(...)calls=calls+1;return heal(...)end
  local caught,why=pcall(daggerObserved,r,0,-1);Run.heal=heal;assert(caught,why)
  eq(why,'defeat');eq(calls,0);eq(r.phase,'defeat');eq(r.nodeFlow.complete,true)
  eq(r.potions[1],'fairy_in_a_bottle');eq(r.relicCounters.lizard_tail,-1)
  H.unchanged(r,m,function()return Nodes.chooseEvent(r,'leave')end)
 end
end)

test('late obtain failure restores Tail charge health and owners before one successful retry',function()
 local r,m=H.fixture('nest');assert(Run.obtainRelic(r,'lizard_tail'));ready(r)
 local before=H.snapshot(r);local counters,deck,potions,flow=r.relicCounters,r.deck,r.potions,r.nodeFlow
 local on,seen=Hooks.onObtainCard,false
 Hooks.onObtainCard=function(staged)
  seen=true;eq(staged.hp,40);eq(staged.relicCounters.lizard_tail,-2);error('NEST_TAIL_LATE_OBTAIN_FAULT')
 end
 local caught,ok,why=pcall(Nodes.chooseEvent,r,'dagger');Hooks.onObtainCard=on
 assert(caught,ok);eq(ok,false);eq(why,'transaction_failed');assert(seen);same(r,before)
 eq(r.relicCounters,counters);eq(r.deck,deck);eq(r.potions,potions);eq(r.nodeFlow,flow)
 eq(daggerObserved(r,40,-2),'pending');eq(r.phase,'node');assert(Nodes.chooseEvent(r,'leave'));eq(r.phase,'map')
end)
print('NEST_TAIL_COMBINATION '..count..' passed; controlled offline only')
