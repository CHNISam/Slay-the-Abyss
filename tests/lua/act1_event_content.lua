package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,Run,Map,Nodes,Pool=require('abyss_combat'),require('abyss_run'),require('abyss_map'),require('abyss_nodes'),require('abyss_event_pool')
local Data=require('abyss_data')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b)eq(type(a),type(b));if type(a)~='table'then eq(a,b);return end;for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end end
local function fixture(id,deck)
 local r,m=Run.new(Data,42),Map.generate(Data,42)
 if deck then r.deck=C.copy(deck)end
 local n=Map.available(m)[1];for _,v in ipairs(m.nodes)do if v.id==n.id then v.type='event';v.eventId=id end end
 assert(Nodes.enter(r,m,n.id));return r,m
end
local function frontRelic(r,id)
 local R=require('abyss_sts_random')
 r.relicPool.rng=R.restore({words={'0000000000000000','0000000000000000'},counter=0})
 local q=r.relicPool.queues.common
 for i,v in ipairs(q)do if v==id then table.remove(q,i);break end end
 table.insert(q,1,id)
end
local count=0
local function test(name,fn)fn();count=count+1;print('PASS act1 content '..count..' '..name)end
test('serpent maps full content and requires second confirmation before any gain',function()
 eq(Pool.contentId['Liars Game'],'sssserpent')
 local r,m=fixture('sssserpent');local before=C.copy(r)
 local options=Nodes.view(r,m).node.event.options;eq(#options,2);eq(options[1].choice,'agree');eq(options[2].choice,'disagree')
 assert(Nodes.chooseEvent(r,'agree'));eq(r.nodeFlow.event.stage,'agree');eq(r.phase,'node');eq(r.gold,before.gold);same(r.deck,before.deck);same(r.miscRng,before.miscRng)
 local saved=C.copy(r);eq(Nodes.chooseEvent(r,'agree'),false);same(r,saved);eq(Nodes.chooseEvent(r,'leave'),false);same(r,saved)
 eq(Nodes.view(r,m).node.event.options[1].choice,'confirm')
end)
test('serpent decline requires farewell, does not consume resources or RNG',function()
 local r,m=fixture('sssserpent');local b=C.copy(r)
 assert(Nodes.chooseEvent(r,'disagree'));eq(r.nodeFlow.event.stage,'disagree');eq(r.phase,'node');eq(#Nodes.view(r,m).node.event.options,1)
 assert(Nodes.chooseEvent(r,'leave'));eq(r.phase,'map');same(r.deck,b.deck);eq(r.gold,b.gold);same(r.miscRng,b.miscRng)
 b=C.copy(r);eq(Nodes.chooseEvent(r,'leave'),false);same(r,b)
end)
test('big fish keeps three source options and banana caches entry maxHP third',function()
 eq(Pool.contentId['Big Fish'],'big_fish')
 local r,m=fixture('big_fish');r.maxHp=82;r.hp=10
 local o=Nodes.view(r,m).node.event.options;eq(#o,3);eq(o[1].choice,'banana');eq(o[2].choice,'donut');eq(o[3].choice,'box')
 assert(Nodes.chooseEvent(r,'banana'));eq(r.hp,36);eq(r.nodeFlow.event.stage,'result');eq(r.phase,'node')
 assert(Nodes.chooseEvent(r,'leave'));eq(r.phase,'map')
end)
test('big fish donut increases max HP and current HP by five',function()
 local r=fixture('big_fish');r.hp=10;r.maxHp=80
 assert(Nodes.chooseEvent(r,'donut'));eq(r.hp,15);eq(r.maxHp,85)
 local saved=C.copy(r);eq(Nodes.chooseEvent(r,'donut'),false);same(r,saved)
end)
test('blacksmith forge commits option before mandatory picker and upgrades exact UID',function()
 eq(Pool.contentId['Accursed Blacksmith'],'accursed_blacksmith')
 local r,m=fixture('accursed_blacksmith',{{uid=7,cardId='strike',upgraded=false}})
 local o=Nodes.view(r,m).node.event.options;eq(#o,3);eq(o[1].choice,'forge');eq(o[2].choice,'rummage');eq(o[3].choice,'leave')
 assert(Nodes.chooseEvent(r,'forge'));eq(r.nodeFlow.event.stage,'choose_card');eq(r.nodeFlow.event.choice,'forge')
 local saved=C.copy(r);eq(Nodes.chooseEvent(r,'leave'),false);same(r,saved);eq(Nodes.chooseEvent(r,'forge',99),false);same(r,saved)
 assert(Nodes.chooseEvent(r,'forge',7));eq(r.deck[1].uid,7);eq(r.deck[1].upgraded,true);eq(r.nodeFlow.event.stage,'result');eq(r.phase,'node')
 assert(Nodes.chooseEvent(r,'leave'));eq(r.phase,'map')
end)
test('blacksmith no upgrades disables forge and leave retains source result screen',function()
 local r,m=fixture('accursed_blacksmith',{});eq(Nodes.view(r,m).node.event.options[1].enabled,false)
 local before=C.copy(r);eq(Nodes.chooseEvent(r,'forge'),false);same(r,before)
 assert(Nodes.chooseEvent(r,'leave'));eq(r.nodeFlow.event.stage,'result');eq(r.phase,'node');assert(Nodes.chooseEvent(r,'leave'));eq(r.phase,'map')
end)
test('bonfire has introduction and choose phases and empty purge result',function()
 eq(Pool.contentId['Bonfire Elementals'],'bonfire')
 local r,m=fixture('bonfire',{});eq(#Nodes.view(r,m).node.event.options,1);eq(Nodes.view(r,m).node.event.options[1].choice,'approach')
 assert(Nodes.chooseEvent(r,'approach'));eq(r.nodeFlow.event.stage,'choose');eq(Nodes.view(r,m).node.event.options[1].choice,'offer')
 assert(Nodes.chooseEvent(r,'offer'));eq(r.nodeFlow.event.stage,'result');eq(r.phase,'node');assert(Nodes.chooseEvent(r,'leave'));eq(r.phase,'map')
end)
test('serpent confirmation obtains one permanent Doubt and 175 gold with stable RNG',function()
 local r,m=fixture('sssserpent');assert(Nodes.chooseEvent(r,'agree'));local b=C.copy(r)
 assert(Nodes.chooseEvent(r,'confirm'));eq(r.gold,b.gold+175);eq(#r.deck,#b.deck+1);eq(r.deck[#r.deck].cardId,'doubt');eq(r.deck[#r.deck].uid,b.nextDeckUid)
 eq(r.nodeFlow.event.stage,'result');same(r.miscRng,b.miscRng);same(r.eventRng,b.eventRng)
 local saved=C.copy(r);eq(Nodes.chooseEvent(r,'confirm'),false);same(r,saved);assert(Nodes.chooseEvent(r,'leave'));eq(r.phase,'map')
end)
test('serpent invalid UID rolls back all resources and old object references',function()
 local r=fixture('sssserpent');assert(Nodes.chooseEvent(r,'agree'));r.nextDeckUid=r.deck[1].uid
 local b=C.copy(r);local deck,event=r.deck,r.nodeFlow.event;local ok,why=Nodes.chooseEvent(r,'confirm')
 eq(ok,false);eq(why,'invalid_deck_uid');same(r,b);eq(r.deck,deck);eq(r.nodeFlow.event,event)
end)
test('serpent old Omamori blocks curse once without spending a permanent UID',function()
 local r=fixture('sssserpent');assert(Run.obtainRelic(r,'Omamori'));assert(Nodes.chooseEvent(r,'agree'))
 r.nextDeckUid=r.deck[1].uid;local b=C.copy(r)
 assert(Nodes.chooseEvent(r,'confirm'));eq(r.gold,b.gold+175);same(r.deck,b.deck);eq(r.nextDeckUid,b.nextDeckUid)
 eq(r.relicCounters.omamori,1);eq(r.nodeFlow.event.curseBlocked,true);eq(r.nodeFlow.event.obtainedCardUid,nil)
 local saved=C.copy(r);eq(Nodes.chooseEvent(r,'confirm'),false);same(r,saved)
end)
test('bonfire rewards each card rarity then removes selected permanent UID',function()
 for _,v in ipairs({{'strike',10,80},{'anger',15,80},{'battle_trance',80,80},{'bludgeon',90,90}})do
  local r=fixture('bonfire',{{uid=7,cardId=v[1],upgraded=false}});r.hp=10;r.maxHp=80
  assert(Nodes.chooseEvent(r,'approach'));assert(Nodes.chooseEvent(r,'offer'));local rng=C.copy(r.miscRng)
  assert(Nodes.chooseEvent(r,'offer',7));eq(#r.deck,0);eq(r.hp,v[2]);eq(r.maxHp,v[3]);same(r.miscRng,rng);eq(r.nodeFlow.event.stage,'result')
 end
end)
test('big fish box uses complete shared queue and commits Regret and actual Anchor once',function()
 local r=fixture('big_fish');frontRelic(r,'Anchor');local b=C.copy(r)
 assert(Nodes.chooseEvent(r,'box'));eq(r.deck[#r.deck].cardId,'regret');eq(r.nodeFlow.event.obtainedRelicId,'anchor')
 eq(r.nodeFlow.event.relicOffer.sourceId,'Anchor');eq(r.nodeFlow.event.relicOffer.tier,'common');eq(#r.relicPool.queues.common,#b.relicPool.queues.common-1)
 eq(r.relicPool.rng.counter,b.relicPool.rng.counter+1);same(r.miscRng,b.miscRng);same(r.eventRng,b.eventRng)
 local after=C.copy(r);eq(Nodes.chooseEvent(r,'box'),false);same(r,after)
end)
test('big fish newly equipped Omamori does not block curse prepared before the relic',function()
 local r=fixture('big_fish');frontRelic(r,'Omamori')
 assert(Nodes.chooseEvent(r,'box'));eq(r.nodeFlow.event.obtainedRelicId,'omamori');eq(r.deck[#r.deck].cardId,'regret');eq(r.relicCounters.omamori,2)
end)
test('big fish card resolve dispatches the newly acquired Ceramic Fish hook',function()
 local r=fixture('big_fish');frontRelic(r,'CeramicFish');local gold=r.gold
 assert(Nodes.chooseEvent(r,'box'));eq(r.nodeFlow.event.obtainedRelicId,'ceramic_fish');eq(r.gold,gold+9);eq(r.deck[#r.deck].cardId,'regret')
end)
test('blacksmith missing original Tongs rolls back already prepared old Omamori',function()
 local r=fixture('accursed_blacksmith');assert(Run.obtainRelic(r,'Omamori'));r.data=C.copy(r.data)
 for i=#r.data.relics.relics,1,-1 do local d=r.data.relics.relics[i];if d.sourceId=='WarpedTongs' or d.id=='warped_tongs' then table.remove(r.data.relics.relics,i)end end
 local before=C.copy(r);local deck=r.deck;local ok,why=Nodes.chooseEvent(r,'rummage')
 eq(ok,false);eq(why,'relic_content_unavailable');same(r,before);eq(r.deck,deck);eq(r.relicCounters.omamori,2)
end)
test('big fish missing original relic refuses whole box without reroll, UID, queue or RNG mutation',function()
 local r=fixture('big_fish');frontRelic(r,'Boot');r.data=C.copy(r.data)
 for i=#r.data.relics.relics,1,-1 do local d=r.data.relics.relics[i];if d.sourceId=='Boot' or d.id=='boot' then table.remove(r.data.relics.relics,i)end end
 local b=C.copy(r)
 local deck,pool,event=r.deck,r.relicPool,r.nodeFlow.event
 local ok,why=Nodes.chooseEvent(r,'box');eq(ok,false);eq(why,'relic_content_unavailable');same(r,b)
 eq(r.deck,deck);eq(r.relicPool,pool);eq(r.nodeFlow.event,event);eq(r.relicPool.queues.common[1],'Boot')
end)
test('full source pool reaches all four official content IDs without changing restricted seven',function()
 local R=require('abyss_sts_random')
 for _,entry in ipairs({{'Liars Game','sssserpent','act'},{'Big Fish','big_fish','act'},{'Accursed Blacksmith','accursed_blacksmith','once'},{'Bonfire Elementals','bonfire','once'}})do
  local r,m=Run.new(Data,42),Map.generate(Data,42);r.unknown.pools=Pool.new('full')
  r.unknown.pools.act={};r.unknown.pools.shrine={};r.unknown.pools.once={};r.unknown.pools[entry[3]]={entry[1]}
  r.eventRng=R.restore({words={'0000000000000000','4000000000000000'},counter=0})
  local first=Map.available(m)[1];for _,n in ipairs(m.nodes)do if n.id==first.id then n.type='event';n.eventId=nil end end
  assert(Nodes.enter(r,m,first.id));eq(r.nodeFlow.event.id,entry[2]);eq(r.nodeFlow.event.originalId,entry[1]);eq(#r.unknown.pools[entry[3]],0)
 end
 local p=Pool.new('restricted-seven');eq(#p.act+#p.shrine+#p.once,7)
end)
test('blacksmith rummage grants real Tongs and Pain through the shared permanent hooks',function()
 local r=fixture('accursed_blacksmith');local before=C.copy(r)
 assert(Nodes.chooseEvent(r,'rummage'));eq(r.relics[#r.relics],'warped_tongs')
 eq(r.deck[#r.deck].cardId,'pain');eq(r.deck[#r.deck].uid,before.nextDeckUid)
 eq(r.nodeFlow.event.stage,'result');same(r.miscRng,before.miscRng)
 local saved=C.copy(r);eq(Nodes.chooseEvent(r,'rummage'),false);same(r,saved)
end)
test('blacksmith uses old Omamori before obtaining Tongs and does not allocate a blocked curse UID',function()
 local r=fixture('accursed_blacksmith');assert(Run.obtainRelic(r,'Omamori'));local before=C.copy(r)
 assert(Nodes.chooseEvent(r,'rummage'));eq(r.relics[#r.relics],'warped_tongs')
 same(r.deck,before.deck);eq(r.nextDeckUid,before.nextDeckUid);eq(r.relicCounters.omamori,1)
 eq(r.nodeFlow.event.curseBlocked,true)
end)
test('bonfire curse obtains Spirit Poop then repeatable Circlet and permanently removes each offered UID',function()
 local r=fixture('bonfire',{{uid=7,cardId='parasite',upgraded=false}});r.hp=80
 assert(Nodes.chooseEvent(r,'approach'));assert(Nodes.chooseEvent(r,'offer'));assert(Nodes.chooseEvent(r,'offer',7))
 eq(r.relics[#r.relics],'spirit_poop');eq(#r.deck,0);eq(r.maxHp,77);eq(r.hp,77)
 eq(require('abyss_relic_hooks').scoreAdjustment(r),-1)
 for turn=1,2 do
  r.phase='node';r.nodeFlow.complete=false;r.nodeFlow.event={id='bonfire',stage='choose_card',choice='offer'}
  r.deck={{uid=7+turn,cardId='doubt',upgraded=false}}
  assert(Nodes.chooseEvent(r,'offer',7+turn));eq(#r.deck,0);eq(r.relicCounters.circlet,turn)
 end
 local n=0;for _,id in ipairs(r.relics)do if id=='circlet' then n=n+1 end end;eq(n,1)
end)
print('ACT1_EVENT_CONTENT '..count..' passed')
