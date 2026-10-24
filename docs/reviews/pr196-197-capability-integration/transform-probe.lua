-- Complete source ordered 72-card pool; explicit Living Wall event fixture.
-- Does not assert Living Wall is in the normal random-event probability pool.
package.path='source196/src/lua/?.lua;source196/build/lua/?.lua;source197/src/lua/?.lua;'..package.path
local C,Run,Map,R,Cap=require('abyss_combat'),require('abyss_run'),require('abyss_map'),require('abyss_sts_random'),require('abyss_card_capability')
local Nodes=dofile('source197/src/lua/abyss_nodes.lua')
local data=require('abyss_data')
local function same(a,b)
 assert(type(a)==type(b));if type(a)~='table' then assert(a==b);return end
 for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end
end
local context={pools={common={},srcUncommon={},srcRare={}},cards={},sourceToLocal={}}
local defs={};for _,d in ipairs(data.cards.cards)do defs[d.id]=d;context.cards[d.id]={sourceId=d.sourceId or d.sts_name,category='colored'};context.sourceToLocal[d.sourceId or d.sts_name]=d.id end
local candidates={}
for _,pair in ipairs({{'common','common'},{'uncommon','srcUncommon'},{'rare','srcRare'}})do
 for _,id in ipairs(data.cards.sourcePools.src[pair[1]])do
  local source=assert(defs[id].sourceId);table.insert(context.pools[pair[2]],source);table.insert(candidates,source)
 end
end
assert(#candidates==72)
for _,id in ipairs({'clash','whirlwind'})do
 local at;for i,source in ipairs(candidates)do if source==defs[id].sourceId then at=i end end
 local run,map=Run.new(data,42),Map.generate(data,42)
 local first=Map.available(map)[1];for _,node in ipairs(map.nodes)do if node.id==first.id then node.type='event';node.eventId='living_wall' end end
 assert(Nodes.enter(run,map,first.id));run.transformContext=C.copy(context)
 -- Existing source RNG vector: next bounded index is n % bound.
 run.miscRng=R.restore({words={'0000000000000000',string.format('%016x',at-1)},counter=7})
 assert(Nodes.chooseEvent(run,'change'))
 local before=C.copy(run);local deckRef,rngRef=run.deck,run.miscRng;local uid=run.deck[1].uid
 local ok,why=Nodes.chooseLivingWallCard(run,uid)
 assert(ok==false and why=='event_content_unavailable');same(run,before)
 assert(run.deck==deckRef and run.miscRng==rngRef)
 -- Narrow diagnostic control locates the blocker; not a production patch.
 local original=Cap.isImplemented
 Cap.isImplemented=function(card)if card and card.id==id then return true end;return original(card)end
 local accepted,reason=Nodes.chooseLivingWallCard(run,uid)
 Cap.isImplemented=original
 assert(accepted and run.deck[#run.deck].cardId==id and run.miscRng.counter==8)
 print('TRANSFORM '..id..': full72 slot='..at..'; original gate='..why..', unchanged deck/UID/RNG/references; single-card diagnostic succeeds, counter 7->8')
end
print('PASS: 2 full-pool transform counterexamples reproduced with atomic original refusal. Explicit event fixture, not normal event probability or platform proof.')
