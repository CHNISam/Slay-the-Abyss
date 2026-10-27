package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,D,R,Shop,Nodes,P=require('abyss_run'),require('abyss_combat'),require('abyss_data'),require('abyss_sts_random'),require('abyss_shop'),require('abyss_nodes'),require('abyss_potion_random')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function fresh(seed)return Run.new(D,seed,{character='watcher',experimental=true})end
local function choose(r,slot,stance)
 assert(Run.usePotion(r,slot));local p=r.combat.pendingPotionChoice;assert(p)
 assert(Run.choosePotionStance(r,{stance},p.token,r.combatGeneration,r.combat));eq(r.combat.player.stance,stance)
end
local r=fresh(28);assert(Run.startCombat(r,'cultist_solo'))
for _=1,100 do
 if r.phase~='combat'then break end
 local uid
 for _,c in ipairs(r.combat.hand)do if C.canPlay(r.combat,c.uid,1)then uid=c.uid;if C.cardDefinition(r.combat,c).type=='attack'then break end end end
 if uid then assert(Run.play(r,uid,1))else assert(Run.endTurn(r))end
end
eq(r.phase,'reward');eq(r.rewards.potion.id,'stance_potion');eq(r.rewards.potion.unavailable,false)
local rng=R.snapshot(r.shopRng.potion);eq(rng.counter,5);eq(rng.words[1],'45dec69647524be4');eq(rng.words[2],'75a8ca6ed2f4625d')
assert(Run.claimPotionReward(r));assert(Run.claimCardReward(r,0));dofile('tests/lua/support/finish_combat_rewards.lua')(r)
assert(Run.startCombat(r,'cultist_solo'));choose(r,1,'Calm')
local shop=fresh(0);local flow=Shop.prepare(shop);local offer=flow.potions[1]
eq(offer.id,'stance_potion');eq(offer.unavailable,false);shop.phase='node';flow.type='shop';shop.nodeFlow=flow;shop.shopRng=flow.shopRng
for _=1,3 do assert(Run.obtainPotion(shop,'block_potion'))end
local gold,counter=shop.gold,shop.shopRng.potion.counter;eq(Nodes.buyPotion(shop,1),false);eq(shop.gold,gold);eq(shop.shopRng.potion.counter,counter)
assert(Run.discardPotion(shop,2));assert(Nodes.buyPotion(shop,1));eq(shop.potions[2],'stance_potion');eq(shop.gold,gold-offer.price);eq(shop.shopRng.potion.counter,counter)
assert(Nodes.leaveShop(shop));assert(Run.startCombat(shop,'cultist_solo'));choose(shop,2,'Wrath')
local e=fresh(5);assert(Run.obtainPotion(e,'entropic_brew'));assert(Run.startCombat(e,'cultist_solo'));assert(Run.usePotion(e,1))
for i,id in ipairs({'flex_potion','stance_potion','liquid_bronze'})do eq(e.potions[i],id);eq(e.lastPotionGeneration[i].id,id);eq(e.lastPotionGeneration[i].unavailable,false)end
local snapshot=R.snapshot(e.shopRng.potion);eq(snapshot.counter,17);eq(snapshot.words[1],'cad8244b09f426c5');eq(snapshot.words[2],'fbe5b9b202d07658')
choose(e,2,'Wrath');eq(#P.pool('watcher'),33);eq(P.pool('watcher')[2].sourceId,'StancePotion')
local native=Run.new(D,42);eq(Run.obtainPotion(native,'stance_potion'),false)
print('CLASS_POTION_STANCE_CHANNELS_PASS real starter reward/shop/Entropic -> typed choice, exact RNG, full33 and Watcher-private dependencies')
