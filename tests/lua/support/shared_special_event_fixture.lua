local Run,C,R=require('abyss_run'),require('abyss_combat'),require('abyss_sts_random')
local Data=require('abyss_data')
local M={Run=Run,C=C,R=R,count=0}
function M.eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
function M.same(a,b)
 if a==b then return end;M.eq(type(a),type(b))
 if type(a)~='table'then M.eq(a,b);return end
 for k,v in pairs(a)do M.same(v,b[k])end
 for k in pairs(b)do assert(a[k]~=nil,'unexpected '..tostring(k))end
end
function M.snapshot(r)return C.copy(r,{[r.data]=r.data})end
local base=Run.new(Data,'42',{experimental=true,campaign=true,character='ironclad'})
function M.fixture(module,id)
 local r=M.snapshot(base);r.phase,r.act,r.floor,r.gold='node',2,18,200
 r.nodeFlow={type='event',event={id=id}}
 assert(Run.transaction(r,function(s)module.prepare(s,s.nodeFlow.event,s.miscRng,18);return true end))
 return r
end
function M.choose(module,r,choice,uid)
 return Run.transaction(r,function(s)return module.choose(s,s.nodeFlow,choice,uid)end)
end
function M.reject(module,r,choice,uid,reason)
 local before=M.snapshot(r);local owners={}
 for k,v in pairs(r)do if type(v)=='table'then owners[k]=v end end
 local event=r.nodeFlow.event;local ok,why=M.choose(module,r,choice,uid)
 M.eq(ok,false);if reason then M.eq(why,reason)end;M.same(r,before)
 for k,v in pairs(owners)do M.eq(r[k],v)end;M.eq(r.nodeFlow.event,event)
end
function M.ready(module,r)assert(M.choose(module,r,'continue'));M.eq(r.nodeFlow.event.stage,'choice')end
function M.test(name,fn)
 if ABYSS_MUTATION_CASE~=nil and ABYSS_MUTATION_CASE~=name then return end
 local ok,why=pcall(fn);assert(ok,name..': '..tostring(why))
 M.count=M.count+1;print('PASS shared special '..M.count..' '..name)
end
return M
