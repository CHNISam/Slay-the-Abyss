package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C=require('abyss_combat');local Run=require('abyss_run');local Colorless=require('abyss_colorless_cards')
local Data=require('abyss_data')
local function find(rows,id)for _,row in ipairs(rows)do if row.id==id then return row end end;error(id)end
local a,b=Colorless.withCards(Data),Colorless.withCards(Data)
find(a.cards.cards,'swift_strike').effects[1].value=900
find(a.statuses.statuses,'magnetism').name='changed'
a.cards.sourcePools.srcColorless[1]='changed';a.cards.sourcePools.colorlessShop.uncommon[1]='changed'
assert(find(b.cards.cards,'swift_strike').effects[1].value==7)
assert(find(b.statuses.statuses,'magnetism').name=='磁引')
assert(b.cards.sourcePools.srcColorless[1]=='madness')
assert(b.cards.sourcePools.colorlessShop.uncommon[1]=='bandage_up')
local fresh=Colorless.withCards(Data)
assert(find(fresh.cards.cards,'swift_strike').effects[1].value==7)
assert(fresh.cards.sourcePools.srcColorless[1]=='madness')
for _,id in ipairs({'default','unselected','ironclad','silent','defect','watcher','hutao','arlecchino','furina','raiden'})do
 local options
 if id=='unselected'then options={experimental=true}
 elseif id~='default'then options={character=id,experimental=true}end
 local x,y=Run.new(Data,29,options),Run.new(Data,29,options)
 local hp=y.data.rules.player.maxHp
 x.data.rules.player.maxHp=1;x.data.cards.cards[1].name='changed'
 x.data.enemies.enemies[1].intents[1].id='changed';x.data.statuses.statuses[1].description='changed'
 x.data.relics.relics[1].name='changed';x.data.cards.sourcePools.srcColorless[1]='changed'
 x.data.relicSource.isolationProbe=true
 assert(y.data.rules.player.maxHp==hp and Data.rules.player.maxHp==80,id)
 assert(y.data.cards.cards[1].name~='changed'and Data.cards.cards[1].name~='changed',id)
 assert(y.data.enemies.enemies[1].intents[1].id~='changed'and Data.enemies.enemies[1].intents[1].id~='changed',id)
 assert(y.data.statuses.statuses[1].description~='changed'and Data.statuses.statuses[1].description~='changed',id)
 assert(y.data.relics.relics[1].name~='changed'and Data.relics.relics[1].name~='changed',id)
 assert(y.data.cards.sourcePools.srcColorless[1]=='madness'and not Data.colorlessCards,id)
 assert(not y.data.relicSource.isolationProbe and not Data.relicSource.isolationProbe,id)
 if x.data.originalV4Role then
  x.data.originalV4Rules.common.energy_per_turn=900
  assert(y.data.originalV4Rules.common.energy_per_turn==3)
  assert(require('abyss_original_v4_data').rules.common.energy_per_turn==3)
  for _,card in ipairs(x.data.cards.cards)do if card.originalV4 then
   card.originalV4.name='changed';assert(find(y.data.cards.cards,card.id).originalV4.name~='changed');break
  end end
 end
end
local extra=require('abyss_act2_enemies')
for _,source in ipairs({Data,Colorless.withCards(Data)})do
 local first=C.new(source,{deck={},enemies={'cultist'},seed=1})
 local second=C.new(source,{deck={},enemies={'cultist'},seed=1})
 first.catalog.cards.swift_strike.effects[1].value=900;first.catalog.statuses.magnetism.name='changed'
 assert(second.catalog.cards.swift_strike.effects[1].value==7)
 assert(second.catalog.statuses.magnetism.name=='磁引')
 assert(find(Colorless.withCards(source).cards.cards,'swift_strike').effects[1].value==7)
end
local x=C.new(Data,{deck={},enemies={'cultist'},seed=1})
local y=C.new(Data,{deck={},enemies={'cultist'},seed=1})
local id=extra.enemies[1].id
x.catalog.enemies[id].intents[1].id='changed';x.catalog.statuses[extra.statuses[1].id].description='changed'
assert(y.catalog.enemies[id].intents[1].id~='changed'and extra.enemies[1].intents[1].id~='changed')
assert(y.catalog.statuses[extra.statuses[1].id].description~='changed'and extra.statuses[1].description~='changed')
print('INITIALIZATION_ISOLATION_PASS colorless templates, ten run modes, Act2 catalogs')
