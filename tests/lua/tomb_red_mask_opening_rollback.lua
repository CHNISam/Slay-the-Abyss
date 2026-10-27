local F=dofile('tests/lua/support/tomb_red_mask_fixture.lua');local eq,same,Run,Nodes,C=F.eq,F.same,F.Run,F.Nodes,F.C
local Hooks=require('abyss_relic_hooks')
local r,m,n=F.fixture(0);assert(Nodes.enter(r,m,n));assert(Nodes.chooseEvent(r,'pay'));assert(Nodes.chooseEvent(r,'leave'))
local next=F.Map.available(m)[1];for _,v in ipairs(m.nodes)do if v.id==next.id then v.type='combat';v.eventId=nil;v.roomKind=nil end end
local before,bm=C.copy(r),C.copy(m);local flow,deck,held,queue,misc,card=r.nodeFlow,r.deck,r.relics,r.encounters,r.miscRng,r.cardRng
local start=Hooks.battleStart;local reached=false
Hooks.battleStart=function(state,id)
 start(state,id)
 if id=='red_mask'then eq(state.enemies[1].statuses.weak,1);reached=true;error('AFTER_RED_MASK_OPENING')end
end
local ok,why=Nodes.enter(r,m,next.id);Hooks.battleStart=start
eq(ok,false);eq(why,'combat_unavailable');assert(reached);same(r,before);same(m,bm)
eq(r.nodeFlow,flow);eq(r.deck,deck);eq(r.relics,held);eq(r.encounters,queue);eq(r.miscRng,misc);eq(r.cardRng,card)
assert(Nodes.enter(r,m,next.id));eq(r.combat.enemies[1].statuses.weak,1)
print('TOMB_RED_MASK_OPENING_ROLLBACK_PASS actual source room fails after Weak, preserves full Run/map/queue/RNG graph and retries')
