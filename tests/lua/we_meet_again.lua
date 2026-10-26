package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,Run,Map,Nodes,R=require('abyss_combat'),require('abyss_run'),require('abyss_map'),require('abyss_nodes'),require('abyss_sts_random')
local Data=require('abyss_data')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b)eq(type(a),type(b));if type(a)~='table'then eq(a,b);return end;for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end end
local function fixture(mode)
 local r,m=Run.new(Data,42),Map.generate(Data,42)
 r.potions={[1]='blood_potion',[3]='fruit_juice'}
 r.deck={{uid=1,cardId='strike',upgraded=false},{uid=7,cardId='anger',upgraded=true,inBottleFlame=true},{uid=9,cardId='cleave',upgraded=false},{uid=5,cardId='doubt',upgraded=false}}
 if mode=='single'then r.gold=50;r.potions={[2]='blood_potion'};r.deck={{uid=9,cardId='cleave',upgraded=false}}
 elseif mode=='empty'then r.gold=49;r.potions={};r.deck={{uid=1,cardId='strike',upgraded=false},{uid=5,cardId='doubt',upgraded=false}}end
 if mode=='duplicates'then r.potions={[1]='blood_potion',[3]='blood_potion'} end
 if mode=='belt'then assert(Run.obtainRelic(r,'Potion Belt'));r.potions={[5]='blood_potion'} end
 local n=Map.available(m)[1];for _,v in ipairs(m.nodes)do if v.id==n.id then v.type='event';v.eventId='we_meet_again' end end
 local ok,why=Nodes.enter(r,m,n.id);assert(ok,why)
 r.relicPool.rng=R.restore({words={'0000000000000000','0000000000000000'},counter=0})
 local q=r.relicPool.queues.common;for i,v in ipairs(q)do if v=='Anchor'then table.remove(q,i);break end end;table.insert(q,1,'Anchor')
 return r,m
end
local count=0
local function test(name,fn)fn();count=count+1;print('PASS we-meet-again '..count..' '..name)end
test('constructor matches independent XS128 plus Java48 ordered potion gold card oracle',function()
 eq(require('abyss_event_pool').contentId.WeMeetAgain,'we_meet_again')
 local r,m=fixture();local e=r.nodeFlow.event;local s=R.snapshot(r.miscRng)
 eq(e.tradePotionSlot,3);eq(e.tradePotionId,'fruit_juice');eq(e.tradeGold,68);eq(e.tradeCardUid,7);eq(e.tradeCardId,'anger')
 eq(s.counter,3);eq(s.words[1],'502fba754a78ddb7');eq(s.words[2],'c4ee13b9edf4e0cf');eq(#Nodes.view(r,m).node.event.options,4);eq(r.shopRng,nil)
 r=fixture('single');e=r.nodeFlow.event;eq(e.tradePotionSlot,2);eq(e.tradeGold,50);eq(e.tradeCardUid,9);same(R.snapshot(r.miscRng),s)
end)
test('empty categories spend no misc and leave four source options with three disabled',function()
 eq(require('abyss_event_pool').isEligible('WeMeetAgain',{gold=0}),true)
 local r,m=fixture('empty');local e=r.nodeFlow.event;eq(e.tradePotionSlot,nil);eq(e.tradeGold,0);eq(e.tradeCardUid,nil)
 local s=R.snapshot(r.miscRng);eq(s.counter,0);eq(s.words[1],'203ea4c5049ad615');eq(s.words[2],'a9eeb425265e56a4')
 local options=Nodes.view(r,m).node.event.options;for i=1,3 do eq(options[i].enabled,false)end;eq(options[4].choice,'leave')
 local b=C.copy(r);eq(Nodes.chooseEvent(r,'trade_potion'),false);same(r,b);eq(Nodes.chooseEvent(r,'trade_gold'),false);same(r,b);eq(Nodes.chooseEvent(r,'trade_card'),false);same(r,b)
 assert(Nodes.chooseEvent(r,'leave'));eq(r.nodeFlow.event.stage,'result');same(r.miscRng,b.miscRng);assert(Nodes.chooseEvent(r,'leave'));eq(r.phase,'map')
end)
test('potion trade removes only constructor slot and obtains exactly one shared-queue relic',function()
 local r=fixture();local b=C.copy(r);assert(Nodes.chooseEvent(r,'trade_potion'))
 eq(r.potions[3],nil);eq(r.potions[1],'blood_potion');eq(r.gold,b.gold);same(r.deck,b.deck);same(r.miscRng,b.miscRng)
 eq(r.nodeFlow.event.obtainedRelicId,'anchor');eq(r.relicPool.rng.counter,b.relicPool.rng.counter+1);eq(r.nodeFlow.event.stage,'result')
 b=C.copy(r);eq(Nodes.chooseEvent(r,'trade_potion'),false);same(r,b)
end)
test('duplicate bottle IDs keep physical identity and expanded belts participate in constructor selection',function()
 local r=fixture('duplicates');eq(r.nodeFlow.event.tradePotionSlot,3);assert(Nodes.chooseEvent(r,'trade_potion'));eq(r.potions[1],'blood_potion');eq(r.potions[3],nil)
 r=fixture('belt');eq(r.nodeFlow.event.tradePotionSlot,5);assert(Nodes.chooseEvent(r,'trade_potion'));eq(r.potions[5],nil)
end)
test('gold and bottled nonbasic card are cached trades, never a random UID picker',function()
 local r=fixture();local b=C.copy(r);assert(Nodes.chooseEvent(r,'trade_gold'));eq(r.gold,31);same(r.deck,b.deck);same(r.potions,b.potions);same(r.miscRng,b.miscRng)
 r=fixture();b=C.copy(r);assert(Nodes.chooseEvent(r,'trade_card'));eq(#r.deck,#b.deck-1)
 for _,card in ipairs(r.deck)do assert(card.uid~=7)end;eq(r.gold,b.gold);same(r.potions,b.potions);same(r.miscRng,b.miscRng)
end)
test('missing relic rejects every offered payment with old owners and all streams unchanged',function()
 for _,choice in ipairs({'trade_potion','trade_gold','trade_card'})do
  local r=fixture();r.data=C.copy(r.data);for i=#r.data.relics.relics,1,-1 do if r.data.relics.relics[i].id=='anchor'then table.remove(r.data.relics.relics,i)end end
  local b=C.copy(r);local event,potions,deck,pool=r.nodeFlow.event,r.potions,r.deck,r.relicPool
  local ok,why=Nodes.chooseEvent(r,choice);eq(ok,false);eq(why,'relic_content_unavailable');same(r,b)
  eq(r.nodeFlow.event,event);eq(r.potions,potions);eq(r.deck,deck);eq(r.relicPool,pool)
 end
end)
test('room blocks public potion use and discard while internal offered trade remains legal',function()
 local r=fixture();r.potions[2]='entropic_brew';local b=C.copy(r)
 for slot=1,3 do local ok,why=Run.usePotion(r,slot);eq(ok,false);eq(why,'potion_event_restricted');same(r,b)
  ok,why=Run.discardPotion(r,slot);eq(ok,false);eq(why,'potion_event_restricted');same(r,b)
  local view=Run.potionView(r)[slot];eq(view.canUse,false);eq(view.canDiscard,false)
 end
 assert(Nodes.chooseEvent(r,'trade_potion'));eq(r.potions[3],nil)
end)
test('room restriction survives leaving for the map and clears on real next-room entry',function()
 local r,m=fixture();assert(Nodes.chooseEvent(r,'leave'));assert(Nodes.chooseEvent(r,'leave'));eq(r.phase,'map')
 eq(Run.discardPotion(r,1),false)
 local next=Map.available(m)[1];for _,n in ipairs(m.nodes)do if n.id==next.id then n.type='event';n.eventId='big_fish' end end
 assert(Nodes.enter(r,m,next.id));assert(Run.discardPotion(r,1));eq(r.potions[1],nil)
end)
print('WE_MEET_AGAIN '..count..' passed')
