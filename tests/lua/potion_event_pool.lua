package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,Run,Map,Nodes,R=require('abyss_combat'),require('abyss_run'),require('abyss_map'),require('abyss_nodes'),require('abyss_sts_random')
local Data=require('abyss_data')
-- Independent fixed PotionHelper registration order, shared with the audited
-- Python oracle rather than read from the production Lua sampler.
local expected={'BloodPotion','ElixirPotion','HeartOfIron','Block Potion','Dexterity Potion','Energy Potion','Explosive Potion','Fire Potion','Strength Potion','Swift Potion','Weak Potion','FearPotion','AttackPotion','SkillPotion','PowerPotion','ColorlessPotion','SteroidPotion','SpeedPotion','BlessingOfTheForge','Regen Potion','Ancient Potion','LiquidBronze','GamblersBrew','EssenceOfSteel','DuplicationPotion','DistilledChaos','LiquidMemories','CultistPotion','Fruit Juice','SneckoOil','FairyPotion','SmokeBomb','EntropicBrew'}
local function eventRun(character)
 local run=Run.new(Data,42,character and {character=character,experimental=true} or nil)
 local map=Map.generate(Data,42);local first=Map.available(map)[1]
 for _,n in ipairs(map.nodes)do if n.id==first.id then n.type='event';n.eventId='woman_in_blue' end end
 assert(Nodes.enter(run,map,first.id));return run
end
local r=eventRun();local base=C.copy(r)
for index,source in ipairs(expected)do
 r=C.copy(base);r.potions={};r.shopRng={potion=R.restore({words={'0000000000000000',string.format('%016x',index-1)},counter=0})}
 assert(Nodes.chooseEvent(r,'buy_1'));local offer=r.nodeFlow.event.potionOffers[1]
 assert(offer.sourceId==source and offer.sourceIndex==index-1);assert(r.shopRng.potion.counter==1)
 assert(Nodes.chooseEvent(r,'claim_1'));assert(r.potions[1]==offer.id and r.nodeFlow.event.potionOffers[1].claimed)
 print('PASS uniform event source slot '..index..' '..source)
end
-- Other class-exclusive outcomes must retain the actual class's source slot,
-- including an atomic refusal while that class bottle definition is missing.
for _,entry in ipairs({{'silent','Poison Potion'},{'defect','FocusPotion'},{'watcher','BottledMiracle'}})do
 local classBase=eventRun(entry[1]);r=C.copy(classBase);r.shopRng={potion=R.restore({words={'0000000000000000','0000000000000000'},counter=0})}
 local ok,why=Nodes.chooseEvent(r,'buy_1')
 assert(ok,why);assert(r.nodeFlow.event.potionOffers[1].sourceId==entry[2]);assert(r.shopRng.potion.counter==1)
 -- The complete class registry now supplies all three bottles. Keep the old
 -- missing-definition refusal as a separate explicitly incomplete fixture.
 local missing=C.copy(classBase)
 local absent=r.nodeFlow.event.potionOffers[1].id
 local definitions={};for _,definition in ipairs(missing.data.potions.potions)do if definition.id~=absent then definitions[#definitions+1]=definition end end
 missing.data.potions=C.copy(missing.data.potions);missing.data.potions.potions=definitions
 missing.shopRng={potion=R.restore({words={'0000000000000000','0000000000000000'},counter=0})}
 local accepted,reason=Nodes.chooseEvent(missing,'buy_1')
 assert(not accepted and reason=='unknown_potion' and missing.gold==classBase.gold and missing.shopRng.potion.counter==0)
end
print('POTION_EVENT_POOL 33+3 passed')
