package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,R=require('abyss_run'),require('abyss_combat'),require('abyss_sts_random')
local D=require('abyss_data');local P=require('abyss_potion_text');local B=require('abyss_battle_potion_view')
local count,failed=0,0
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function test(name,fn)local ok,why=pcall(fn);if ok then count=count+1;print('PASS Bark '..name)else failed=failed+1;print('FAIL Bark '..name..': '..tostring(why))end end
local function fresh(potion,character)
 local run=Run.new(D,42,character and {character=character,experimental=true}or nil)
 assert(Run.obtainRelic(run,'SacredBark'));if potion then assert(Run.obtainPotion(run,potion))end
 return run
end
local function battle(potion,character)
 local r=fresh(potion,character);assert(Run.startCombat(r,'cultist_solo'))
 r.combat.enemies[1].hp,r.combat.enemies[1].maxHp=500,500;return r,r.combat
end
test('basic battle and shop wording reflect the held potency without changing source definitions',function()
 local run=Run.new(D,42);local definition
 for _,p in ipairs(run.data.potions.potions)do if p.id=='fire_potion'then definition=p end end
 local owner={data=run.data,relics={'SacredBark'}}
 assert(P.describe(owner,'fire_potion'):find('40',1,true),'shop text retained base Fire damage')
 assert(B.potionText(definition,owner,true):find('40',1,true),'battle detail retained base Fire damage')
 eq(definition.effects[1].value,20)
end)
test('actual obtained Bark doubles damage block energy and ordinary statuses once',function()
 local cases={{'fire_potion','enemyHp',460},{'block_potion','block',24},{'energy_potion','energy',7},
  {'strength_potion','strength',4},{'dexterity_potion','dexterity',4},{'poison_potion','poison',12},
  {'weak_potion','weak',6},{'fear_potion','vulnerable',6},{'regen_potion','regen',10},
  {'ancient_potion','artifact',2},{'liquid_bronze','thorns',6},{'duplication_potion','duplication',2},
  {'heart_of_iron','metallicize',12},{'essence_of_steel','plated_armor',8},{'cultist_potion','ritual',2},
  {'flex_potion','strength',10},{'speed_potion','dexterity',10}}
 for _,case in ipairs(cases)do
  local r,b=battle(case[1]);assert(Run.usePotion(r,1,1));eq(r.potions[1],nil)
  local actual=case[2]=='enemyHp'and b.enemies[1].hp or case[2]=='energy'and b.energy or case[2]=='block'and b.player.block
   or b.player.statuses[case[2]]or b.enemies[1].statuses[case[2]]
  eq(actual,case[3])
 end
end)
test('outside and battle health doses and automatic Fairy use true doubled potency',function()
 for _,inside in ipairs({false,true})do for _,case in ipairs({{'blood_potion',42,80},{'fruit_juice',20,90}})do
  local r=fresh(case[1]);r.hp=10;if inside then assert(Run.startCombat(r,'cultist_solo'))end
  assert(Run.usePotion(r,1));eq(r.hp,case[2]);eq(r.maxHp,case[3]);eq(r.potions[1],nil)
 end end
 local r,b=battle('fairy_in_a_bottle');b.player.hp,b.player.maxHp=1,83
 C.damage(b,b.enemies[1],b.player,99,true);eq(b.player.hp,49);eq(b.potionInventory[1],nil)
end)
test('Discovery duplicates selected card while its three candidates and RNG count stay unchanged',function()
 local r,b=battle('attack_potion');local plain=Run.new(D,42);assert(Run.obtainPotion(plain,'attack_potion'));assert(Run.startCombat(plain,'cultist_solo'))
 assert(Run.usePotion(plain,1));assert(Run.usePotion(r,1));local request=b.pendingChoice;eq(#request.cards,3)
 for i,c in ipairs(request.cards)do eq(c.cardId,plain.combat.pendingChoice.cards[i].cardId)end
 eq(R.snapshot(b.cardRandomRng).counter,R.snapshot(plain.combat.cardRandomRng).counter)
 local uid=b.nextUid;assert(Run.chooseCard(r,request.token,1));eq(b.nextUid,uid+2)
end)
test('Entropic Brew still samples once per total slot and preserves exact source draws',function()
 local bark=fresh('entropic_brew');local plain=Run.new(D,42);assert(Run.obtainPotion(plain,'entropic_brew'))
 assert(Run.usePotion(bark,1));assert(Run.usePotion(plain,1));eq(#bark.lastPotionGeneration,Run.potionCapacity(bark))
 for i,v in ipairs(bark.lastPotionGeneration)do eq(v.id,plain.lastPotionGeneration[i].id)end
 eq(R.snapshot(bark.shopRng.potion).counter,R.snapshot(plain.shopRng.potion).counter)
end)
test('Forge upgrades each card once and Smoke remains one escape action',function()
 local r,b=battle('blessing_of_the_forge');b.hand={{uid=999,cardId='searing_blow',upgraded=false}}
 assert(Run.usePotion(r,1));eq(b.hand[1].upgrades,1)
 local smoke=fresh('smoke_bomb');assert(Run.startCombat(smoke,'cultist_solo'));assert(Run.usePotion(smoke,1));eq(smoke.phase,'map');eq(smoke.potions[1],nil)
end)
assert(failed==0,tostring(failed)..' Sacred Bark potion regressions failed')
print('SACRED_BARK_POTIONS_PASS '..count)
