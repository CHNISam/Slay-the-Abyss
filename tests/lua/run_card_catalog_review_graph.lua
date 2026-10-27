package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,D=require('abyss_run'),require('abyss_combat'),require('abyss_data')
local function strike(data)for _,c in ipairs(data.cards.cards)do if c.id=='strike'then return c end end;error('strike')end
local source=C.copy(D);local graph={};graph.self=graph
source.cards.callerGraph=graph;source.strikeAlias=strike(source)
for _,spec in ipairs({{}, {character='ironclad',experimental=true},{character='silent',experimental=true},{character='defect',experimental=true},{character='watcher',experimental=true}})do
 local r=Run.new(source,42,next(spec)and spec or nil)
 assert(r.data.cards.callerGraph and r.data.cards.callerGraph.self==r.data.cards.callerGraph,'cards extension cycle must survive')
 assert(r.data.cards.callerGraph~=graph and r.data.strikeAlias==strike(r.data)and r.data.strikeAlias~=source.strikeAlias,'real directory Strike retains its private caller alias')
end
print('RUN_CARD_CATALOG_REVIEW_GRAPH_PASS exact cards extension cycle and Strike directory alias across default/four selected classes')
