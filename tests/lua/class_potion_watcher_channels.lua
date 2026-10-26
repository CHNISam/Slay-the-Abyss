package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,D,R,Shop,Nodes,P=require('abyss_run'),require('abyss_combat'),require('abyss_data'),require('abyss_sts_random'),require('abyss_shop'),require('abyss_nodes'),require('abyss_potion_random')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local originalCount=#D.potions.potions
local function fresh(seed)return Run.new(D,seed,{character='watcher',experimental=true})end
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
-- Frozen source oracle first normal drops: only equal-rarity prefix IDs differ.
for _,row in ipairs({{10,'bottled_miracle',3,'b632f75f2fc62855','b11029cf11723fac'},
 {109,'ambrosia',3,'65f84caf5ea1d2f8','7b8e87b97d892be5'}})do
 local r=fresh(row[1]);assert(Run.startCombat(r,'cultist_solo'));win(r)
 eq(r.rewards.potion.id,row[2]);eq(r.rewards.potion.unavailable,false)
 local rng=R.snapshot(r.shopRng.potion);eq(rng.counter,row[3]);eq(rng.words[1],row[4]);eq(rng.words[2],row[5])
 assert(Run.claimPotionReward(r));eq(r.potions[1],row[2]);assert(Run.claimCardReward(r,0));dofile('tests/lua/support/finish_combat_rewards.lua')(r)
 assert(Run.startCombat(r,'cultist_solo'));assert(Run.usePotion(r,1));eq(r.potions[1],nil)
 print('ok unchanged Watcher starter victory -> normal reward -> claim -> next battle uses '..row[2])
end
for _,row in ipairs({{3,3,'bottled_miracle'},{10,3,'ambrosia'}})do
 local r=fresh(row[1]);local flow=Shop.prepare(r);local offer=flow.potions[row[2]]
 eq(offer.id,row[3]);eq(offer.unavailable,false);r.phase='node';flow.type='shop';r.nodeFlow=flow;r.shopRng=flow.shopRng
 for _=1,3 do assert(Run.obtainPotion(r,'block_potion'))end
 local gold,counter=r.gold,r.shopRng.potion.counter;eq(Nodes.buyPotion(r,row[2]),false);eq(r.gold,gold);eq(r.shopRng.potion.counter,counter)
 assert(Run.discardPotion(r,2));assert(Nodes.buyPotion(r,row[2]));eq(r.potions[2],row[3]);eq(r.gold,gold-offer.price);eq(r.shopRng.potion.counter,counter)
 assert(Nodes.leaveShop(r));assert(Run.startCombat(r,'cultist_solo'));assert(Run.usePotion(r,2))
 print('ok normal initial shop obtains and uses '..row[3]..', full-slot failure cannot reroll')
end
local e=fresh(392);assert(Run.obtainPotion(e,'entropic_brew'));assert(Run.startCombat(e,'cultist_solo'));assert(Run.usePotion(e,1))
for i,id in ipairs({'ambrosia','blessing_of_the_forge','bottled_miracle'})do
 eq(e.lastPotionGeneration[i].id,id);eq(e.lastPotionGeneration[i].unavailable,false);eq(e.potions[i],id)
end
local snapshot=R.snapshot(e.shopRng.potion);eq(snapshot.counter,9);eq(snapshot.words[1],'51be2efcb2ee6631');eq(snapshot.words[2],'799e7a611da289b7')
assert(Run.usePotion(e,1));assert(Run.usePotion(e,3))
local missing=fresh(5);assert(Run.obtainPotion(missing,'entropic_brew'));assert(Run.startCombat(missing,'cultist_solo'));assert(Run.usePotion(missing,1))
eq(missing.lastPotionGeneration[2].id,'stance_potion');eq(missing.lastPotionGeneration[2].unavailable,true);eq(missing.shopRng.potion.counter,17)
eq(missing.potions[1],'flex_potion');eq(missing.potions[2],'liquid_bronze');eq(missing.potions[3],nil)
local mother=P.pool('watcher');eq(#mother,33);eq(mother[1].id,'bottled_miracle');eq(mother[2].id,'stance_potion');eq(mother[3].id,'ambrosia')
eq(#D.potions.potions,originalCount)
local native=Run.new(D,42);eq(Run.obtainPotion(native,'bottled_miracle'),false);eq(Run.obtainPotion(native,'ambrosia'),false)
print('CLASS_POTION_WATCHER_CHANNELS_PASS source RNG, full33, honest unsupported Stance, private Watcher directory')
