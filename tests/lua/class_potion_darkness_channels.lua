package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,D,R,Shop,Nodes,P=require('abyss_run'),require('abyss_combat'),require('abyss_data'),require('abyss_sts_random'),require('abyss_shop'),require('abyss_nodes'),require('abyss_potion_random')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function fresh(seed)return Run.new(D,seed,{character='defect',experimental=true})end
local r=fresh(109);assert(Run.startCombat(r,'cultist_solo'))
for _=1,100 do
 if r.phase~='combat'then break end
 local uid
 for _,c in ipairs(r.combat.hand)do if C.canPlay(r.combat,c.uid,1)then uid=c.uid;if C.cardDefinition(r.combat,c).type=='attack'then break end end end
 if uid then assert(Run.play(r,uid,1))else assert(Run.endTurn(r))end
end
eq(r.phase,'reward');eq(r.rewards.potion.id,'essence_of_darkness');eq(r.rewards.potion.unavailable,false)
local rng=R.snapshot(r.shopRng.potion);eq(rng.counter,3);eq(rng.words[1],'65f84caf5ea1d2f8');eq(rng.words[2],'7b8e87b97d892be5')
assert(Run.claimPotionReward(r));assert(Run.claimCardReward(r,0));dofile('tests/lua/support/finish_combat_rewards.lua')(r)
assert(Run.startCombat(r,'cultist_solo'));assert(Run.usePotion(r,1));eq(#r.combat.orbs.balls,3)
print('ok actual unchanged Defect starter victory -> rare Darkness drop -> claim -> next battle use, fixed source RNG')
local shop=fresh(10);local flow=Shop.prepare(shop);local offer=flow.potions[3]
eq(offer.id,'essence_of_darkness');eq(offer.unavailable,false);shop.phase='node';flow.type='shop';shop.nodeFlow=flow;shop.shopRng=flow.shopRng
for _=1,3 do assert(Run.obtainPotion(shop,'block_potion'))end
local gold,counter=shop.gold,shop.shopRng.potion.counter;eq(Nodes.buyPotion(shop,3),false);eq(shop.gold,gold);eq(shop.shopRng.potion.counter,counter)
assert(Run.discardPotion(shop,2));assert(Nodes.buyPotion(shop,3));eq(shop.potions[2],'essence_of_darkness');eq(shop.gold,gold-offer.price);eq(shop.shopRng.potion.counter,counter)
assert(Nodes.leaveShop(shop));assert(Run.startCombat(shop,'cultist_solo'));assert(Run.usePotion(shop,2))
print('ok source initial shop Darkness purchase and use, full-slot rejection cannot reroll')
local e=fresh(392);assert(Run.obtainPotion(e,'entropic_brew'));assert(Run.startCombat(e,'cultist_solo'));assert(Run.usePotion(e,1))
for i,id in ipairs({'essence_of_darkness','blessing_of_the_forge','focus_potion'})do
 eq(e.lastPotionGeneration[i].id,id);eq(e.lastPotionGeneration[i].unavailable,false);eq(e.potions[i],id)
end
local snapshot=R.snapshot(e.shopRng.potion);eq(snapshot.counter,9);eq(snapshot.words[1],'51be2efcb2ee6631');eq(snapshot.words[2],'799e7a611da289b7')
assert(Run.usePotion(e,3));assert(Run.usePotion(e,1));eq(e.combat.player.statuses.focus,2);eq(#e.combat.orbs.balls,3)
local mother=P.pool('defect');eq(#mother,33);eq(mother[3].id,'essence_of_darkness');eq(#P.pool('watcher'),33);eq(P.pool('watcher')[2].id,'stance_potion')
local w=Run.new(D,42,{character='watcher',experimental=true});eq(Run.obtainPotion(w,'stance_potion'),true)
print('CLASS_POTION_DARKNESS_CHANNELS_PASS Entropic actual acquisition/use, exact RNG, full33 and real Stance available')
