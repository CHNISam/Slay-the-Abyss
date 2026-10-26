package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local H,C,I,R,A,U,N,Map,S=require('abyss_relic_hooks'),require('abyss_combat'),require('abyss_inventory'),require('abyss_run'),require('abyss_actor'),require('abyss_unknown'),require('abyss_nodes'),require('abyss_map'),require('abyss_sts_random')
local data=require('abyss_data')
local count=0
local function test(name,f)f();count=count+1;print('PASS '..name)end
local function battle(ids,hp,context)
 local q=assert(I.opening(data.relics.relics,ids,nil,context))
 local s=assert(C.new(data,{seed=42,hp=hp or 80,deck={'strike','defend','defend','defend','defend','defend','defend','defend','defend','defend'},enemies={'cultist'},
 beforeOpeningDraw=function(s)return I.applyOpening(s,q.beforeDraw)end}));assert(I.applyOpening(s,q.afterDraw));return s
end
test('PreservedInsect sets only elite current HP to floor 75 percent and preserves max HP',function()
 local normal=battle({'preserved_insect'},80,{tier='normal'})
 local elite=battle({'preserved_insect'},80,{tier='elite'})
 assert(elite.enemies[1].maxHp==normal.enemies[1].maxHp)
 assert(elite.enemies[1].hp==math.floor(S.float32(normal.enemies[1].maxHp*.75)))
end)
test('RedSkull starts at half HP, adds three Strength and removes it after healing above half',function()
 local s=battle({'red_skull'},40);assert(s.player.statuses.strength==3)
 local before=s.player.hp;s.player.hp=41;H.hpChanged(s,s.player,before);assert(s.player.statuses.strength==0)
 before=s.player.hp;C.applyEffects(s,{{op='loseHp',value=1}},s.player,s.player);assert(s.player.hp==40 and s.player.statuses.strength==3)
end)
test('CentennialPuzzle first positive HP loss queues TOP draw once including self-loss and thorns',function()
 local s=battle({'centennial_puzzle'});local n=#s.hand
 C.applyEffects(s,{{op='loseHp',value=1}},s.player,s.player)
 assert(#s.hand==n and #s.cardActions==1 and s.cardActions[1].effect.op=='draw' and s.cardActions[1].effect.value==3)
 C.applyEffects(s,{{op='loseHp',value=1}},s.player,s.player);assert(#s.hand==n and #s.cardActions==1)
 local other=battle({'centennial_puzzle'});n=#other.hand;C.addStatus(other.enemies[1],'thorns',1)
 C.damage(other,other.player,other.enemies[1],1);assert(#other.hand==n and #other.cardActions==1)
end)
test('Puzzle ignores fully blocked attacks and lethal loss does not draw after death',function()
 local s=battle({'centennial_puzzle'});local n=#s.hand;s.player.block=10
 A.damage(s,s.enemies[1],s.player,5);assert(#s.hand==n)
 C.applyEffects(s,{{op='loseHp',value=80}},s.player,s.player);assert(s.player.hp==0 and #s.hand==n)
 local ended=battle({'centennial_puzzle'});ended.enemies[1].hp=0;n=#ended.hand
 local before=ended.player.hp;ended.player.hp=before-1;H.hpChanged(ended,ended.player,before);assert(#ended.hand==n)
end)
test('RedSkull updates on actual normal damage and regeneration healing; Artifact may block negative Strength',function()
 local s=battle({'red_skull'},41);A.damage(s,s.enemies[1],s.player,1);assert(s.player.statuses.strength==3)
 C.addStatus(s.player,'regen',2);A.endTurn(s,s.player);assert(s.player.hp==42 and s.player.statuses.strength==0)
 s.player.hp=40;H.hpChanged(s,s.player,42);C.addStatus(s.player,'artifact',1)
 s.player.hp=41;H.hpChanged(s,s.player,40);assert(s.player.statuses.strength==3 and s.player.statuses.artifact==0)
end)
test('TinyChest equipment resets its actual unknown-room counter',function()
 local r=R.new(data,42);r.relics={'tiny_chest'};r.unknown.chances.tinyChestCount=3
 H.onEquip(r,'tiny_chest');assert(r.unknown.chances.tinyChestCount==0)
end)
test('Juzu and fourth TinyChest use existing formal Nodes unknown-room ownership adapters',function()
 for _,kind in ipairs({'juzu_bracelet','tiny_chest'})do
  local d=C.copy(data);d.rules.events.encounterId=nil
  local r,m=R.new(d,42),Map.generate(d,42);r.relics[#r.relics+1]=kind
  r.unknown.chances.tinyChestCount=3
  local target
  for _=1,15 do
   local options=Map.available(m)
   for _,node in ipairs(options)do if node.type=='event' then target=node;break end end
   if target then break end
   assert(options[1]);assert(Map.choose(m,options[1].id))
  end
  assert(target);local old=S.randomFloat
  S.randomFloat=function(rng)old(rng);return 0 end
  local called,ok,why=pcall(N.enter,r,m,target.id);S.randomFloat=old
  assert(called and ok,tostring(why))
  assert(r.nodeFlow.type==(kind=='tiny_chest' and 'treasure' or 'event'))
 end
end)
test('DreamCatcher rest hook requests the ordinary card reward once and refuses missing production adapter',function()
 local r={relics={'dream_catcher'}};local n=0
 local result=H.onRest(r,function(owner)assert(owner==r);n=n+1;return {'card1','card2','card3'}end)
 assert(n==1 and #result==3)
 assert(not pcall(H.onRest,r));r.relics={};assert(H.onRest(r)==nil)
end)
print('LUA_COMMON_RELIC_FINAL_PASS '..count)
