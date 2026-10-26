package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,D,R,Shop,Nodes,P=require('abyss_run'),require('abyss_combat'),require('abyss_data'),require('abyss_sts_random'),require('abyss_shop'),require('abyss_nodes'),require('abyss_potion_random')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local originalCount=#D.potions.potions
local function fresh(seed)return Run.new(D,seed,{character='defect',experimental=true})end
local function win(r)
 for _=1,100 do
  if r.phase~='combat'then break end
  local uid
  for _,c in ipairs(r.combat.hand)do if C.canPlay(r.combat,c.uid,1)then
   uid=c.uid;if C.cardDefinition(r.combat,c).type=='attack'then break end
  end end
  if uid then assert(Run.play(r,uid,1))else assert(Run.endTurn(r))end
 end
 eq(r.phase,'reward')
end
-- Independent frozen Ironclad oracle rows10/28 keep their draw words when only
-- the first source identity is replaced with the same-rarity Defect identity.
for _,row in ipairs({{10,'focus_potion',3,'b632f75f2fc62855','b11029cf11723fac'},
 {28,'potion_of_capacity',5,'45dec69647524be4','75a8ca6ed2f4625d'}})do
 local r=fresh(row[1]);assert(Run.startCombat(r,'cultist_solo'));win(r)
 eq(r.rewards.potion.id,row[2]);eq(r.rewards.potion.unavailable,false)
 local rng=R.snapshot(r.shopRng.potion);eq(rng.counter,row[3]);eq(rng.words[1],row[4]);eq(rng.words[2],row[5])
 assert(Run.claimPotionReward(r));eq(r.potions[1],row[2]);assert(Run.claimCardReward(r,0));dofile('tests/lua/support/finish_combat_rewards.lua')(r)
 assert(Run.startCombat(r,'cultist_solo'));assert(Run.usePotion(r,1));eq(r.potions[1],nil)
 print('ok unchanged real starter combat rewards, claims, carries and uses '..row[2])
end
for _,row in ipairs({{3,3,'focus_potion'},{0,1,'potion_of_capacity'}})do
 local r=fresh(row[1]);local flow=Shop.prepare(r);local offer=flow.potions[row[2]]
 eq(offer.id,row[3]);eq(offer.unavailable,false);r.phase='node';flow.type='shop';r.nodeFlow=flow;r.shopRng=flow.shopRng
 for _=1,3 do assert(Run.obtainPotion(r,'block_potion'))end
 local gold,counter=r.gold,r.shopRng.potion.counter;eq(Nodes.buyPotion(r,row[2]),false);eq(r.gold,gold);eq(r.shopRng.potion.counter,counter)
 assert(Run.discardPotion(r,2));assert(Nodes.buyPotion(r,row[2]));eq(r.potions[2],row[3]);eq(r.gold,gold-offer.price);eq(r.shopRng.potion.counter,counter)
 assert(Nodes.leaveShop(r));assert(Run.startCombat(r,'cultist_solo'));assert(Run.usePotion(r,2))
 print('ok normal initial shop buys and uses '..row[3]..' without full-slot reroll')
end
local e=fresh(9);assert(Run.obtainPotion(e,'entropic_brew'));assert(Run.startCombat(e,'cultist_solo'));assert(Run.usePotion(e,1))
local expected={'focus_potion','potion_of_capacity','ancient_potion'}
for i,id in ipairs(expected)do eq(e.lastPotionGeneration[i].id,id);eq(e.lastPotionGeneration[i].unavailable,false);eq(e.potions[i],id)end
eq(e.shopRng.potion.counter,14);assert(Run.usePotion(e,1));assert(Run.usePotion(e,2))
local mother=P.pool('defect');eq(#mother,33);eq(mother[1].id,'focus_potion');eq(mother[2].id,'potion_of_capacity');eq(mother[3].id,'essence_of_darkness')
local missing=false;for _,p in ipairs(e.data.potions.potions)do if p.id=='essence_of_darkness'then missing=true end end;eq(missing,false)
eq(#D.potions.potions,originalCount)
print('CLASS_POTION_CHANNELS_PASS full33 mother, actual Entropic obtains/uses, missing Darkness retained, caller data unchanged')
