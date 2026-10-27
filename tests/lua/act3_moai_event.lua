package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,Map,Nodes,C,P,Q,R=require('abyss_run'),require('abyss_map'),require('abyss_nodes'),require('abyss_combat'),require('abyss_event_pool'),require('abyss_encounter_queue'),require('abyss_sts_random')
local D=require('abyss_data')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b)eq(type(a),type(b));if type(a)~='table'then eq(a,b);return end;for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end end
local template=Map.generate(D,'42',3)
local function fixture(hp,maxHp,relics)
 local r=Run.new(D,'42',{experimental=true,campaign=true});local m=C.copy(template)
 r.act,r.floor=3,34;r.encounters=Q.new(r.runSeed,3);r.unknown.pools=P.new('full',true,3)
 r.hp,r.maxHp=hp==nil and 80 or hp,maxHp==nil and 80 or maxHp;r.relics=relics or {'burning_blood'}
 local id=Map.available(m)[1].id;for _,n in ipairs(m.nodes)do if n.id==id then n.type='event';n.eventId='moai_head'end end
 return r,m,id
end
local r,m,id=fixture();local ok,why=Nodes.enter(r,m,id);assert(ok,why)
eq(P.contentId['The Moai Head'],'moai_head');eq(r.nodeFlow.event.hpLoss,10);eq(r.nodeFlow.event.stage,'intro')
local rows=Nodes.view(r,m).node.event.options;eq(#rows,3);eq(rows[1].choice,'heal');eq(rows[2].choice,'give_idol');eq(rows[3].choice,'leave');assert(rows[1].enabled and not rows[2].enabled and rows[3].enabled)
local before=C.copy(r);Nodes.view(r,m);same(r,before);eq(Nodes.chooseEvent(r,'give_idol'),false);same(r,before)
local deck,pools,rng=C.copy(r.deck),C.copy(r.unknown.pools),R.snapshot(r.miscRng)
assert(Nodes.chooseEvent(r,'heal'));eq(r.maxHp,70);eq(r.hp,70);eq(r.nodeFlow.event.stage,'result');same(r.deck,deck);same(r.unknown.pools,pools);same(R.snapshot(r.miscRng),rng)
assert(Nodes.chooseEvent(r,'leave'));eq(r.phase,'map');before=C.copy(r);eq(Nodes.chooseEvent(r,'leave'),false);same(r,before)
-- Python IEEE32+Java-round oracle, including conversion before multiplication.
for _,vector in ipairs({{1,0},{3,0},{4,1},{11,1},{12,2},{20,3},{80,10},{16777219,2097153},{2147483647,268435456}})do
 local maximum,loss=vector[1],vector[2];local s,map,node=fixture(1,maximum);assert(Nodes.enter(s,map,node));eq(s.nodeFlow.event.hpLoss,loss)
 assert(Nodes.chooseEvent(s,'heal'));eq(s.maxHp,maximum-loss);eq(s.hp,s.maxHp)
end
for _,vector in ipairs({{1,{'mark_of_bloom'},1},{80,{'mark_of_bloom'},70},{1,{'magic_flower'},70},{1,{'mark_of_bloom','magic_flower'},1}})do
 local s,map,node=fixture(vector[1],80,vector[2]);s.potions[1]='fairy_in_a_bottle'
 s.combat={player={hp=0,maxHp=999,statuses={intangible=3}},relics={'sacred_bark','magic_flower'},potionInventory={[1]='fairy_in_a_bottle'},events={{kind='old'}}}
 local combat=C.copy(s.combat);assert(Nodes.enter(s,map,node));assert(Nodes.chooseEvent(s,'heal'));eq(s.maxHp,70);eq(s.hp,vector[3]);eq(s.potions[1],'fairy_in_a_bottle');same(s.combat,combat)
end
for _,blocked in ipairs({false,true})do
 local relics={'anchor','golden_idol','vajra'};if blocked then relics[#relics+1]='ectoplasm'end
 local s,map,node=fixture(80,80,relics);local cards=C.copy(s.deck);local gold=s.gold;assert(Nodes.enter(s,map,node));local rng=R.snapshot(s.miscRng)
 assert(Nodes.view(s,map).node.event.options[2].enabled);assert(Nodes.chooseEvent(s,'give_idol'));eq(s.gold,gold+(blocked and 0 or 333));eq(s.maxHp,80);eq(s.hp,80)
 eq(s.relics[1],'anchor');eq(s.relics[2],'vajra');eq(#s.relics,blocked and 3 or 2);same(s.deck,cards);same(R.snapshot(s.miscRng),rng);eq(s.nodeFlow.event.stage,'result')
 assert(Nodes.chooseEvent(s,'leave'));eq(s.phase,'map')
end
-- Unknown source spelling is not a second canonical inventory identity.
do local s,map,node=fixture(80,80,{'Golden Idol'});assert(Nodes.enter(s,map,node));assert(not Nodes.view(s,map).node.event.options[2].enabled);local b=C.copy(s);eq(Nodes.chooseEvent(s,'give_idol'),false);same(s,b)end
for _,choice in ipairs({'heal','give_idol','leave'})do
 local s,map,node=fixture(1,80,{'golden_idol'});assert(Nodes.enter(s,map,node));local b=C.copy(s);eq(Nodes.chooseEvent(s,choice,999),false);same(s,b)
end
do local s,map,node=fixture();assert(Nodes.enter(s,map,node));local hp,maxHp,gold=s.hp,s.maxHp,s.gold;assert(Nodes.chooseEvent(s,'leave'));eq(s.nodeFlow.event.stage,'result');eq(s.phase,'node');eq(s.hp,hp);eq(s.maxHp,maxHp);eq(s.gold,gold);assert(Nodes.chooseEvent(s,'leave'));eq(s.phase,'map')end
for _,change in ipairs({'lost_idol','max_hp'})do
 local s,map,node=fixture(20,80,{'golden_idol','anchor'});assert(Nodes.enter(s,map,node))
 if change=='lost_idol'then table.remove(s.relics,1)else s.maxHp=0 end
 local b,bm=C.copy(s),C.copy(map);eq(Nodes.chooseEvent(s,change=='lost_idol'and'give_idol'or'heal'),false);same(s,b);same(map,bm)
end
for _,kind in ipairs({'heal','give_idol'})do for _,failure in ipairs({'return','throw'})do
 local s,map,node=fixture(1,80,{'golden_idol'});assert(Nodes.enter(s,map,node));local b,bm=C.copy(s),C.copy(map)
 local key=kind=='heal'and'heal'or'gainGold';local original=Run[key]
 Run[key]=function(owner,value)original(owner,value);if failure=='throw'then error('late Moai failure')end;return false,'late_moai_failure'end
 local called,accepted=pcall(Nodes.chooseEvent,s,kind);Run[key]=original;assert(called);eq(accepted,false);same(s,b);same(map,bm)
end end
do local s,map,node=fixture(20,80,{'golden_idol'});s.gold=2147483647;assert(Nodes.enter(s,map,node));local b,bm=C.copy(s),C.copy(map);eq(Nodes.chooseEvent(s,'give_idol'),false);same(s,b);same(map,bm)end
for _,spec in ipairs({{0,80,{'golden_idol'}},{1,0,{'golden_idol'}},{80,80,{'golden_idol','golden_idol'}}})do
 local s,map,node=fixture(spec[1],spec[2],spec[3]);local b,bm=C.copy(s),C.copy(map);eq(Nodes.enter(s,map,node),false);same(s,b);same(map,bm)
end
local full=P.new('full',true,3);same(full.act,{'Falling','MindBloom','The Moai Head','Mysterious Sphere','SensoryStone','Tomb of Lord Red Mask','Winding Halls'});eq(#full.shrine,6);eq(#full.once,14)
print('ACT3_MOAI_EVENT_PASS source f32/round, full-HP admission, clamp/heal/Bloom/Fairy, exact canonical Idol/333/Ectoplasm, stages and atomic stale/late failures')
