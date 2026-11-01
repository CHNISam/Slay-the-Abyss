package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,D=require('abyss_run'),require('abyss_combat'),require('abyss_data')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local count,failed=0,0
local function test(name,fn)
 count=count+1;local ok,why=pcall(fn)
 if not ok then failed=failed+1 end
 print((ok and 'PASS ' or 'FAIL ')..name..(ok and '' or ': '..tostring(why)))
end
local function fresh(id,upgraded,rod)
 local r=Run.new(D,42)
 local uids={};for _,c in ipairs(r.deck)do uids[#uids+1]=c.uid end
 for _,uid in ipairs(uids)do assert(Run.removeCard(r,uid))end
 assert(Run.obtainCard(r,id,{upgraded=upgraded}))
 if rod then assert(Run.obtainRelic(r,'tungsten_rod'))end
 assert(Run.startCombat(r,'cultist_solo'))
 local c=r.combat.hand[1];eq(c.cardId,id);eq(c.upgraded,upgraded)
 return r,c
end
for _,id in ipairs({'bloodletting','offering','hemokinesis'})do
 for _,upgraded in ipairs({false,true})do
  test('public Run '..id..(upgraded and '+' or '')..' pays HP after one Rod',function()
   local r,c=fresh(id,upgraded,true)
   local s=r.combat;local before=s.player.hp
   local definition=C.cardDefinition(s,c)
   local energy,enemyHp=s.energy,s.enemies[1].hp
   assert(Run.play(r,c.uid,1))
   eq(before-s.player.hp,definition.effects[1].value-1)
   eq(s.player.damagedThisCombat,1)
   if id=='hemokinesis'then eq(s.enemies[1].hp,enemyHp-definition.effects[2].value)
   else eq(s.energy,energy+definition.effects[2].value)end
   local pile=id=='offering' and s.exhaust or s.discard
   eq(pile[1].uid,c.uid);eq(r.deck[1].uid,c.deckUid)
   eq(Run.play(r,c.uid,1),false)
  end)
 end
end
test('public Run without Rod still pays full Offering HP',function()
 local r,c=fresh('offering',false,false);local hp=r.combat.player.hp
 assert(Run.play(r,c.uid));eq(hp-r.combat.player.hp,6)
end)
assert(failed==0,tostring(failed)..' Tungsten card HP-loss failures')
print('TUNGSTEN_ROD_CARD_HP_LOSS_PASS '..count)
