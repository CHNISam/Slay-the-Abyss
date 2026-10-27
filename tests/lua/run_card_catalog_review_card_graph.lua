package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,D=require('abyss_run'),require('abyss_combat'),require('abyss_data')
local function strike(data)for _,c in ipairs(data.cards.cards)do if c.id=='strike'then return c end end;error('strike')end
local source=C.copy(D);local graph={};graph.self=graph
strike(source).callerGraph=graph;source.cardExtensionAlias=graph
source.nativeEffectsAlias=strike(source).effects
source.nativeEffectAlias=strike(source).effects[1]
for _,spec in ipairs({{}, {character='ironclad',experimental=true},{character='silent',experimental=true},{character='defect',experimental=true},{character='watcher',experimental=true}})do
 local r=Run.new(source,42,next(spec)and spec or nil);local owned=strike(r.data).callerGraph
 assert(owned and owned.self==owned and owned==r.data.cardExtensionAlias and owned~=graph,'valid opaque card extension graph remains private and shared')
 assert(strike(r.data).effects[1].value==6,'graph support does not replace actual native rules')
 assert(r.data.nativeEffectsAlias==strike(r.data).effects and r.data.nativeEffectAlias==strike(r.data).effects[1],'unchanged native semantic nodes retain their private aliases')
end
assert(strike(source).callerGraph==graph and graph.self==graph)
print('RUN_CARD_CATALOG_REVIEW_CARD_GRAPH_PASS valid opaque card cycle and alias preserved for default/four selected classes')
