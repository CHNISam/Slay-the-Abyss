package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Shop=require('abyss_shop_relics')
local C,R=require('abyss_combat'),require('abyss_run')
local A,Actions=require('abyss_actor'),require('abyss_card_actions')
local Random=require('abyss_sts_random')
local data=require('abyss_data')
local n=0
local function test(name,f)f();n=n+1;print('PASS '..name)end
local function battle(ids)
 local run=R.new(data,42);assert(R.startCombat(run,'cultist_solo'))
 local s=run.combat;s.relics=ids;s.shopRelicCombat={};return s
end
test('source aliases and owners are exact',function()
 for source,id in pairs(Shop.aliases)do assert(Shop.owns({relics={source}},id))end
 assert(not Shop.owns({relics={'chemical_x'}},'sling'))
end)
test('Sling only grants elite strength and Clockwork grants artifact',function()
 local s=battle({'Sling','clockwork_souvenir'})
 assert(#Shop.battleStartActions(s,{eliteTrigger=false})==1)
 local effects=Shop.battleStartActions(s,{eliteTrigger=true});assert(#effects==2)
 for _,e in ipairs(effects)do A.applyPower(s,s.player,e.status,e.value,s.player)end
 assert(s.player.statuses.strength==2 and s.player.statuses.artifact==1)
end)
test('Hand Drill queues actual vulnerable and respects Artifact',function()
 local s=battle({'hand_drill'});local enemy=s.enemies[1]
 Shop.onBlockBroken(s,enemy);assert(#s.cardActions==1)
 Shop.execute(s,s.cardActions[1].effect);assert(enemy.statuses.vulnerable==2)
 A.applyPower(s,enemy,'artifact',1,enemy)
 Shop.execute(s,s.cardActions[1].effect);assert(enemy.statuses.vulnerable==2 and enemy.statuses.artifact==0)
 Shop.onBlockBroken(s,s.player);assert(#s.cardActions==1)
end)
test('Abacus fixed block ignores dexterity and frail',function()
 local s=battle({'the_abacus'});A.addStatus(s.player,'dexterity',9);A.addStatus(s.player,'frail',2)
 Shop.onShuffle(s);local e=s.cardActions[1].effect
 A.block(s,s.player,e.value,e.fixed);assert(s.player.block==6)
end)
test('Chemical X, Medical Kit and Frozen Eye preserve unrelated cards',function()
 local s=battle({'chemical_x','medical_kit','frozen_eye'})
 assert(Shop.xBonus(s)==2 and Shop.drawOrderVisible(s))
 local d={type='status',cost=-2,exhaust=false};local actual=Shop.medicalCard(s,d)
 assert(actual.cost==0 and actual.exhaust and d.cost==-2 and not d.exhaust)
 local attack={type='attack',cost=1};assert(Shop.medicalCard(s,attack)==attack)
 local slime=Shop.medicalCard(s,{type='status',cost=1});assert(slime.cost==1 and slime.exhaust)
end)
test('Spoon consumes one source boolean at disposal only',function()
 local s=battle({'strange_spoon'});s.cardRandomRng=Random.fromSeed('912')
 local oracle=Random.cloneState(s.cardRandomRng)
 for _=1,20 do
  assert(Shop.exhaustAfterUse(s,{type='skill'},true,false)==not Random.randomBoolean(oracle))
 end
 assert(Random.snapshot(s.cardRandomRng).counter==Random.snapshot(oracle).counter)
 local before=Random.snapshot(s.cardRandomRng).counter
 assert(Shop.exhaustAfterUse(s,{type='power'},true,false))
 assert(not Shop.exhaustAfterUse(s,{type='skill'},false,false))
 assert(Shop.exhaustAfterUse(s,{type='skill'},true,true))
 assert(Random.snapshot(s.cardRandomRng).counter==before)
end)
test('Orange Pellets removes debuffs but retains positive strength',function()
 local s=battle({'orange_pellets'});local p=s.player
 A.applyPower(s,p,'weak',2,p);A.applyPower(s,p,'strength',3,p)
 Shop.turnStartActions(s)
 Shop.onUseCard(s,{type='attack'});Shop.onUseCard(s,{type='skill'});assert(not s.cardActions)
 Shop.onUseCard(s,{type='power'});assert(#s.cardActions==1)
 Shop.execute(s,s.cardActions[1].effect);assert(p.statuses.weak==nil and p.statuses.strength==3)
 Shop.onUseCard(s,{type='power'});assert(#s.cardActions==1)
 Shop.onUseCard(s,{type='attack'});Shop.onUseCard(s,{type='skill'});assert(#s.cardActions==2)
end)
test('Brimstone grants both sides strength each turn',function()
 local s=battle({'brimstone'})
 for _=1,2 do for _,e in ipairs(Shop.turnStartActions(s))do
  local target=e.targetId and s.enemies[1]or s.player
  A.applyPower(s,target,e.status,e.value,target)
 end end
 assert(s.player.statuses.strength==4 and s.enemies[1].statuses.strength==2)
end)
test('Toolbox offers three distinct source cards and preserves real costs',function()
 local s=battle({'toolbox'});Shop.beginToolbox(C,s)
 local p=s.pendingChoice;local seen={}
 for _,c in ipairs(p.cards)do assert(not seen[c.cardId]);seen[c.cardId]=true end
 local chosen=p.cards[1].cardId;local count=#s.hand+#s.discard
 assert(not Shop.chooseToolbox(C,s,p.token+1,1,Actions))
 assert(Shop.chooseToolbox(C,s,p.token,1,Actions));assert(not s.pendingChoice)
 assert(#s.hand+#s.discard==count+1)
 local added=s.hand[#s.hand].cardId==chosen and s.hand[#s.hand]or s.discard[#s.discard]
 assert(added.cardId==chosen and added.costForTurn==nil)
 assert(not Shop.chooseToolbox(C,s,p.token,1,Actions))
end)
test('Battle Trance attack and power clear real NoDraw and permit subsequent draw',function()
 local s=C.new(data,{seed=42,deck={'battle_trance','strike','inflame','defend','defend','defend','defend','defend','defend','defend'},enemies={'cultist'}})
 s.relics={'orange_pellets'};s.shopRelicCombat={}
 local cards={};for _,pile in ipairs({s.hand,s.draw,s.discard})do for _,c in ipairs(pile)do cards[#cards+1]=c end end
 s.hand={};s.draw={};s.discard={};local uid={}
 for _,c in ipairs(cards)do
  if c.cardId=='battle_trance'or c.cardId=='strike'or c.cardId=='inflame'then
   s.hand[#s.hand+1]=c;uid[c.cardId]=c.uid
  else s.draw[#s.draw+1]=c end
 end
 assert(C.play(s,uid.battle_trance));assert(s.player.noDraw)
 assert(C.play(s,uid.strike,1));assert(s.player.noDraw)
 assert(C.play(s,uid.inflame));assert(not s.player.noDraw)
 for _,id in ipairs(s.player.powerOrder)do assert(id~='no_draw')end
 for _,entry in ipairs(s.player.powerScheduleOrder or {})do assert(entry.id~='no_draw')end
 local before=#s.hand;C.draw(s,1);assert(#s.hand==before+1)
 assert(not C.play(s,uid.inflame));assert(not s.player.noDraw)
end)
test('Pellets removal precedes already queued draw and late execution is idempotent',function()
 local s=battle({'orange_pellets'});assert(A.applyNoDraw(s,s.player))
 Actions.enqueue(s,{op='shopRelic',kind='pellets'})
 Actions.enqueue(s,{op='draw',value=1})
 local before=#s.hand;Actions.drain(C,s)
 assert(not s.player.noDraw and #s.hand==before+1)
 local count=#s.player.powerOrder;Shop.execute(s,{kind='pellets'})
 assert(#s.player.powerOrder==count and #s.hand==before+1)
end)
test('queued Pellets never removes Powers from a dead owner',function()
 local s=battle({'orange_pellets'});assert(A.applyNoDraw(s,s.player))
 A.applyPower(s,s.player,'weak',2,s.player);s.player.hp=0
 Shop.execute(s,{kind='pellets'})
 assert(s.player.noDraw and s.player.statuses.weak==2)
end)
print('LUA_SHOP_RELIC_EFFECTS_PASS '..n)
