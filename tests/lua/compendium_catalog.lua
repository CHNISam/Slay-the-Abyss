package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local D,P=require('abyss_data'),require('abyss_presentation')
local Copy=require('abyss_copy').copy
local function freeze(root)
 local saved,work={},{root}
 while #work>0 do local t=table.remove(work);if not saved[t]then
  local entries={};saved[t]=entries
  for k,v in pairs(t)do entries[k]=v;if type(v)=='table'then work[#work+1]=v end end
 end end
 return function()for t,entries in pairs(saved)do
  for k,v in pairs(entries)do assert(t[k]==v,'source changed '..tostring(k))end
  for k,v in pairs(t)do assert(entries[k]==v,'source added '..tostring(k))end
 end end
end
local unchangedD,unchangedP=freeze(D),freeze(P)
local Run,R=require('abyss_run'),require('abyss_sts_random')
local oldNew=Run.new;Run.new=function()error('compendium must not create a Run')end
local randomMethods={}
for key,value in pairs(R)do if type(value)=='function'then
 randomMethods[key]=value;R[key]=function()error('compendium must not invoke RNG '..key)end
end end
local oldRandom,oldRandomSeed=math.random,math.randomseed
math.random=function()error('compendium must not invoke math.random')end
math.randomseed=function()error('compendium must not reseed randomness')end
local ok,C=pcall(require,'abyss_compendium_catalog')
assert(ok,'missing standalone compendium provider')
local catalog=C.new(D,P)
assert(catalog.character=='ironclad' and catalog.campaignProfile=='competition-two-act')
local function indexed(list)local out={};for _,e in ipairs(list)do assert(not out[e.id]);out[e.id]=e end;return out end
local cards=indexed(catalog:list('cards'))
assert(cards.strike and cards.bash and cards.apotheosis and cards.blade_dance and cards.master_reality,
 'production must retain cross-color cards obtainable through Prismatic Shard')
assert(not cards.strike_green and not cards.neutralize and not cards.zap and not cards.eruption,
 'closed classes must not expose their exclusive starter cards')
assert(cards.shiv and cards.beta and cards.omega,'legal cross-color generated dependencies remain inspectable')
for _,id in ipairs({'apparition','bite','jax','ritual_dagger','necronomicurse','curse_of_the_bell',
 'normality','regret','dazed','slimed','wound','burn','void'})do
 assert(cards[id],'missing event/curse/status dependency '..id)
end
assert(#catalog:list('cards')==356 and #catalog:list('relics')==149,'review Production scope when content changes')
local potions=indexed(catalog:list('potions'))
assert(#catalog:list('potions')==33 and potions.blood_potion and potions.fairy_in_a_bottle)
assert(not potions.poison_potion and not potions.focus_potion and not potions.ambrosia)
local relics=indexed(catalog:list('relics'))
assert(relics.burning_blood and relics.prismatic_shard and relics.necronomicon and relics.bloody_idol)
assert(not relics.mark_of_bloom and not relics.snake_skull and not relics.data_disk and not relics.damaru)
for _,kind in ipairs({'cards','potions','relics'})do
 for _,entry in ipairs(catalog:list(kind))do
  assert(entry.name:find('[\128-\255]'),'missing Chinese '..kind..' name '..entry.id)
  assert(type(entry.text)=='string'and #entry.text>0,'missing detail '..kind..' '..entry.id)
 end
end
for _,entry in ipairs(catalog:list('cards'))do
 local base=catalog:card(entry.id,false)
 local upgrade=catalog:card(entry.id,true)
 local eligible=base.type~='status'and base.type~='curse'and base.definition.upgrade~=nil
 assert((upgrade~=nil)==eligible,'incorrect preview availability '..entry.id)
 if upgrade then assert(upgrade.upgraded and #upgrade.text>0,'missing upgrade '..entry.id)end
end
local base=catalog:card('strike',false);local upgraded=catalog:card('strike',true)
assert(base.definition.effects[1].value==6 and upgraded.definition.effects[1].value==9)
assert(not base.upgraded and upgraded.upgraded and upgraded.text~=base.text)
assert(catalog:card('searing_blow',true).definition.effects[1].value==16)
assert(catalog:card('wound',true)==nil,'unupgradeable cards must not invent an upgrade')
assert(catalog:card('strike_green')==nil and catalog:detail('potions','focus_potion')==nil)
base.definition.effects[1].value=999;cards.strike.name='mutated'
assert(catalog:card('strike').definition.effects[1].value==6)
local copy=catalog:list('relics');copy[1].text='mutated'
assert(catalog:list('relics')[1].text~='mutated')
local another=C.new(D,P);assert(another:card('strike').definition.effects[1].value==6)
local RelicText=require('abyss_relic_text')
local ctx={self={run={data=D}},inspectCards={}}
require('abyss_node_ui_faces').install(ctx)
for _,def in ipairs(D.relics.relics)do
 assert(ctx.relicText(def.id)==RelicText.describe(D,def.id),'live relic UI diverged')
 if def.description and def.id~='membership_card'and def.id~='courier'and def.id~='smiling_mask'then
  assert(RelicText.describe(D,def.id)==def.description,'authored relic text changed')
 end
end
assert(RelicText.describe(D,'membership_card')=='所有商店商品半价。')
assert(RelicText.describe(D,'courier')=='商店商品八折，购买后补货。')
assert(RelicText.describe(D,'smiling_mask')=='商店删牌服务固定为50金币。')
assert(RelicText.describe(D,'missing')=='')
local synthetic={relics={relics={{id='test',trigger='combat_start',effects={
 {op='heal',value=1},{op='block',value=2},{op='draw',value=3},{op='energy',value=4},
 {op='gainStatus',value=5,status='strength'}}}}},statuses={statuses={{id='strength',name='力量'}}}}
assert(RelicText.describe(synthetic,'test')=='战斗开始时，回复 1 点生命，获得 2 点格挡，抽 3 张牌，获得 4 点能量，获得 5 层力量。')
local future=Copy(D)
future.cards.cards[#future.cards.cards+1]={id='future_event_card',name='未来事件牌',sourceId='Future',
 type='skill',rarity='special',cost=0,target='SELF',effects={{op='block',value=1}},upgrade={}}
assert(C.new(future,P):card('future_event_card')==nil,'unknown future special must stay closed')
local rejected=Copy(D);rejected.characterId='watcher'
assert(not pcall(C.new,rejected,P),'reject prepared closed class source')
unchangedD();unchangedP();Run.new=oldNew
for key,value in pairs(randomMethods)do R[key]=value end
math.random,math.randomseed=oldRandom,oldRandomSeed
print('COMPENDIUM_CATALOG_PASS production catalogs, no Run/RNG, detached previews and Chinese detail')
