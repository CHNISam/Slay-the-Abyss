package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,Map,Nodes,C,R,P=require('abyss_run'),require('abyss_map'),require('abyss_nodes'),require('abyss_combat'),require('abyss_sts_random'),require('abyss_event_pool')
local D=require('abyss_data')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b)eq(type(a),type(b));if type(a)~='table'then eq(a,b);return end;for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end end
local template=Map.generate(D,'42')
local function fixture(hp,maximum)
 local r=Run.new(D,'42');local m=C.copy(template);r.hp,r.maxHp=hp or 80,maximum or 80
 local id=Map.available(m)[1].id;for _,n in ipairs(m.nodes)do if n.id==id then n.type='event';n.eventId='golden_idol'end end
 return r,m,id
end
return {fixture=fixture,eq=eq,same=same,Run=Run,Map=Map,Nodes=Nodes,C=C,R=R,P=P,D=D}
