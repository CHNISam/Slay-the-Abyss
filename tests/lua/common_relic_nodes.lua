package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,Nodes,Map,C,H,Pool,R=require('abyss_run'),require('abyss_nodes'),require('abyss_map'),require('abyss_combat'),require('abyss_relic_hooks'),require('abyss_card_pool'),require('abyss_sts_random')
local Data=require('abyss_data')
local passed,failed=0,0
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b)eq(type(a),type(b));if type(a)~='table'then eq(a,b);return end;for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil,'extra '..tostring(k))end end
local function test(name,fn)local ok,e=pcall(fn);if ok then passed=passed+1;print('PASS node relic '..name)else failed=failed+1;print('FAIL node relic '..name..': '..tostring(e))end end
local function fixture(kind,relics)
 local run,map=Run.new(Data,42),Map.generate(Data,42)
 for _,id in ipairs(relics or {})do assert(Run.obtainRelic(run,id))end
 local first=Map.available(map)[1];local node
 for _,v in ipairs(map.nodes)do if v.id==first.id then node=v end end
 node.type=kind;if kind=='event'then node.eventId='cleric'end
 return run,map,node
end
local function camp(relics)local r,m,n=fixture('camp',relics);assert(Nodes.enter(r,m,n.id));return r,m end
test('room Maw Bank precedes eligibility and actual shop Meal Ticket follows resolution',function()
 local r,m,n=fixture('event',{'MawBank'});r.gold=Data.rules.events.cleric.minGold-12
 assert(Nodes.enter(r,m,n.id));eq(r.gold,Data.rules.events.cleric.minGold)
 local s,sm,sn=fixture('shop',{'MawBank','MealTicket'});s.hp=10;local gold=s.gold
 assert(Nodes.enter(s,sm,sn.id));eq(s.hp,25);eq(s.gold,gold+12)
end)
test('unknown room resolved shop receives Meal Ticket exactly once',function()
 local r,m,n=fixture('event',{'MawBank','MealTicket'});n.eventId=nil;r.data.rules.events.encounterId=nil;r.hp=10
 local U=require('abyss_unknown');local old=U.advancePc;U.advancePc=function()return 'shop'end
 local gold=r.gold;local called,ok,why=pcall(Nodes.enter,r,m,n.id);U.advancePc=old
 assert(called and ok,tostring(why));eq(r.gold,gold+12);eq(r.hp,25);eq(r.nodeFlow.type,'shop')
end)
test('entry rejection retains external map resources and all mutable owners',function()
 local r,m,n=fixture('combat',{'MawBank','Ancient Tea Set'});r.relicCounters.ancient_tea_set=-2
 local before,bmap=C.copy(r),C.copy(m);local owner,deck,path=r.relicCounters,r.deck,m.path
 local original=Run.startRoomCombat;Run.startRoomCombat=function(s)s.relicCounters.ancient_tea_set=-1;s.gold=1;return false,'injected_setup_failure'end
 local called,ok,why=pcall(Nodes.enter,r,m,n.id);Run.startRoomCombat=original
 assert(called);eq(ok,false);eq(why,'injected_setup_failure');same(r,before);same(m,bmap);eq(r.relicCounters,owner);eq(r.deck,deck);eq(m.path,path)
end)
test('entry hook overflow cannot heal a shop visitor or advance the external map',function()
 local r,m,n=fixture('shop',{'MawBank','MealTicket'});r.gold=2147483647;r.hp=1
 local before,bmap=C.copy(r),C.copy(m);local owner,path=r.relicCounters,m.path
 eq(Nodes.enter(r,m,n.id),false);same(r,before);same(m,bmap);eq(r.relicCounters,owner);eq(m.path,path)
end)
test('camp charges Tea Set and combat setup publishes its consumed persistent counter',function()
 local r,m=camp({'Ancient Tea Set','MawBank'});eq(r.relicCounters.ancient_tea_set,-2);assert(Nodes.rest(r))
 local nextNode=Map.available(m)[1];for _,n in ipairs(m.nodes)do if n.id==nextNode.id then n.type='combat'end end
 local gold=r.gold;assert(Nodes.enter(r,m,nextNode.id));eq(r.combat.energy,5);eq(r.relicCounters.ancient_tea_set,-1);eq(r.combat.relicCounters.ancient_tea_set,-1);eq(r.combat.player.gold,gold+12)
end)
test('Regal Pillow adds fifteen to exact camp treatment shown by the node view',function()
 local r,m=camp({'Regal Pillow'});r.hp=10;local amount=math.floor(r.maxHp*Data.rules.camp.healPercent/100)+15
 eq(Nodes.view(r,m).node.heal,amount);assert(Nodes.rest(r));eq(r.hp,10+amount);eq(r.phase,'map');eq(r.nodeFlow.complete,true)
end)
test('Dream Catcher uses ordinary rarity context after an elite or boss without rewriting it',function()
 for _,tier in ipairs({'elite','boss'})do
  local r,m=camp({'Dream Catcher'});r.encounterTier=tier;r.hp=r.maxHp
  local expected,rng,offset=Pool.prepareRewards({data=r.data,cardRng=r.cardRng,cardRarityOffset=r.cardRarityOffset,encounterTier='normal'})
  assert(Nodes.rest(r));eq(r.phase,'node');eq(r.nodeFlow.complete,false);same(r.nodeFlow.restReward.cards,expected);same(r.cardRng,rng);eq(r.cardRarityOffset,offset);eq(r.encounterTier,tier)
  local before=C.copy(r);eq(Nodes.rest(r),false);same(r,before);eq(r.rewards,nil)
 end
end)
test('failed Dream Catcher generation rolls back healing camp choice and card owner',function()
 local r,m=camp({'Dream Catcher','Regal Pillow'});r.hp=10;local before=C.copy(r);local owner=r.cardRng
 local original=Pool.prepareRewards;Pool.prepareRewards=function(s)R.randomInt(s.cardRng,99);error('injected reward failure')end
 local called,ok=pcall(Nodes.rest,r);Pool.prepareRewards=original
 assert(called);eq(ok,false);same(r,before);eq(r.cardRng,owner)
end)
test('Dream Catcher choose or skip closes camp once and chosen card uses real obtain hooks',function()
 for _,choice in ipairs({0,1})do
  local r=camp({'Dream Catcher','CeramicFish'});r.hp=1;assert(Nodes.rest(r));local size,gold,uid=#r.deck,r.gold,r.nextDeckUid
  local before=C.copy(r);eq(Nodes.claimRestReward(r,4),false);same(r,before)
  local id=r.nodeFlow.restReward.cards[1];assert(Nodes.claimRestReward(r,choice));eq(r.phase,'map');eq(r.nodeFlow.complete,true)
  eq(#r.deck,size+(choice==1 and 1 or 0));eq(r.nextDeckUid,uid+(choice==1 and 1 or 0));eq(r.gold,gold+(choice==1 and 9 or 0))
  if choice==1 then eq(r.deck[#r.deck].cardId,id)end
  before=C.copy(r);eq(Nodes.claimRestReward(r,choice),false);same(r,before)
 end
end)
test('failed Dream Catcher acquisition leaves its original pending offer available',function()
 local r=camp({'Dream Catcher','CeramicFish'});assert(Nodes.rest(r));local before=C.copy(r);local owner=r.cardRng
 local original=H.onObtainCard;H.onObtainCard=function()error('injected acquire failure')end
 local called,ok=pcall(Nodes.claimRestReward,r,1);H.onObtainCard=original
 assert(called);eq(ok,false);same(r,before);eq(r.cardRng,owner);assert(Nodes.claimRestReward(r,1))
end)
local function native(hp)
 local F=dofile('tests/lua/support/game_ui_fixture.lua');local cursor={CursorEnter='enter',CursorExit='exit',CursorDown='down',CursorUp='up',CursorEndDrag='endDrag'}
 local host,root=F.fixture(nil,nil,nil,cursor);local r,m=camp({'Dream Catcher','Regal Pillow'})
 if hp then r.hp=hp end
 -- Bind the prepared real run exactly as GameUI.start binds its child owners.
 host.run,host.map=r,m;host.nodeUI.run,host.nodeUI.map=r,m;host.mapUI.map=m;host.battleUI.run=r;host:refresh()
 local panel=root:GetChild('nodePanel')
 local function get(path)local b=panel;for key in path:gmatch('[^/]+')do b=assert(b:GetChild(key),path)end;return b end
 local function emit(path,event,touch)local fn=get(path):GetChild('hit').listeners[event];if fn then return fn({touchId=touch})end end
 local function tap(path,touch)emit(path,'down',touch);emit(path,'up',touch);return emit(path,'click',touch)end
 return host,root,get,emit,tap
end
test('full-health Dream Catcher is usable in native camp and all three choices are real cards',function()
 local h,root,get,emit,tap=native();eq(h.mode,'node');eq(h.nodeUI.actions['campView/rest'].enabled,true)
 tap('campView/rest',1);eq(get('pickerView').visible,true);eq(h.run.phase,'node');eq(get('back/label').text,'跳过卡牌')
 for i=1,3 do eq(get('pickerView/card'..i).visible,true);assert(get('pickerView/card'..i..'/name').text~='')end
 local id=h.run.nodeFlow.restReward.cards[1];local size=#h.run.deck;tap('pickerView/card1',2);eq(get('pickerView/label').text,'将加入牌组');tap('confirm',3);eq(#h.run.deck,size+1);eq(h.run.deck[#h.run.deck].cardId,id)
 tap('confirm',4);eq(h.mode,'map');eq(get('pickerView').visible,false)
end)
test('native Regal Pillow treatment and Dream Catcher information fit the existing camp text',function()
 local h,root,get,emit,tap=native(10)
 eq(get('campView/rest/description').text,'回复 39 点生命\n生命 10 → 49\n捕梦网：可选一张牌')
 tap('campView/rest',1);eq(h.run.hp,49);eq(get('pickerView').visible,true)
end)
test('native skip and stale or duplicate rest clicks cannot claim twice',function()
 local h,root,get,emit,tap=native();local size=#h.run.deck
 emit('campView/rest','down',10);emit('campView/rest','up',10);emit('campView/rest','click',10)
 local before=C.copy(h.run);emit('campView/rest','click',10);same(h.run,before)
 emit('pickerView/card1','down',20);h.nodeUI:render();emit('pickerView/card1','up',20);emit('pickerView/card1','click',20);eq(h.nodeUI.selected,nil)
 tap('back',30);eq(h.run.phase,'map');eq(#h.run.deck,size);tap('confirm',31);eq(h.mode,'map')
 before=C.copy(h.run);emit('back','click',30);same(h.run,before)
end)
assert(failed==0,failed..' node relic tests failed');print('COMMON_RELIC_NODES '..passed..' passed')
