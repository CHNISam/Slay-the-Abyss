package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,Map,Nodes,C,R,P,Q=require('abyss_run'),require('abyss_map'),require('abyss_nodes'),require('abyss_combat'),require('abyss_sts_random'),require('abyss_event_pool'),require('abyss_encounter_queue')
local D=require('abyss_data');local templates={}
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b,seen)
 eq(type(a),type(b));if type(a)~='table'then eq(a,b);return end
 seen=seen or {};if seen[a]==b then return end;seen[a]=b
 for k,v in pairs(a)do same(v,b[k],seen)end;for k in pairs(b)do assert(a[k]~=nil)end
end
local function fixture(gold,seed,natural)
 seed=seed or '4';templates[seed]=templates[seed]or Map.generate(D,seed,3)
 local r=Run.new(D,seed,{experimental=true,campaign=true});local m=C.copy(templates[seed])
 r.act,r.floor=3,34;r.gold=gold==nil and r.gold or gold;r.encounters=Q.new(r.runSeed,3);r.unknown.pools=P.new('full',false,3)
 local first=Map.available(m)[1];for _,n in ipairs(m.nodes)do if n.id==first.id then n.type='event';n.eventId=not natural and 'tomb_red_mask'or nil end end
 return r,m,first.id
end
return {fixture=fixture,eq=eq,same=same,Run=Run,Map=Map,Nodes=Nodes,C=C,R=R,P=P,Q=Q,D=D}
