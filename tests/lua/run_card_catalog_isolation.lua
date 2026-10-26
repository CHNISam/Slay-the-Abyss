package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,D=require('abyss_run'),require('abyss_combat'),require('abyss_data')
local function card(data,id)for _,c in ipairs(data.cards.cards)do if c.id==id then return c end end;error(id)end
local source=C.copy(D);source.rules.player.maxHp=83;source.rules.player.startingGold=123;source.cards.starter_deck.cards={'strike','defend'}
local graph={};graph.self=graph;source.catalogTestA=graph;source.catalogTestB=graph
local first=Run.new(source,42);assert(first.hp==83 and first.gold==123 and #first.deck==2)
assert(first.data~=source and first.data.catalogTestA==first.data.catalogTestB and first.data.catalogTestA.self==first.data.catalogTestA and first.data.catalogTestA~=graph)
card(source,'strike').cost=2
local second=Run.new(source,42);assert(card(first.data,'strike').cost==1 and card(second.data,'strike').cost==2,'same input identity must not cache stale content')
card(first.data,'cold_snap').effects[1].value=999;assert(card(second.data,'cold_snap').effects[1].value==6)
first.data.catalogTestA.extra=1;assert(not graph.extra and not second.data.catalogTestA.extra)
assert(Run.startCombat(second,'cultist_solo'));local battle=second.combat;local before=card(second.data,'strike').effects[1].value
battle.catalog.cards.strike.effects[1].value=777;assert(card(second.data,'strike').effects[1].value==before)
assert(Run.obtainPotion(second,'smoke_bomb'));assert(Run.usePotion(second,1));assert(Run.startCombat(second,'cultist_solo'))
assert(second.combat~=battle and second.combat.catalog.cards.strike.effects[1].value==before)
assert(card(source,'strike').cost==2 and card(source,'strike').effects[1].value==before)
local registered=require('abyss_colorless_cards').withCards(D)
local registeredRun=Run.new(registered,42)
assert(registeredRun.data.runCardCatalog and card(registeredRun.data,'survivor').sourceId=='Survivor')
assert(not registered.runCardCatalog,'already registered caller bundle must remain caller owned')
print('RUN_CARD_CATALOG_ISOLATION_PASS fresh caller reads, graph cycles/aliases, two Run and two actual combat private ownership')
