package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,Run,Map,Nodes,R=require('abyss_combat'),require('abyss_run'),require('abyss_map'),require('abyss_nodes'),require('abyss_sts_random')
local Data=require('abyss_data')
-- Independent fixed PotionHelper registration order, shared with the audited
-- Python oracle rather than read from the production Lua sampler.
local expected={'BloodPotion','ElixirPotion','HeartOfIron','Block Potion','Dexterity Potion','Energy Potion','Explosive Potion','Fire Potion','Strength Potion','Swift Potion','Weak Potion','FearPotion','AttackPotion','SkillPotion','PowerPotion','ColorlessPotion','SteroidPotion','SpeedPotion','BlessingOfTheForge','Regen Potion','Ancient Potion','LiquidBronze','GamblersBrew','EssenceOfSteel','DuplicationPotion','DistilledChaos','LiquidMemories','CultistPotion','Fruit Juice','SneckoOil','FairyPotion','SmokeBomb','EntropicBrew'}
local r,m=Run.new(Data,42),Map.generate(Data,42)
local first=Map.available(m)[1];for _,n in ipairs(m.nodes)do if n.id==first.id then n.type='event';n.eventId='woman_in_blue' end end
assert(Nodes.enter(r,m,first.id));local base=C.copy(r)
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
 r=C.copy(base);r.character=entry[1];r.shopRng={potion=R.restore({words={'0000000000000000','0000000000000000'},counter=0})}
 local ok,why=Nodes.chooseEvent(r,'buy_1')
 if entry[1]=='silent'then assert(ok and r.nodeFlow.event.potionOffers[1].sourceId==entry[2])
 else assert(not ok and why=='unknown_potion' and r.gold==base.gold and r.shopRng.potion.counter==0)end
end
print('POTION_EVENT_POOL 33+3 passed')
