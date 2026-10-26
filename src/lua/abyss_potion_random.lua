-- Fixed 319009d5 Ironclad pool sampler. No effects, awards or gameplay wiring.
-- IDs/order are the full33 catalog; existing availability never filters draws.
local R=require('abyss_sts_random')
local M={}
local pool={
 {'BloodPotion','blood_potion','common'},
 {'ElixirPotion','elixir','uncommon'},
 {'HeartOfIron','heart_of_iron','rare'},
 {'Block Potion','block_potion','common'},
 {'Dexterity Potion','dexterity_potion','common'},
 {'Energy Potion','energy_potion','common'},
 {'Explosive Potion','explosive_potion','common'},
 {'Fire Potion','fire_potion','common'},
 {'Strength Potion','strength_potion','common'},
 {'Swift Potion','swift_potion','common'},
 {'Weak Potion','weak_potion','common'},
 {'FearPotion','fear_potion','common'},
 {'AttackPotion','attack_potion','common'},
 {'SkillPotion','skill_potion','common'},
 {'PowerPotion','power_potion','common'},
 {'ColorlessPotion','colorless_potion','common'},
 {'SteroidPotion','flex_potion','common'},
 {'SpeedPotion','speed_potion','common'},
 {'BlessingOfTheForge','blessing_of_the_forge','common'},
 {'Regen Potion','regen_potion','uncommon'},
 {'Ancient Potion','ancient_potion','uncommon'},
 {'LiquidBronze','liquid_bronze','uncommon'},
 {'GamblersBrew','gamblers_brew','uncommon'},
 {'EssenceOfSteel','essence_of_steel','uncommon'},
 {'DuplicationPotion','duplication_potion','uncommon'},
 {'DistilledChaos','distilled_chaos','uncommon'},
 {'LiquidMemories','liquid_memories','uncommon'},
 {'CultistPotion','cultist_potion','rare'},
 {'Fruit Juice','fruit_juice','rare'},
 {'SneckoOil','snecko_oil','rare'},
 {'FairyPotion','fairy_in_a_bottle','rare'},
 {'SmokeBomb','smoke_bomb','rare'},
 {'EntropicBrew','entropic_brew','rare'},
}
local rarities={common=true,uncommon=true,rare=true}
local function validate(owner)
 assert(type(owner)=='table' and getmetatable(owner)==nil,'Expected plain potion RNG owner')
 R.snapshot(owner.potionRng)
end
function M.new(seed,...)
 assert(select('#',...)==0,'Unexpected potion owner arguments')
 return {potionRng=R.fromSeed(seed)}
end
function M.snapshot(owner)
 validate(owner);return {version=1,potionRng=R.snapshot(owner.potionRng)}
end
function M.restore(snapshot)
 assert(type(snapshot)=='table' and getmetatable(snapshot)==nil,'Expected plain potion RNG snapshot')
 for key in pairs(snapshot)do assert(key=='version' or key=='potionRng','Unexpected potion snapshot field')end
 assert(snapshot.version==1,'Invalid potion snapshot version')
 return {potionRng=R.restore(snapshot.potionRng)}
end
function M.clone(owner)return M.restore(M.snapshot(owner))end
function M.commit(owner,prepared,...)
 assert(select('#',...)==0,'Unexpected potion commit arguments')
 validate(owner);validate(prepared)
 -- Publish an independent value, leaving a retained prepared owner detached.
 owner.potionRng=R.cloneState(prepared.potionRng)
end
function M.rarity(roll)
 assert(type(roll)=='number' and roll%1==0 and roll>=0 and roll<=99,'Invalid potion rarity roll')
 return roll<65 and 'common' or roll<90 and 'uncommon' or 'rare'
end
local function descriptor(index,attempts)
 local entry=pool[index+1]
 return {sourceId=entry[1],id=entry[2],rarity=entry[3],sourceIndex=index,attempts=attempts}
end
function M.pool()
 local result={}
 for i=1,#pool do local row=descriptor(i-1);result[i]=row end
 return result
end
function M.sample(owner,options,...)
 assert(select('#',...)==0,'Unexpected potion sample arguments')
 if options==nil then options={}end
 assert(type(options)=='table' and getmetatable(options)==nil,'Expected plain potion sample options')
 for key in pairs(options)do assert(key=='rarity' or key=='limited','Unexpected potion sample option')end
 assert(options.rarity==nil or rarities[options.rarity],'Invalid explicit potion rarity')
 assert(options.limited==nil or type(options.limited)=='boolean','Invalid limited potion flag')
 validate(owner)
 local wanted=options.rarity or M.rarity(R.randomIntBetween(owner.potionRng,0,99))
 local attempts={}
 local function candidate()
  local index=R.randomIntBetween(owner.potionRng,0,#pool-1)
  attempts[#attempts+1]=index;return index
 end
 local index=candidate()
 if options.limited then
  -- The source consumes a candidate before entering its limited loop, even
  -- when that first candidate already matches. Later Fruit is never accepted.
  repeat index=candidate() until pool[index+1][3]==wanted and pool[index+1][1]~='Fruit Juice'
 else
  while pool[index+1][3]~=wanted do index=candidate()end
 end
 return descriptor(index,attempts)
end
function M.totallyRandom(owner,...)
 assert(select('#',...)==0,'Unexpected totally-random potion arguments')
 validate(owner)
 local index=R.randomIntBetween(owner.potionRng,0,#pool-1)
 return descriptor(index,{index})
end
return M
