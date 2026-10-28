package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local F={R=require('abyss_run'),C=require('abyss_combat'),S=require('abyss_sts_random'),N=require('abyss_nodes'),Map=require('abyss_map'),D=require('abyss_data')}
F.vectors=dofile('tests/fixtures/max-hp-relics-vectors.lua')
function F.eq(a,b,label)assert(a==b,(label or 'value')..': '..tostring(a)..' ~= '..tostring(b))end
function F.same(a,b,seen)
 F.eq(type(a),type(b));if type(a)~='table'then F.eq(a,b);return end
 seen=seen or {};if seen[a]==b then return end;seen[a]=b
 for k,v in pairs(a)do F.same(v,b[k],seen)end
 for k in pairs(b)do assert(a[k]~=nil,'extra key '..tostring(k))end
end
function F.new(case)
 local r=F.R.new(F.D,case.seed,{experimental=true,character=case.character})
 F.same(r.relicPool.queues,case.queues);F.same(F.S.snapshot(r.relicPool.rng),case.afterInitialization)
 F.eq(r.maxHp,case.startingMaximum);F.eq(r.hp,case.startingMaximum)
 r.hp=30;return r
end
function F.remove(r,source)
 r.data=F.C.copy(r.data)
 for i,d in ipairs(r.data.relics.relics)do if d.sourceId==source then table.remove(r.data.relics.relics,i);return end end
 error('missing expected source definition')
end
function F.enter(r,kind)
 local map=F.Map.generate(F.D,r.eventSeed or r.seed);local id=F.Map.available(map)[1].id
 for _,node in ipairs(map.nodes)do if node.id==id then node.type=kind;node.roomKind=nil end end
 assert(F.N.enter(r,map,id));return map
end
function F.snapshotFailure(r,command)
 local before=F.C.copy(r);local data,deck,pool,flow,battle=r.data,r.deck,r.relicPool,r.nodeFlow,r.combat
 local called,ok=pcall(command);assert(called and not ok)
 F.same(r,before);F.eq(r.data,data);F.eq(r.deck,deck);F.eq(r.relicPool,pool);F.eq(r.nodeFlow,flow);F.eq(r.combat,battle)
end
return F
