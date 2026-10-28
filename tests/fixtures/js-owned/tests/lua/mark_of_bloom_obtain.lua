package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,Data=require('abyss_run'),require('abyss_combat'),require('abyss_data')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local count=0
local function test(name,fn)fn();count=count+1;print('ok Mark obtain '..count..' '..name)end
local function fresh(id)
 local r=Run.new(Data,'42');r.hp=20;assert(Run.obtainRelic(r,id or 'Mark of the Bloom'));return r
end
test('named SPECIAL obtain canonicalizes identity and rejects duplicate source/local claims',function()
 for _,id in ipairs({'mark_of_bloom','Mark of the Bloom'})do
  local r=fresh(id);eq(r.relics[#r.relics],'mark_of_bloom');eq(r.hp,20)
  local size=#r.relics;local pool=r.relicPool
  for _,other in ipairs({'mark_of_bloom','Mark of the Bloom'})do
   local ok,why=Run.obtainRelic(r,other);eq(ok,false);eq(why,'relic_already_owned');eq(#r.relics,size);eq(r.relicPool,pool)
  end
 end
end)
test('real permanent heal and maximum HP increase keep the mark authoritative',function()
 local r=fresh();eq(Run.heal(r,99),0);eq(r.hp,20)
 local maximum=r.maxHp;local ok,healed=Run.increaseMaxHp(r,5);assert(ok);eq(healed,0);eq(r.maxHp,maximum+5);eq(r.hp,20)
 assert(Run.obtainRelic(r,'Strawberry'));eq(r.maxHp,maximum+12);eq(r.hp,20)
end)
test('real outside Blood Potion and Fruit Juice consume bottles without healing',function()
 for _,id in ipairs({'blood_potion','fruit_juice'})do
  local r=fresh();assert(Run.obtainRelic(r,'Toy Ornithopter'));local maximum=r.maxHp
  assert(Run.obtainPotion(r,id));assert(Run.usePotion(r,1));eq(r.hp,20);eq(r.potions[1],nil)
  eq(r.maxHp,maximum+(id=='fruit_juice' and 5 or 0))
 end
end)
test('real source opening Blood Vial and automatic Fairy cannot bypass the Mark',function()
 local r=fresh();assert(Run.obtainRelic(r,'Blood Vial'));assert(Run.obtainPotion(r,'fairy_in_a_bottle'))
 assert(Run.startCombat(r,'cultist_solo'));eq(r.combat.player.hp,20)
 local s=r.combat;C.damage(s,s.enemies[1],s.player,999,true)
 eq(s.player.hp,0);eq(s.potionInventory[1],'fairy_in_a_bottle');eq(r.potions[1],'fairy_in_a_bottle')
end)
print('MARK_BLOOM_OBTAIN_PASS '..count..' explicit-only; natural MindBloom NOT_RUN')
