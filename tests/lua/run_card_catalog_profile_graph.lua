package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local P,C,D=require('abyss_character_profiles'),require('abyss_combat'),require('abyss_data')
local source=C.copy(D);local graph={};graph.self=graph
for _,c in ipairs(source.cards.cards)do if c.id=='strike'then c.callerGraph=graph;source.strikeAlias=c end end
source.extensionAlias=graph
local raw,profile=P.prepare(source,'ironclad');local normal,actual=0
for _,c in ipairs(raw.cards.cards)do
 if c.type~='status'and c.type~='curse'and c.rarity~='special'then normal=normal+1 end
 if c.id=='strike'then actual=c end
end
assert(normal==66 and profile.id=='ironclad'and not raw.runCardCatalog,'historical raw component/filter remain unchanged')
assert(actual==raw.strikeAlias and actual.callerGraph==raw.extensionAlias and actual.callerGraph.self==actual.callerGraph)
assert(actual.callerGraph~=graph and actual.effects[1].value==6 and actual.upgrade.effects[1].value==9)
assert(source.strikeAlias.callerGraph==graph and source.experimentalCharacter==nil)
print('RUN_CARD_CATALOG_PROFILE_GRAPH_PASS historical raw Ironclad66 rules/filter and graph-copy enhancement remain detached')
