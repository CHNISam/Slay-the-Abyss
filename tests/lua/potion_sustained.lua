package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,A,Data=require('abyss_run'),require('abyss_combat'),require('abyss_actor'),require('abyss_data')
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local count=0
local function test(name,fn) fn();count=count+1;print('ok sustained '..count..' '..name) end
local base=Run.new(Data,42)
local function battle(id)
 local run=C.copy(base);assert(Run.obtainPotion(run,id));assert(Run.startCombat(run,'cultist_solo'));return run
end
test('Iron heart grants six fixed block before end-turn Burn, stacks, and survives turns',function()
 local run=battle('heart_of_iron');local s=run.combat
 assert(Run.usePotion(run,1));eq(s.player.statuses.metallicize,6)
 C.addStatus(s.player,'dexterity',20);C.addStatus(s.player,'frail',2)
 s.hand={{cardId='burn',uid=1000}};local hp=s.player.hp
 assert(Run.endTurn(run));eq(s.player.hp,hp);eq(s.player.statuses.metallicize,6)
end)
test('Cultist applies player Ritual with immediate first owner-end trigger, no enemy hook double trigger',function()
 local run=battle('cultist_potion');local s=run.combat
 assert(Run.usePotion(run,1));eq(s.player.statuses.ritual,1)
 assert(Run.endTurn(run));eq(s.player.statuses.strength,1)
 assert(Run.endTurn(run));eq(s.player.statuses.strength,2)
 eq(s.player.statuses.ritual,1)
end)
test('Steel grants four plated armor before Burn; direct attack HP loss reduces one, blocked or THORNS does not',function()
 local run=battle('essence_of_steel');local s=run.combat
 assert(Run.usePotion(run,1));eq(s.player.statuses.plated_armor,4)
 s.hand={{cardId='burn',uid=1000}};local beforeBurn=s.player.hp
 assert(Run.endTurn(run));eq(s.player.hp,beforeBurn)
 s.player.block=20;C.damage(s,s.enemies[1],s.player,3);eq(s.player.statuses.plated_armor,4)
 s.player.block=0;C.damage(s,s.enemies[1],s.player,3);eq(s.player.statuses.plated_armor,3)
 C.damage(s,s.enemies[1],s.player,3,true);eq(s.player.statuses.plated_armor,3)
 C.applyEffects(s,{{op='loseHp',value=1}},s.player,s.player);eq(s.player.statuses.plated_armor,3)
 A.applyPower(s,s.player,'plated_armor',1000,s.player);eq(s.player.statuses.plated_armor,999)
end)
test('all sustained potions reject outside combat without consuming the source slot',function()
 for _,id in ipairs({'heart_of_iron','essence_of_steel','cultist_potion'}) do
  local run=C.copy(base);assert(Run.obtainPotion(run,id))
  local ok,why=Run.usePotion(run,1);eq(ok,false);eq(why,'not_in_combat');eq(run.potions[1],id)
 end
end)
test('Ritual and timed Strength loss retain first-application order at the strength cap',function()
 for _,ritualFirst in ipairs({false,true}) do
  local run=battle(ritualFirst and 'cultist_potion' or 'flex_potion');local s=run.combat
  C.addStatus(s.player,'strength',999)
  assert(Run.obtainPotion(run,ritualFirst and 'flex_potion' or 'cultist_potion'))
  assert(Run.usePotion(run,1));assert(Run.usePotion(run,2));assert(Run.endTurn(run))
  eq(s.player.statuses.strength,ritualFirst and 994 or 995)
 end
end)
print('LUA_POTION_SUSTAINED_PASS '..count)
