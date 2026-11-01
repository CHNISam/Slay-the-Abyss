-- Controlled staged-room fixtures, not proof of natural pool admission/native
-- play. All effects execute the REAL Nodes commands and Run transactions.
local H={}
H.C,H.Run,H.Map,H.Nodes=require('abyss_combat'),require('abyss_run'),require('abyss_map'),require('abyss_nodes')
H.R,H.Data,H.Pool,H.Hooks=require('abyss_sts_random'),require('abyss_data'),require('abyss_event_pool'),require('abyss_relic_hooks')
local base=H.Run.new(H.Data,'42',{experimental=true,campaign=true})
base.act,base.floor=2,17;base.unknown.pools=H.Pool.new('full',false,2)
local baseMap=H.Map.generate(base.data,'42',2)
function H.eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
function H.same(a,b,path)
    if a==b then return end;path=path or 'state';H.eq(type(a),type(b))
    if type(a)~='table'then assert(a==b,path..': '..tostring(a)..' ~= '..tostring(b));return end
    for k,v in pairs(a)do H.same(v,b[k],path..'.'..tostring(k))end
    for k in pairs(b)do assert(a[k]~=nil,path..' missing '..tostring(k))end
end
function H.snapshot(run)return H.C.copy(run,{[run.data]=run.data})end
function H.fixture(id,setup)
    local run,map=H.snapshot(base),H.C.copy(baseMap)
    if setup then setup(run)end
    local n=H.Map.available(map)[1]
    for _,node in ipairs(map.nodes)do if node.id==n.id then node.type,node.eventId='event',id end end
    local ok,why=H.Nodes.enter(run,map,n.id);assert(ok,why)
    return run,map
end
function H.reject(run,choice,uid,reason)
    local before=H.snapshot(run);local owners={}
    for key,value in pairs(run)do if type(value)=='table'then owners[key]=value end end
    local ok,why=H.Nodes.chooseEvent(run,choice,uid);H.eq(ok,false);if reason then H.eq(why,reason)end
    H.same(run,before)
    for key,value in pairs(owners)do H.eq(run[key],value)end
end
function H.withHook(name,replacement,body)
    local old=H.Hooks[name];H.Hooks[name]=replacement(old)
    local ok,why=pcall(body);H.Hooks[name]=old;assert(ok,why)
end
function H.removeDefinition(run,kind,id)
    local original=run.data;run.data=H.C.copy(run.data)
    for i=#run.data[kind][kind],1,-1 do if run.data[kind][kind][i].id==id then table.remove(run.data[kind][kind],i)end end
    return original
end
local count=0
function H.test(name,body)body();count=count+1;print('PASS '..name)end
function H.finish(marker)print(marker..' '..count..' passed')end
return H
