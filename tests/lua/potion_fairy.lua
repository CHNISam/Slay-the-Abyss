package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,Data=require('abyss_run'),require('abyss_combat'),require('abyss_data')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function battle(hp)
 local r=Run.new(Data,42);r.hp=hp or 1
 assert(Run.obtainPotion(r,'fairy_in_a_bottle'))
 assert(Run.startCombat(r,'cultist_solo'));return r
end
local n=0
local function test(name,f)f();n=n+1;print('ok fairy '..n..' - '..name)end
test('automatic bottle rejects ordinary use without spending it',function()
 local r=battle();local p=r.potions;local ok=Run.usePotion(r,1)
 eq(ok,false);eq(r.potions,p);eq(r.potions[1],'fairy_in_a_bottle');eq(Run.potionView(r)[1].canUse,false)
end)
test('normal enemy fatal hit revives and persists consumed physical slot',function()
 local r=battle();assert(Run.endTurn(r));assert(Run.endTurn(r))
 eq(r.phase,'combat');eq(r.combat.player.hp,24);eq(r.potions[1],nil)
 assert(Run.endTurn(r));assert(r.combat.player.hp<24);eq(r.potions[1],nil)
end)
test('multiple hits consume leftmost fairies independently with no onUsePotion heal',function()
 local r=battle();assert(Run.obtainPotion(r,'fairy_in_a_bottle'));assert(Run.obtainRelic(r,'Toy Ornithopter'))
 -- Damage arithmetic exercises the same fatal callback as enemy/card actions.
 local s=r.combat;C.damage(s,s.enemies[1],s.player,99,true);eq(s.player.hp,24)
 C.damage(s,s.enemies[1],s.player,99,true);eq(s.player.hp,24)
 C.damage(s,s.enemies[1],s.player,99,true);eq(s.player.hp,0)
 eq(s.potionInventory[1],nil);eq(s.potionInventory[2],nil)
end)
test('Mark of Bloom blocks revival without consuming the bottle',function()
 local r=battle();r.combat.relics[#r.combat.relics+1]='mark_of_bloom'
 C.damage(r.combat,r.combat.enemies[1],r.combat.player,99,true)
 eq(r.combat.player.hp,0);eq(r.combat.potionInventory[1],'fairy_in_a_bottle')
end)
test('minimum one HP and Sacred Bark doubled potency use float32 truncation',function()
 for _,spec in ipairs({{1,{},1},{83,{},24},{83,{'sacred_bark'},49}})do
  local r=battle();r.combat.player.maxHp=spec[1];r.combat.relics=spec[2]
  C.damage(r.combat,r.combat.enemies[1],r.combat.player,99,true);eq(r.combat.player.hp,spec[3])
 end
end)
test('failed combat command does not consume live potion owner',function()
 local r=battle();local owner=r.potions
 local ok=Run.play(r,-1,1);eq(ok,false);eq(r.potions,owner);eq(r.potions[1],'fairy_in_a_bottle')
end)
print('LUA_POTION_FAIRY_PASS '..n)
