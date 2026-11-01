package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,P,D,A=require('abyss_combat'),require('abyss_character_profiles'),require('abyss_data'),require('abyss_card_actions')
-- Real fixed-source definitions in one controlled mixed-card combat. This
-- tests shared payment semantics, not the pending all-colour acquisition task.
local data=P.prepare(D,'watcher')
for _,card in ipairs(P.prepare(D,'ironclad').cards.cards)do if card.id=='whirlwind'then data.cards.cards[#data.cards.cards+1]=C.copy(card)end end
local function setup(up)
 local s=C.new(data,{deck={'swivel','whirlwind'},enemies={'jaw_worm'},seed=42,enableStances=true,cardRandomSeed='17'})
 local cards={};for _,c in ipairs(s.hand)do cards[c.cardId]=c end;cards.whirlwind.upgraded=up
 return s,cards
end
local failed=0
local function test(name,fn)local ok,why=pcall(fn);if not ok then failed=failed+1 end;print((ok and 'PASS 'or 'FAIL ')..name..(ok and ''or ': '..tostring(why)))end
for _,up in ipairs({false,true})do
 local suffix=up and '+'or ''
 local damage=up and 8 or 5
 test('ordinary Whirlwind'..suffix..' spends all current energy for its captured X',function()
  local s,c=setup(up);s.energy=3;local hp=s.enemies[1].hp
  assert(C.play(s,c.whirlwind.uid,1));assert(s.energy==0 and hp-s.enemies[1].hp==3*damage)
 end)
 test('Swivel then Whirlwind'..suffix..' still spends X energy',function()
  local s,c=setup(up);s.energy=5;assert(C.play(s,c.swivel.uid));assert(s.energy==3)
  local hp=s.enemies[1].hp;assert(C.play(s,c.whirlwind.uid,1))
  assert(s.energy==0,'Swivel must not suppress WhirlwindAction energy use')
  assert(hp-s.enemies[1].hp==3*damage and not s.player.statuses.free_attack)
 end)
 test('freeToPlayOnce Whirlwind'..suffix..' preserves energy and clears its physical one-shot flag',function()
  local s,c=setup(up);s.energy=3;c.whirlwind.freeToPlayOnce=true;local hp=s.enemies[1].hp
  assert(C.play(s,c.whirlwind.uid,1));assert(s.energy==3,'explicit freeToPlayOnce must suppress X payment')
  assert(hp-s.enemies[1].hp==3*damage and not c.whirlwind.freeToPlayOnce)
 end)
 test('Swivel plus freeToPlayOnce Whirlwind'..suffix..' honors the explicit free flag',function()
  local s,c=setup(up);s.energy=5;assert(C.play(s,c.swivel.uid));c.whirlwind.freeToPlayOnce=true
  local hp=s.enemies[1].hp;assert(C.play(s,c.whirlwind.uid,1));assert(s.energy==3 and hp-s.enemies[1].hp==3*damage)
  assert(not s.player.statuses.free_attack and not c.whirlwind.freeToPlayOnce)
 end)
 test('automatic Whirlwind'..suffix..' preserves live energy and uses its separate captured X',function()
  local s,c=setup(up);s.energy=5;assert(C.play(s,c.swivel.uid));s.energy=5;s.hand={};local hp=s.enemies[1].hp
  C.queueCard(s,c.whirlwind,{append=true,targetIndex=1,purge=false,exhaustCards=false,energyOnUse=2});A.drain(C,s)
  assert(s.energy==5 and hp-s.enemies[1].hp==2*damage and not s.player.statuses.free_attack)
  assert(#s.discard==2 and s.discard[2]==c.whirlwind and not s.cardInUse and not s.actionQueue)
 end)
end
assert(failed==0,tostring(failed)..' free attack X regressions failed')
print('FREE_ATTACK_X_PASS Swivel versus explicit free/automatic X payment, base/upgraded snapshots and disposal')
