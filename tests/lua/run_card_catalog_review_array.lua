package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,D=require('abyss_run'),require('abyss_combat'),require('abyss_data')
-- This exact ownership contract exists in pre-catalog Run01c1f94f when the
-- caller is already Colorless-registered. Unregistered old Run replaced lists.
local source=require('abyss_colorless_cards').withCards(C.copy(D))
source.cardListAlias=source.cards.cards;source.statusListAlias=source.statuses.statuses
local beforeCards,beforeStatuses=#source.cardListAlias,#source.statusListAlias
local first,second=Run.new(source,42),Run.new(source,43)
for _,r in ipairs({first,second})do
 assert(r.data.cardListAlias==r.data.cards.cards,'old registered caller card-array alias must remain the actual full catalogue')
 assert(r.data.statusListAlias==r.data.statuses.statuses,'old registered caller status-array alias must remain the actual Power catalogue')
 assert(r.data.cardListAlias~=source.cardListAlias and r.data.statusListAlias~=source.statusListAlias)
end
assert(#source.cardListAlias==beforeCards and #source.statusListAlias==beforeStatuses)
table.remove(first.data.cardListAlias);assert(#second.data.cardListAlias==#second.data.cards.cards and #second.data.cardListAlias==#first.data.cardListAlias+1)
print('RUN_CARD_CATALOG_REVIEW_ARRAY_PASS baseline-supported registered card/status array aliases and two-Run private ownership')
