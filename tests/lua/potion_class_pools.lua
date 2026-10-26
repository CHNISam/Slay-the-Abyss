package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local P,R,Rewards,Shop,Generation,Run,Data=require('abyss_potion_random'),require('abyss_sts_random'),require('abyss_potion_rewards'),require('abyss_shop'),require('abyss_potion_generation'),require('abyss_run'),require('abyss_data')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local prefixes={ironclad={'BloodPotion','ElixirPotion','HeartOfIron'},silent={'Poison Potion','CunningPotion','GhostInAJar'},
 defect={'FocusPotion','PotionOfCapacity','EssenceOfDarkness'},watcher={'BottledMiracle','StancePotion','Ambrosia'}}
for character,source in pairs(prefixes)do
 local pool=P.pool(character);eq(#pool,33)
 for i=1,3 do eq(pool[i].sourceId,source[i])end
 -- Hand-derived XS128 state(0,index) yields index as the next 0..32 draw.
 for index=0,2 do
  local owner=P.restore({version=1,potionRng={words={'0000000000000000',string.format('%016x',index)},counter=0}})
  local result=P.sample(owner,{character=character,rarity=pool[index+1].rarity})
  eq(result.sourceId,source[index+1]);eq(result.attempts[1],index)
 end
end
eq(#P.pool('shared'),30);eq(P.pool('shared')[1].sourceId,'Block Potion')
for character,source in pairs(prefixes)do
 for _,row in ipairs({{3,3,1},{0,1,2},{10,3,3}})do
  local r=Run.new(Data,row[1]);r.character=character
  local selected=Shop.prepare(r).potions[row[2]];local pool=P.pool(character)
  eq(selected.id,pool[row[3]].id)
 end
 local r=Run.new(Data,0);r.character=character
 local ids,rng=Generation.prepare(r,false);local owner=P.new(r.runSeed)
 for _,id in ipairs(ids)do eq(id,P.sample(owner,{character=character}).id)end
 eq(rng.counter,owner.potionRng.counter)
end
local plain=Run.new(Data,42);eq(P.character(plain),'ironclad')
for _,role in ipairs({'hutao','arlecchino','furina','raiden'})do
 eq(P.character({character=role,characterProfile={originalV4=true}}),'shared')
end
assert(not pcall(P.character,{character='silnet'}));assert(not pcall(P.pool,'silnet'))
assert(not pcall(P.character,{character=false}));assert(not pcall(P.pool,false))
-- Poison remains an actual supported Silent reward. The missing other-class
-- definitions must preserve their identity as unavailable instead of rerolling.
for _,character in ipairs({'silent','defect','watcher'})do
 local r=Run.new(Data,42);r.character=character;local seen={}
 for _=1,1000 do
  local offer,rng,modifier=Rewards.prepare(r,2);Rewards.commit(r,rng,modifier)
  if offer then seen[offer.sourceId]=offer end
 end
 for _,id in ipairs(prefixes[character])do assert(seen[id],character..' '..id)end
 assert(not seen.BloodPotion and not seen.ElixirPotion and not seen.HeartOfIron)
 if character=='silent'then eq(seen['Poison Potion'].unavailable,false)else eq(seen[prefixes[character][1]].unavailable,true)end
end
print('LUA_POTION_CLASS_POOLS_PASS 4+shared')
