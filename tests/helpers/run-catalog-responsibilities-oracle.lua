package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Catalog,Copy,D=require('abyss_run_card_catalog'),require('abyss_copy'),require('abyss_data')
local function check(ok,why)assert(ok,'[CATALOG_RESPONSIBILITY] '..why)end
local source=Copy.copy(D)
source.cards.sourcePools.cardSourceMetadata={strike={word='caller'}}
source.listAlias=source.cards.cards;source.statusAlias=source.statuses.statuses
local graph={};graph.self=graph;source.a=graph;source.b=graph
local selected=Catalog.prepareSelected(source,'silent')
local out=Catalog.prepare(source,selected,'silent',true)
check(out==selected,'owned selected identity')
check(out.cards.cards==out.listAlias and out.statuses.statuses==out.statusAlias,'directory alias identity')
check(out.a==out.b and out.a.self==out.a and out.a~=graph,'private caller graph')
local cards,statuses={},{}
for _,c in ipairs(out.cards.cards)do cards[c.id]=c end
for _,s in ipairs(out.statuses.statuses)do statuses[s.id]=s end
check(statuses.intangible.priority==75 and statuses.rage.priority==5,'shared Power priorities')
check(cards.feed.runNativeABI==true and cards.strike.runNativeABI==nil,'native ABI owners')
check(out.cards.sourcePools.cardSourceMetadata.strike.word=='caller','metadata caller words')
check(cards.burn.burnDamage==2 and cards.burn.upgrade.burnDamage==4,'shared Burn upgrade')
check(source.cards.cards==source.listAlias and not source.runCardCatalog,'source remains untouched')
