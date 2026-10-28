package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,Map,N,C,R=require('abyss_run'),require('abyss_map'),require('abyss_nodes'),require('abyss_combat'),require('abyss_sts_random')
local D=require('abyss_data');local template=Map.generate(D,'42')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b,seen)
 eq(type(a),type(b));if type(a)~='table'then eq(a,b);return end
 seen=seen or {};if seen[a]==b then return end;seen[a]=b
 for k,v in pairs(a)do same(v,b[k],seen)end;for k in pairs(b)do assert(a[k]~=nil)end
end
local function fixture(seed)
 seed=seed or '42'
 local r=Run.new(D,seed,{experimental=true,campaign=true});local m=seed=='42'and C.copy(template)or Map.generate(D,seed)
 r.floor=6;for _,n in ipairs(m.nodes)do if n.floor==6 then m.floor,m.currentNodeId,m.path=6,n.id,{n.id};break end end;local node=Map.available(m)[1]
 for _,n in ipairs(m.nodes)do if n.id==node.id then n.type,n.eventId='event','mushrooms' end end
 return r,m,node.id
end
local function enter()local r,m,id=fixture();local ok,why=N.enter(r,m,id);assert(ok,why);return r,m end
local function owned(r,id)for _,v in ipairs(r.relics)do if v==id then return true end end;return false end
return {fixture=fixture,enter=enter,Run=Run,Map=Map,N=N,C=C,R=R,D=D,eq=eq,same=same,owned=owned}

