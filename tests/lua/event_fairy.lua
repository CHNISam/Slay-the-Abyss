package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,Map,Nodes,R,C=require('abyss_run'),require('abyss_map'),require('abyss_nodes'),require('abyss_sts_random'),require('abyss_combat')
local Data=require('abyss_data')
local count,failures=0,{}
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b)
 eq(type(a),type(b));if type(a)~='table'then eq(a,b);return end
 for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil,'unexpected '..tostring(k))end
end
local function state(n)return R.restore({words={'0000000000000000',string.format('%016x',n)},counter=0})end
local function fixture(kind)
 local r,m=Run.new(Data,42),Map.generate(Data,42)
 local n=Map.available(m)[1]
 for _,v in ipairs(m.nodes)do if v.id==n.id then v.type='event';v.eventId=kind end end
 assert(Nodes.enter(r,m,n.id));return r,m
end
local function damage(r,kind,roll)
 if kind=='wheel'then r.miscRng=state(5);assert(Nodes.chooseEvent(r,'spin'));return Nodes.chooseEvent(r,'accept')end
 r.miscRng=state(roll or 0);return Nodes.chooseEvent(r,'search')
end
local function test(name,fn)
 local ok,why=pcall(fn)
 if ok then count=count+1;print('PASS event fairy '..count..' '..name)
 else failures[#failures+1]=name..': '..tostring(why);print('FAIL '..failures[#failures])end
end
test('real Scrap Ooze and Wheel fatal damage revive then finish their normal event stages',function()
 for _,kind in ipairs({'scrap_ooze','wheel'})do
  local r,m=fixture(kind);r.hp=1;assert(Run.obtainPotion(r,'fairy_in_a_bottle'))
  assert(damage(r,kind));eq(r.hp,24);eq(r.maxHp,80);eq(r.potions[1],nil);eq(r.phase,'node')
  eq(r.miscRng.counter,1);assert(not r.nodeFlow.complete)
  assert(Nodes.chooseEvent(r,'leave'))
  if kind=='scrap_ooze'then eq(r.phase,'node');assert(Nodes.chooseEvent(r,'leave'))end
  eq(r.phase,'map');assert(#Nodes.available(r,m)>0)
 end
end)
test('event revival applies Bark and Bloom but never combat Flower or ordinary Toy healing',function()
 for _,kind in ipairs({'scrap_ooze','wheel'})do
  for _,spec in ipairs({{{'magic_flower'},24},{{'sacred_bark'},48},{{'sacred_bark','magic_flower'},48},{{'mark_of_bloom','sacred_bark'},0}})do
   local r=fixture(kind);r.hp=1;assert(Run.obtainPotion(r,'fairy_in_a_bottle'));assert(Run.obtainRelic(r,'Toy Ornithopter'))
   for _,id in ipairs(spec[1])do r.relics[#r.relics+1]=id end
   assert(damage(r,kind));eq(r.hp,spec[2])
   if spec[2]==0 then eq(r.phase,'defeat');eq(r.potions[1],'fairy_in_a_bottle')
   else eq(r.phase,'node');eq(r.potions[1],nil)end
  end
 end
end)
test('leftmost occupied Fairy consumes one physical slot per fatal Scrap search across a five-slot belt',function()
 local r=fixture('scrap_ooze');assert(Run.obtainRelic(r,'Potion Belt'))
 for _,id in ipairs({'block_potion','swift_potion','fairy_in_a_bottle','energy_potion','fairy_in_a_bottle'})do assert(Run.obtainPotion(r,id))end
 assert(Run.discardPotion(r,4));r.hp=1
 assert(damage(r,'scrap_ooze'));eq(r.hp,24);eq(r.potions[3],nil);eq(r.potions[5],'fairy_in_a_bottle')
 r.hp=1;assert(damage(r,'scrap_ooze'));eq(r.hp,24);eq(r.potions[5],nil);eq(r.potions[1],'block_potion');eq(r.potions[2],'swift_potion');eq(r.potions[4],nil)
 r.hp=1;assert(damage(r,'scrap_ooze'));eq(r.phase,'defeat');eq(r.hp,0)
end)
test('stale combat health inventory powers and relics cannot influence outside damage or be changed',function()
 local r=fixture('wheel');r.hp=1;assert(Run.obtainPotion(r,'fairy_in_a_bottle'))
 r.combat={player={hp=0,maxHp=999,statuses={intangible=3}},relics={'mark_of_bloom','sacred_bark','magic_flower'},potionInventory={[1]='block_potion'},events={{kind='old'}}}
 local old=C.copy(r.combat);assert(damage(r,'wheel'));eq(r.hp,24);eq(r.maxHp,80);eq(r.potions[1],nil);same(r.combat,old)
end)
test('missing selected relic rolls back fatal damage Fairy slot RNG progression and every live owner',function()
 local r,m=fixture('scrap_ooze');r.hp=1;assert(Run.obtainPotion(r,'fairy_in_a_bottle'));r.miscRng=state(99)
 r.relicPool.rng=state(0);local q=r.relicPool.queues.common
 for i,v in ipairs(q)do if v=='Anchor'then table.remove(q,i);break end end;table.insert(q,1,'Anchor')
 r.data=C.copy(r.data);for i=#r.data.relics.relics,1,-1 do if r.data.relics.relics[i].id=='anchor'then table.remove(r.data.relics.relics,i)end end
 local before,map=C.copy(r),C.copy(m);local inventory,event,pool,misc,deck=r.potions,r.nodeFlow.event,r.relicPool,r.miscRng,r.deck
 local prepare,observed=Run.prepareRelic
 Run.prepareRelic=function(staged,options)observed={hp=staged.hp,potion=staged.potions[1],rng=staged.miscRng.counter};return prepare(staged,options)end
 local ok,why=Nodes.chooseEvent(r,'search');Run.prepareRelic=prepare
 eq(ok,false);eq(why,'relic_content_unavailable');eq(observed.hp,24);eq(observed.potion,nil);eq(observed.rng,1);same(r,before);same(m,map)
 eq(r.potions,inventory);eq(r.nodeFlow.event,event);eq(r.relicPool,pool);eq(r.miscRng,misc);eq(r.deck,deck)
end)
test('nonlethal and zero damage do not use Fairy while absent or blocked Fairy preserves fatal defeat',function()
 for _,kind in ipairs({'scrap_ooze','wheel'})do
  local r=fixture(kind);assert(Run.obtainPotion(r,'fairy_in_a_bottle'));assert(damage(r,kind));eq(r.hp,kind=='wheel'and 72 or 77);eq(r.potions[1],'fairy_in_a_bottle')
  r=fixture(kind);r.hp=1;assert(damage(r,kind));eq(r.phase,'defeat');eq(r.hp,0)
 end
 local r=fixture('scrap_ooze');r.hp=1;assert(Run.obtainPotion(r,'fairy_in_a_bottle'))
 assert(Run.eventDamage(r,0));eq(r.hp,1);eq(r.potions[1],'fairy_in_a_bottle')
 local before=C.copy(r);r.phase='combat';local combat=C.copy(r);eq(Run.eventDamage(r,3),false);same(r,combat);r.phase='node';same(r,before)
end)
test('legacy Nodes damage events use the same outside boundary without changing their rewards or picker',function()
 for _,spec in ipairs({{'goop','gather'},{'shining_light','accept'},{'golden_wing','sacrifice'}})do
  local r=fixture(spec[1]);r.hp=1;assert(Run.obtainPotion(r,'fairy_in_a_bottle'));local gold=r.gold
  assert(Nodes.chooseEvent(r,spec[2]));eq(r.hp,24);eq(r.potions[1],nil)
  if spec[1]=='goop'then eq(r.gold,gold+r.data.rules.events.goop.gold);eq(r.phase,'map')
  elseif spec[1]=='shining_light'then eq(#r.nodeFlow.event.upgradedUids,2);eq(r.phase,'map')
  else eq(r.phase,'node');eq(r.nodeFlow.event.stage,'purge');local uid=r.deck[1].uid;assert(Nodes.chooseEvent(r,'purge',uid));eq(r.phase,'map');eq(#r.deck,9)end
 end
end)
test('event Fairy minimum one HP is not confused with maximum-health changes or existing death',function()
 local r=fixture('scrap_ooze');r.hp,r.maxHp=1,2;assert(Run.obtainPotion(r,'fairy_in_a_bottle'))
 assert(damage(r,'scrap_ooze'));eq(r.hp,1);eq(r.potions[1],nil);eq(r.phase,'node')
 r=fixture('scrap_ooze');r.hp=1;assert(Run.obtainPotion(r,'fairy_in_a_bottle'));assert(Run.increaseMaxHp(r,5));eq(r.hp,6);eq(r.potions[1],'fairy_in_a_bottle')
 r.hp=0;local before=C.copy(r);eq(Run.eventDamage(r,3),false);same(r,before)
 for _,invalid in ipairs({-1,.5,'3',false,math.huge})do local old=C.copy(r);eq(Run.eventDamage(r,invalid),false);same(r,old)end
end)
assert(#failures==0,table.concat(failures,'\n'))
print('EVENT_FAIRY '..count..' passed')
