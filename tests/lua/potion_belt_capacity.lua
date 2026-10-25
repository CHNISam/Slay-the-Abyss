package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,Data=require('abyss_run'),require('abyss_combat'),require('abyss_data')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b)eq(type(a),type(b));if type(a)~='table'then eq(a,b);return end;for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end end
local count=0
local function test(name,fn)fn();count=count+1;print('PASS potion belt '..count..' '..name)end
test('real Potion Belt changes capacity from three to five without changing base rules',function()
 local r=Run.new(Data,42);eq(Run.potionCapacity(r),3)
 assert(Run.obtainRelic(r,'Potion Belt'));eq(Run.potionCapacity(r),5);eq(r.data.rules.player.potionSlots,3)
end)
test('fourth and fifth acquisition full refusal discard and leftmost refill keep physical identity',function()
 local r=Run.new(Data,42)
 for _,id in ipairs({'fire_potion','block_potion','regen_potion'})do assert(Run.obtainPotion(r,id))end
 local b=C.copy(r);local ok,why=Run.obtainPotion(r,'energy_potion');eq(ok,false);eq(why,'potion_slots_full');same(r,b)
 assert(Run.obtainRelic(r,'Potion Belt'))
 local ok,slot=Run.obtainPotion(r,'energy_potion');eq(ok,true);eq(slot,4)
 ok,slot=Run.obtainPotion(r,'strength_potion');eq(ok,true);eq(slot,5);eq(Run.potionCount(r),5)
 b=C.copy(r);ok,why=Run.obtainPotion(r,'dexterity_potion');eq(ok,false);eq(why,'potion_slots_full');same(r,b)
 assert(Run.discardPotion(r,4));eq(r.potions[5],'strength_potion');eq(Run.potionCount(r),4)
 ok,slot=Run.obtainPotion(r,'dexterity_potion');eq(ok,true);eq(slot,4)
 same(r.potions,{'fire_potion','block_potion','regen_potion','dexterity_potion','strength_potion'})
end)
test('real battle view and use accept slots four and five and preserve neighbors',function()
 local r=Run.new(Data,42);assert(Run.obtainRelic(r,'Potion Belt'))
 for _,id in ipairs({'fire_potion','block_potion','regen_potion','energy_potion','strength_potion'})do assert(Run.obtainPotion(r,id))end
 assert(Run.startCombat(r,'cultist_solo'));local v=Run.potionView(r);eq(v[4].slot,4);eq(v[5].slot,5)
 assert(Run.usePotion(r,4));eq(r.combat.energy,5);eq(r.potions[4],nil);eq(r.potions[5],'strength_potion')
 assert(Run.usePotion(r,5));eq(r.combat.player.statuses.strength,2);eq(r.potions[5],nil);eq(Run.potionCount(r),3)
end)
test('default three rejects nonexistent fourth and fifth slots without mutation',function()
 local r=Run.new(Data,42);assert(Run.startCombat(r,'cultist_solo'))
 for _,slot in ipairs({4,5,6})do
  local b=C.copy(r);local ok,why=Run.usePotion(r,slot);eq(ok,false);eq(why,'invalid_potion_slot');same(r,b)
  ok,why=Run.discardPotion(r,slot);eq(ok,false);eq(why,'invalid_potion_slot');same(r,b)
 end
end)
print('POTION_BELT_CAPACITY '..count..' passed')
