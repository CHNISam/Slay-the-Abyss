package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,A,Data=require('abyss_run'),require('abyss_combat'),require('abyss_actor'),require('abyss_data')
local passed,failed=0,0
local function test(name,fn)local ok,why=pcall(fn);if ok then passed=passed+1;print('PASS '..name)else failed=failed+1;print('FAIL '..name..': '..tostring(why))end end
local function battle(card)
 local r=Run.new(Data,42);assert(Run.obtainPotion(r,'duplication_potion'));assert(Run.startCombat(r,'cultist_solo'))
 local s=r.combat;s.hand={{cardId=card,uid=4001}};s.draw={};s.discard={};s.enemies[1].hp=1000;s.enemies[1].maxHp=1000
 assert(Run.usePotion(r,1));return r,s
end
test('Duplication repeats one ordinary attack exactly once and disposes only the real card',function()
 local r,s=battle('strike');assert(Run.play(r,4001,1))
 assert(s.enemies[1].hp==988 and s.energy==2 and #s.discard==1 and #s.exhaust==0)
 assert((s.player.statuses.duplication or 0)==0 and not s.queuedCards)
end)
test('Duplication repeats Skills and Powers without recursive consumption or exhausting a Power',function()
 for _,id in ipairs({'defend','inflame'}) do
  local r,s=battle(id);assert(Run.play(r,4001))
  assert((s.player.statuses.duplication or 0)==0)
  if id=='defend' then assert(s.player.block==10 and #s.discard==1) else assert(s.player.statuses.strength==4 and #s.discard==0 and #s.exhaust==0) end
 end
end)
test('Duplication and DoubleTap independently add one replay without multiplying each other',function()
 local r,s=battle('strike');A.applyPower(s,s.player,'double_tap',1,s.player)
 assert(Run.play(r,4001,1));assert(s.enemies[1].hp==982 and s.energy==2 and #s.discard==1)
 assert((s.player.statuses.duplication or 0)==0 and (s.player.statuses.double_tap or 0)==0)
end)
test('Duplication copies energyOnUse for Whirlwind and charges energy only once',function()
 local r,s=battle('whirlwind');assert(Run.play(r,4001));assert(s.energy==0 and s.enemies[1].hp==970 and #s.discard==1)
end)
test('unused Duplication loses one at enemy round end, not all stacks at player owner end',function()
 local r,s=battle('defend');assert(Run.obtainPotion(r,'duplication_potion'));assert(Run.usePotion(r,1))
 assert(s.player.statuses.duplication==2);assert(Run.endTurn(r));assert(s.player.statuses.duplication==1)
 assert(Run.endTurn(r));assert((s.player.statuses.duplication or 0)==0)
end)
test('Duplication final kill clears queued replay and leaves one real discard',function()
 local r,s=battle('strike');s.enemies[1].hp=1;assert(Run.play(r,4001,1))
 assert(r.phase=='reward' and #s.discard==1 and not s.queuedCards and not s.cardActions)
end)
test('invalid original card use preserves Duplication stock and card identity',function()
 local r,s=battle('bash');s.energy=0;local card=s.hand[1]
 local ok,why=Run.play(r,4001,1);assert(not ok and why=='insufficient_energy')
 assert(s.hand[1]==card and s.player.statuses.duplication==1 and not s.queuedCards)
end)
test('late original rule failure restores consumed Duplication stock and original instance',function()
 local r,s=battle('strike');local card=s.hand[1];local hp,energy=s.enemies[1].hp,s.energy
 s.catalog.cards.strike.effects[#s.catalog.cards.strike.effects+1]={op='gainStatus',status='invalid_rule_fixture',value=1}
 local ok=pcall(Run.play,r,4001,1);assert(not ok)
 assert(s.player.statuses.duplication==1 and s.hand[1]==card and s.enemies[1].hp==hp and s.energy==energy)
 assert(not s.cardActions and not s.queuedCards)
end)
print('LUA_POTION_DUPLICATION '..passed..' passed '..failed..' failed');assert(failed==0)
