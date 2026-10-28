package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local H,C,R,S=require('abyss_relic_hooks'),require('abyss_combat'),require('abyss_run'),require('abyss_sts_random')
local data=require('abyss_data')
local n=0
local function test(name,f)f();n=n+1;print('PASS '..name)end
test('Strawberry raises current and max HP by seven on equipment',function()
 local r=R.new(data,42);r.hp=30;H.onEquip(r,'strawberry');assert(r.hp==37 and r.maxHp==87)
end)
test('RegalPillow adds fifteen only to rest recovery; healing still clamps at max',function()
 local r=R.new(data,42);r.relics={'regal_pillow'}
 assert(H.campHealAmount(r,24)==39);assert(H.campHealAmount(r,0)==15)
 r.relics={};assert(H.campHealAmount(r,24)==24)
end)
test('ToyOrnithopter heals five in current battle and in noncombat, clamped',function()
 local r=R.new(data,42);r.relics={'toy_ornithopter'};r.hp=30
 assert(R.startCombat(r,'cultist_solo'));H.onUsePotion(r,r.combat);assert(r.combat.player.hp==30)
 require('abyss_card_actions').drain(C,r.combat);assert(r.combat.player.hp==35 and r.hp==30)
 r.combat.player.hp=79;H.onUsePotion(r,r.combat);require('abyss_card_actions').drain(C,r.combat);assert(r.combat.player.hp==80)
 r.phase='map';H.onUsePotion(r);assert(r.hp==35)
 r.relics={};H.onUsePotion(r);assert(r.hp==35)
end)
test('Whetstone and WarPaint shuffle eligible cards using one misc long and upgrade two original identities',function()
 for _,spec in ipairs({{'whetstone','attack'},{'war_paint','skill'}})do
  local r=R.new(data,42);local before=S.snapshot(r.miscRng);local candidates={}
  for _,card in ipairs(r.deck)do
   local def=C.cardDefinition({catalog={cards=(function()local t={}for _,d in ipairs(data.cards.cards)do t[d.id]=d end;return t end)()}},card)
   if def.type==spec[2]then candidates[#candidates+1]=card end
  end
  local rng=S.restore(before);S.shuffle(rng,candidates)
  local first,second=candidates[1],candidates[2];H.onEquip(r,spec[1])
  assert(first.upgraded and second.upgraded and r.miscRng.counter==before.counter+1)
  local upgraded=0;for _,card in ipairs(r.deck)do if card.upgraded then upgraded=upgraded+1 end end;assert(upgraded==2)
  assert(S.randomLongHex(rng)==S.randomLongHex(r.miscRng))
 end
end)
test('empty/singleton equipment upgrades still consume one shuffle seed and never upgrade wrong types',function()
 local r=R.new(data,42);r.deck={{uid=1,cardId='bash',upgraded=false}}
 local before=r.miscRng.counter;H.onEquip(r,'war_paint');assert(not r.deck[1].upgraded and r.miscRng.counter==before+1)
 H.onEquip(r,'whetstone');assert(r.deck[1].upgraded and r.miscRng.counter==before+2)
end)
test('equipment upgrade callback preserves repeatable card semantics and bottled identity',function()
 local r=R.new(data,42);r.deck={{uid=7,cardId='bash',upgraded=true,upgradeCount=4}};local original=r.deck[1];local seen
 H.onEquip(r,'whetstone',{canUpgrade=function(card)return card.uid==7 end,upgrade=function(card)
  seen=card;card.upgradeCount=card.upgradeCount+1
 end})
 assert(seen==original and original.upgradeCount==5)
end)
print('LUA_COMMON_RELIC_EQUIPMENT_PASS '..n)
