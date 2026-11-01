package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,R,B=require('abyss_run'),require('abyss_combat'),require('abyss_sts_random'),require('abyss_boss_relics')
local D=require('abyss_data')
local sourceIds={['Velvet Choker']=true,['Runic Dome']=true,['Snecko Eye']=true,["Pandora's Box"]=true,
 ['Cursed Key']=true,['Busted Crown']=true,Ectoplasm=true,['Tiny House']=true,["Philosopher's Stone"]=true,
 Astrolabe=true,['Empty Cage']=true,['Runic Pyramid']=true,['Calling Bell']=true,['Mark of Pain']=true,['Runic Cube']=true}
local cases={};for _,d in ipairs(D.relics.relics)do if sourceIds[d.sourceId]then cases[#cases+1]=d end end
assert(#cases==15,'canonical boss definitions missing')
local count,failed=0,0
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b)
 eq(type(a),type(b));if type(a)~='table'then eq(a,b);return end
 for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil,'extra '..tostring(k))end
end
local function test(name,fn)local ok,why=pcall(fn);count=count+1;if not ok then failed=failed+1 end;print((ok and 'PASS 'or'FAIL ')..name..(ok and''or': '..tostring(why)))end
local function fresh()return Run.new(D,'42',{experimental=true,character='ironclad'})end
local function obtain(r,id)local ok,why=Run.obtainRelic(r,id);assert(ok,why)end
local function battle(r)assert(Run.startRoomCombat(r,'normal'));return r.combat end

test('seven energy bosses prepare four energy and Ectoplasm prevents actual gold',function()
 for _,id in ipairs({'velvet_choker','runic_dome','cursed_key','busted_crown','ectoplasm','philosophers_stone','mark_of_pain'})do
  local r=fresh();obtain(r,id);local s=battle(r);eq(s.energy,4)
  if id=='ectoplasm'then local gold=r.gold;eq(Run.gainGold(r,50),0);eq(r.gold,gold)end
 end
end)
test('Snecko applies confusion before first seven-card draw',function()
 local r=fresh();obtain(r,'snecko_eye');local s=battle(r)
 eq(#s.hand,7);eq(s.player.statuses.confusion,1)
 local changed=false;for _,c in ipairs(s.hand)do if c.costOverride~=nil then changed=true end end
 assert(changed,'first draw never dispatched Confusion')
end)
test('Stone grants one strength at opening and to newly spawned monsters',function()
 local r=fresh();obtain(r,'philosophers_stone');local s=battle(r)
 for _,e in ipairs(s.enemies)do eq(e.statuses.strength,1)end
 local e=C.copy(s.enemies[1]);e.statuses.strength=nil;B.onSpawnMonster(s,e);eq(e.statuses.strength,1)
end)
test('Mark of Pain inserts exactly two temporary wounds with unique identities',function()
 local r=fresh();obtain(r,'mark_of_pain');local s=battle(r);local found=0;local uids={}
 for _,pile in ipairs({s.hand,s.draw,s.discard,s.exhaust})do for _,c in ipairs(pile)do
  assert(not uids[c.uid]);uids[c.uid]=true;if c.cardId=='wound'then found=found+1 end
 end end
 eq(found,2);eq(#r.deck,10)
end)
test('Runic Cube draws once for each actual HP loss and none for block',function()
 local r=fresh();obtain(r,'runic_cube');local s=battle(r);local old=#s.hand
 C.damage(s,s.enemies[1],s.player,1,true);eq(#s.hand,old+1)
 s.player.block=10;C.damage(s,s.enemies[1],s.player,1);eq(#s.hand,old+1)
 s.player.block=0;C.damage(s,s.enemies[1],s.player,1,true);eq(#s.hand,old+2)
end)
test('Empty Cage selects two distinct live UIDs and rejects duplicate input atomically',function()
 local r=fresh();obtain(r,'empty_cage');local p=assert(r.pendingBossRelic)
 eq(p.total,2);local first,second=r.deck[1].uid,r.deck[2].uid
 assert(B.select(r,first));local before=C.copy(r);assert(not B.select(r,first));same(r,before)
 assert(B.select(r,second));eq(#r.deck,8);eq(r.pendingBossRelic,nil)
 assert(not B.select(r,second))
end)
test('Astrolabe really removes three old cards and obtains three upgraded replacements',function()
 local r=fresh();obtain(r,'astrolabe');local uids={r.deck[1].uid,r.deck[2].uid,r.deck[3].uid}
 local nextUid=r.nextDeckUid;local before=R.snapshot(r.miscRng)
 for _,uid in ipairs(uids)do assert(B.select(r,uid))end
 eq(r.pendingBossRelic,nil);eq(#r.deck,10);eq(r.nextDeckUid,nextUid+3)
 assert(r.miscRng.counter>before.counter)
 for i=#r.deck-2,#r.deck do assert(r.deck[i].upgraded);assert(r.deck[i].uid>=nextUid)end
end)
test('Pandora replaces every starter, preserving Bash and permanent obtain hooks',function()
 local r=fresh();obtain(r,'ceramic_fish');local gold=r.gold;local nextUid=r.nextDeckUid
 obtain(r,'pandoras_box');eq(#r.deck,10);eq(r.nextDeckUid,nextUid+9);eq(r.gold,gold+81)
 local starters=0;for _,c in ipairs(r.deck)do if c.cardId=='strike'or c.cardId=='defend'then starters=starters+1 end end
 eq(starters,0)
end)
test('Tiny House upgrades one card, increases health, and exposes once-only real rewards',function()
 local r=fresh();r.hp=20;local maxHp,gold=r.maxHp,r.gold;obtain(r,'tiny_house')
 eq(r.maxHp,maxHp+5);eq(r.hp,25);eq(r.gold,gold)
 local upgrades=0;for _,c in ipairs(r.deck)do if c.upgraded then upgrades=upgrades+1 end end;eq(upgrades,1)
 local p=assert(r.pendingBossRelic);eq(p.gold,50);assert(p.potion and p.cards and #p.cards==3)
 assert(B.claim(r,'gold'));eq(r.gold,gold+50);assert(not B.claim(r,'gold'))
 assert(B.claim(r,'potion'));eq(r.potions[1],p.potion.id)
 local before=#r.deck;assert(B.claim(r,'card',1));eq(#r.deck,before+1);assert(not B.claim(r,'card',1))
 assert(B.claim(r,'done'));eq(r.pendingBossRelic,nil)
end)
test('Crown and visibility/retention predicates follow actual acquired owners',function()
 local r=fresh();obtain(r,'busted_crown');eq(B.cardRewardCount(r,3),1)
 local ids=require('abyss_card_pool').prepareRewards(r);eq(#ids,1)
 obtain(r,'runic_dome');assert(B.hidesIntents(r));obtain(r,'runic_pyramid');assert(B.retainsHand(r))
end)
test('Velvet Choker refuses the seventh real card and resets next turn',function()
 local r=fresh();obtain(r,'velvet_choker');local s=battle(r)
 s.hand={};s.draw={};s.discard={};s.energy=20
 for i=1,7 do s.hand[i]={uid=100+i,cardId='defend',upgraded=false}end
 s.nextUid=108
 for i=1,6 do local ok,why=C.play(s,100+i);assert(ok,why)end
 eq(s.relicCounters.velvet_choker,6)
 local before=C.copy(s);local ok,why=C.play(s,107);assert(not ok);eq(why,'velvet_choker_limit');same(s,before)
 assert(C.endTurn(s));eq(s.relicCounters.velvet_choker,0)
end)
test('Runic Pyramid preserves ordinary hand cards across the real end-turn continuation',function()
 local r=fresh();obtain(r,'runic_pyramid');local s=battle(r);local held={}
 for _,card in ipairs(s.hand)do held[card.uid]=true end
 assert(C.endTurn(s));local found=0;for _,card in ipairs(s.hand)do if held[card.uid]then found=found+1 end end
 eq(found,5)
end)
test('Calling Bell obtains its protected curse and individually grants three source relic offers',function()
 local r=fresh();local size=#r.deck;obtain(r,'calling_bell');eq(#r.deck,size+1)
 local p=assert(r.pendingBossRelic);eq(#p.relics,3)
 local protected=true
 for _,card in ipairs(require('abyss_living_wall').purgeCards(r))do if card.cardId=='curse_of_the_bell'then protected=false end end
 assert(protected)
 for i=1,3 do
  local id=r.pendingBossRelic.relics[i].id;local old=#r.relics
  local ok,why=B.claim(r,'relic',i);assert(ok,why);eq(#r.relics,old+1)
  eq(r.relics[#r.relics],id);local before=C.copy(r);assert(not B.claim(r,'relic',i));same(r,before)
 end
 assert(B.claim(r,'done'));eq(r.pendingBossRelic,nil)
end)
test('failed complex obtain restores ownership, entropy, deck and pending state',function()
 local r=fresh();r.nextDeckUid=9007199254740991.0;local before=C.copy(r)
 assert(not Run.obtainRelic(r,'pandoras_box'));same(r,before)
end)
test('all fifteen source identities survive boss chest creation, opening and ordinary claiming',function()
 local Map,Nodes=require('abyss_map'),require('abyss_nodes')
 local base=Run.new(D,'42',{experimental=true,character='ironclad',campaign=true,campaignProfile='full-source'})
 local map=Map.generate(D,'42',1,assert(Run.freezeMapContext(base)))
 local boss=require('abyss_acts').get(1).boss
 while Map.available(map)[1].floor<=boss do assert(Map.choose(map,Map.available(map)[1].id))end
 for _,d in ipairs(cases)do
  local r=C.copy(base);local m=C.copy(map);local queue=r.relicPool.queues.boss;local position
  for i,id in ipairs(queue)do if id==d.sourceId then position=i;break end end
  assert(position,'source identity absent from full boss queue '..d.sourceId)
  table.insert(queue,1,table.remove(queue,position))
  r.floor,r.phase=boss,'map'
  r.nodeFlow={id=m.currentNodeId,floor=boss,type='boss',complete=true,result='boss_victory',mapSeed=m.seed,mapSignature=m.sourceSignature}
  assert(Nodes.enter(r,m,Map.available(m)[1].id));eq(r.nodeFlow.reward.relics[1],d.id)
  assert(Nodes.openTreasure(r));local ok,why=Nodes.claimBossTreasure(r,1);assert(ok,why)
  local held=false;for _,id in ipairs(r.relics)do if id==d.id then held=true end end;assert(held,d.id)
  if d.id=='empty_cage'or d.id=='astrolabe'then
   assert(r.pendingBossRelic and r.pendingBossRelic.kind=='cards')
  elseif d.id=='tiny_house'or d.id=='calling_bell'then
   assert(r.pendingBossRelic and r.pendingBossRelic.kind=='rewards')
  end
 end
end)
assert(failed==0,tostring(failed)..' boss relic failures')
print('LUA_BOSS_RELICS_MISSING_PASS '..count)
