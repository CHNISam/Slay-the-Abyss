local H={}
H.C,H.Run,H.Map,H.Nodes=require('abyss_combat'),require('abyss_run'),require('abyss_map'),require('abyss_nodes')
H.Data,H.Pool,H.R,H.Hooks=require('abyss_data'),require('abyss_event_pool'),require('abyss_sts_random'),require('abyss_relic_hooks')
local bases={}
function H.eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
function H.same(a,b,path,seen)
 if a==b then return end;path=path or 'state';H.eq(type(a),type(b))
 if type(a)~='table'then assert(a==b,path..': '..tostring(a)..' ~= '..tostring(b));return end
 seen=seen or {};if seen[a]then H.eq(seen[a],b);return end;seen[a]=b
 for k,v in pairs(a)do H.same(v,b[k],path..'.'..tostring(k),seen)end
 for k in pairs(b)do assert(a[k]~=nil,path..' missing '..tostring(k))end
end
function H.snap(r)return H.C.copy(r,{[r.data]=r.data})end
function H.fixture(character,hp,maximum,unentered)
 character=character or 'ironclad'
 if not bases[character]then
  local r=H.Run.new(H.Data,'42',{experimental=true,campaign=true,character=character})
  r.act,r.floor=2,17;r.unknown.pools=H.Pool.new('full',false,2)
  bases[character]={run=r,map=H.Map.generate(r.data,'42',2)}
 end
 local b=bases[character];local r,m=H.snap(b.run),H.C.copy(b.map)
 if maximum then r.maxHp=maximum end;if hp then r.hp=hp end
 local n=H.Map.available(m)[1]
 for _,v in ipairs(m.nodes)do if v.id==n.id then v.type='event';v.eventId=not unentered and 'the_library' or nil end end
 if not unentered then assert(H.Nodes.enter(r,m,n.id))end
 return r,m,n.id
end
function H.reject(r,choice,token,reason)
 local before=H.snap(r);local owners={}
 local fields={'deck','nodeFlow','cardRng','miscRng','eventRng','treasureRng','unknown','relicPool','relics','potions','relicCounters','shopRng','encounters','extension','data'}
 for _,field in ipairs(fields)do owners[field]=r[field]end
 local event=r.nodeFlow.event
 local ok,why=H.Nodes.chooseEvent(r,choice,token);H.eq(ok,false);H.eq(why,reason)
 H.same(r,before);for _,field in ipairs(fields)do H.eq(r[field],owners[field])end;H.eq(r.nodeFlow.event,event)
end
function H.read(r)assert(H.Nodes.chooseEvent(r,'read'));return r.nodeFlow.event.offers end
H.count=0
function H.test(name,fn)fn();H.count=H.count+1;print('PASS Library '..H.count..' '..name)end
function H.finish(marker)print(marker..' '..H.count..' passed')end
return H
