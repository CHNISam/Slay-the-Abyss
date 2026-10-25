-- Independent fixed 319009d5 Fountain/AbstractPlayer contracts, exercised via real nodes.
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,Run,Map,Nodes,R,Pool=require('abyss_combat'),require('abyss_run'),require('abyss_map'),require('abyss_nodes'),require('abyss_sts_random'),require('abyss_event_pool')
local Data=require('abyss_data')
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function same(a,b) eq(type(a),type(b));if type(a)~='table' then eq(a,b);return end;for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end end
local n=0
local function test(name,fn) fn();n=n+1;print('PASS fountain '..n..' '..name)end
local function fixture(deck,pooled)
 local run,map=Run.new(Data,42),Map.generate(Data,42);run.deck=C.copy(deck or {})
 local first=Map.available(map)[1];local node
 for _,v in ipairs(map.nodes)do if v.id==first.id then node=v end end
 node.type='event';node.eventId=not pooled and 'fountain' or nil
 if pooled then
  run.unknown.pools=Pool.new('full');run.unknown.pools.act={};run.unknown.pools.shrine={};run.unknown.pools.once={'Fountain of Cleansing'}
  -- Independent float .5 vector routes to Event with the real base chances.
  run.eventRng=R.restore({words={'0000000000000000','4000000000000000'},counter=0})
 end
 return run,map,node
end
local function enter(deck,pooled)local r,m,node=fixture(deck,pooled);assert(Nodes.enter(r,m,node.id));return r,m end
test('official content mapping and real options',function()
 eq(Pool.contentId['Fountain of Cleansing'],'fountain')
 local r,m=enter({{uid=8,cardId='regret'}});local o=Nodes.view(r,m).node.event.options
 eq(#o,2);eq(o[1].choice,'cleanse');eq(o[1].enabled,true);eq(o[1].picker,nil);eq(o[2].choice,'leave')
end)
test('cleansing removes only permanent curse UIDs in reverse deck order, with zero HP reward',function()
 for _,hp in ipairs({40,80})do
  local r=enter({{uid=1,cardId='regret'},{uid=2,cardId='strike'},{uid=3,cardId='regret',inBottleTornado=true}})
  r.hp=hp;r.maxHp=80;r.combat={hand={{uid=4,cardId='regret'}}}
  local before=C.copy(r);assert(Nodes.chooseEvent(r,'cleanse'));eq(#r.deck,1);eq(r.deck[1].uid,2)
  same(r.nodeFlow.event.removedUids,{3,1});eq(r.hp,hp);eq(r.maxHp,80);eq(r.gold,before.gold);eq(r.nextDeckUid,before.nextDeckUid)
  same(r.combat,before.combat);same(r.miscRng,before.miscRng);same(r.eventRng,before.eventRng)
  local saved=C.copy(r);eq(Nodes.chooseEvent(r,'cleanse'),false);same(r,saved)
 end
end)
test('Flame and Lightning remain, empty cleanse and leave finish without damage or healing',function()
 for _,deck in ipairs({{},{{uid=1,cardId='regret',inBottleFlame=true},{uid=2,cardId='regret',inBottleLightning=true}}})do
  local r=enter(deck);assert(Nodes.chooseEvent(r,'cleanse'));same(r.deck,deck);same(r.nodeFlow.event.removedUids,{});eq(r.phase,'map')
 end
 local r=enter({{uid=1,cardId='regret'}});local deck=C.copy(r.deck);assert(Nodes.chooseEvent(r,'leave'));same(r.deck,deck);eq(r.hp,r.maxHp)
end)
test('invalid choice and unsupported remove hook fail atomically',function()
 local r=enter({{uid=1,cardId='regret'}});local before=C.copy(r);eq(Nodes.chooseEvent(r,'pray'),false);same(r,before)
 r.data=C.copy(r.data);r.data.cards.cards[#r.data.cards.cards+1]={id='unsupported_curse',type='curse'};r.deck[1].cardId='unsupported_curse'
 before=C.copy(r);local ok,why=Nodes.chooseEvent(r,'cleanse');eq(ok,false);eq(why,'event_content_unavailable');same(r,before)
end)
test('all ten basic curses cleanse through their own permanent removal hooks',function()
 local ids={'regret','injury','shame','parasite','normality','doubt','writhe','pain','decay','clumsy'}
 local deck={};for i,id in ipairs(ids)do deck[i]={uid=i,cardId=id}end
 local r=enter(deck);r.hp=80
 assert(Nodes.chooseEvent(r,'cleanse'));eq(#r.deck,0);eq(r.maxHp,77);eq(r.hp,77)
 for i=1,10 do eq(r.nodeFlow.event.removedUids[i],11-i)end
 local bottled=enter({{uid=1,cardId='parasite',inBottleFlame=true},{uid=2,cardId='doubt'}})
 assert(Nodes.chooseEvent(bottled,'cleanse'));eq(bottled.maxHp,80);eq(#bottled.deck,1)
end)
test('full one-time pool selects from permanent deck, consumes on entry even when leaving',function()
 local r,m=enter({{uid=1,cardId='regret',inBottleFlame=true}},true)
 eq(r.nodeFlow.event.originalId,'Fountain of Cleansing');eq(#r.unknown.pools.once,0);eq(r.nodeFlow.selectionRng.counter,r.eventRng.counter+2)
 assert(Nodes.chooseEvent(r,'leave'));eq(#r.unknown.pools.once,0);eq(#r.deck,1)
 local normal=Pool.new('restricted-seven');eq(#normal.once,0);eq(#normal.act+#normal.shrine,7)
end)
test('temporary curses do not grant full-pool eligibility; failure does not consume pool/RNG/map',function()
 local r,m,node=fixture({{uid=1,cardId='strike'}},true);r.combat={hand={{cardId='regret'}}}
 local before,bmap=C.copy(r),C.copy(m);local ok,why=Nodes.enter(r,m,node.id)
 eq(ok,false);eq(why,'event_pool_exhausted');same(r,before);same(m,bmap)
end)
test('three protected curses never grant eligibility or removal',function()
 for _,id in ipairs({'Necronomicurse','CurseOfTheBell','AscendersBane','necronomicurse','curse_of_the_bell','ascenders_bane'})do
  local r,m,node=fixture({{uid=1,cardId=id}},true)
  r.data=C.copy(r.data);r.data.cards.cards[#r.data.cards.cards+1]={id=id,type='curse'}
  local before=C.copy(r);local ok,why=Nodes.enter(r,m,node.id);eq(ok,false);eq(why,'event_pool_exhausted');same(r,before)
  node.eventId='fountain';assert(Nodes.enter(r,m,node.id));assert(Nodes.chooseEvent(r,'cleanse'));eq(r.deck[1].uid,1);eq(#r.nodeFlow.event.removedUids,0)
 end
end)
print('FOUNTAIN_EVENT '..n..' passed')
