-- The Node bridge injects one complete source into a fresh VM. This file also
-- runs under the ordinary Lua runner, retaining its functional assertions.
local M=SNAPSHOT_SOURCE and assert(load(SNAPSHOT_SOURCE,'=snapshot-module'))() or require('abyss_snapshot')
local mode=SNAPSHOT_MODE or 'contract'
local function observe(label,value)
 if SNAPSHOT_GRAPH_WRITE then SNAPSHOT_GRAPH_WRITE(value,label,true)end
end
local function result(label,fn,...)
 local values=table.pack(pcall(fn,...))
 if not values[1]and type(values[2])=='string'then
  -- Only source-location provenance differs between injected and normal runners.
  values[2]=values[2]:gsub('^snapshot%-module:%d+: ',''):gsub('^%./src/lua/abyss_snapshot%.lua:%d+: ','')
 end
 observe('api:'..label,values)
 return table.unpack(values,1,values.n)
end
local function same(a,b)return rawequal(a,b)or type(a)=='number'and type(b)=='number'and a~=a and b~=b end
local function fields(node,expected)
 for k,v in next,expected do assert(same(rawget(node,k),v),'raw original field/identity must restore')end
 for k in next,node do assert(rawget(expected,k)~=nil,'new raw field must disappear')end
end

-- Count retained private tables without naming their variables or assuming a
-- layout. Exclude the complete original raw graph (including opaque functions)
-- and _ENV, then follow table keys/values and function upvalues transitively.
local function containers(restore,root)
 local excluded,queue={}, {root}
 while #queue>0 do
  local node=table.remove(queue)
  if not excluded[node]then
   excluded[node]=true
   if type(node)=='table'then for k,v in next,node do
    if type(k)=='table'or type(k)=='function'then queue[#queue+1]=k end
    if type(v)=='table'or type(v)=='function'then queue[#queue+1]=v end
   end end
  end
 end
 local visited,count={},0
 local function visit(value)
  local kind=type(value)
  if(kind~='table'and kind~='function')or excluded[value]or visited[value]then return end
  visited[value]=true
  if kind=='table'then
   count=count+1;for k,v in next,value do visit(k);visit(v)end
  else
   local index=1
   while true do
    local name,upvalue=debug.getupvalue(value,index);if not name then break end
    if name~='_ENV'then visit(upvalue)end;index=index+1
   end
  end
 end
 visit(restore);return count
end
local function widthCase(width)
 local root={};for i=1,width do root[i]={value=i,enabled=false}end
 local restore=M.capture(root)
 local count=containers(restore,root)
 for i=1,width do root[i].value=-1;root[i].enabled=true;root[i].added=true end
 restore()
 for i=1,width do fields(root[i],{value=i,enabled=false})end
 return count
end
if mode=='containers'then
 observe('containers',{narrow=widthCase(32),wide=widthCase(128)})
 return
end
if mode=='benchmark'then
 local root={};for i=1,128 do root[i]={value=i,enabled=false,shared=root}end
 local captureTime,restoreTime=0,0
 for i=1,SNAPSHOT_ITERATIONS do
  local start=os.clock();local restore=M.capture(root);captureTime=captureTime+os.clock()-start
  root[1].value=-1;start=os.clock();restore();restoreTime=restoreTime+os.clock()-start
  assert(root[1].value==1 and root[128].shared==root,'benchmark full restore')
 end
 observe('benchmark',{capture=captureTime,restore=restoreTime,iterations=SNAPSHOT_ITERATIONS})
 return
end

-- Empty boundaries, raw scalars, function/thread references and every legal
-- key class used here. No expected state is derived from snapshot internals.
do
 local root={};observe('empty:before',root)
 local ok,restore=result('capture-empty',M.capture,root);assert(ok and type(restore)=='function')
 root.added=false;observe('empty:changed',root)
 local restored,unexpected=result('restore-empty',restore);assert(restored and unexpected==nil)
 observe('empty:restored',root);fields(root,{})
 local fn=function()return 'callback'end;local thread=coroutine.create(fn);local nan=0/0
 local child,empty={},{}
 local expected={disabled=false,zero=0,negativeZero=-0.0,fraction=3.5,text='',binary='a\0b',nan=nan,inf=math.huge,negative=-math.huge,
  callback=fn,thread=thread,userdata=io.stdout,child=child,empty=empty,[false]='false-key',[true]=false,[0]='zero-key',['']='empty-key',[fn]=thread,[thread]=fn,[io.stdout]=false}
 for k,v in next,expected do root[k]=v end
 local view={root=root,child=child,empty=empty,callback=fn,thread=thread}
 observe('scalars:before',view)
 restore=M.capture(root)
 for k in next,root do rawset(root,k,nil)end
 root.new={};child.added=true;empty.added=1
 observe('scalars:changed',view);restore();observe('scalars:restored',view)
 fields(root,expected);fields(child,{});fields(empty,{})
 assert(1/root.negativeZero==-math.huge,'negative zero remains a legal scalar')
 assert(root.callback==fn and root.callback()=='callback'and root.thread==thread and rawequal(root.userdata,io.stdout),'opaque reference identity')
 root.zero=-1;root.disabled=nil;restore();observe('scalars:repeated',view);fields(root,expected)
end

-- Deterministic complete graphs: aliases, cycles, key-only components, empty
-- nodes, and data/catalog fields which are ordinary mutable reachable state.
for seed=1,6 do
 local nodes={};for i=1,24 do nodes[i]={id=i,enabled=false}end
 local root={data=nodes[1],catalog=nodes[1]}
 local keyOnly,keyChild={},{}
 keyOnly.child=keyChild;keyOnly.self=keyOnly;keyChild.parent=keyOnly
 root[keyOnly]='key-only';root.self=root
 local expected={}
 for i,node in ipairs(nodes)do
  local key=nodes[(i*7+seed)%#nodes+1]
  node.self=node;node.next=nodes[i%#nodes+1];node.shared=nodes[1];node[key]=nodes[(i*11+seed)%#nodes+1]
  expected[i]={id=i,enabled=false,self=node,next=node.next,shared=nodes[1],[key]=node[key]}
 end
 local view={root=root,nodes=nodes,keyOnly=keyOnly,keyChild=keyChild}
 local prefix='graph-'..seed
 observe(prefix..':before',view)
 local ok,restore,owner=result(prefix..'-capture',M.capture,root,keyOnly)
 assert(ok and restore==owner,'capture returns identical restore/owner functions')
 for _,node in ipairs(nodes)do for k in next,node do rawset(node,k,nil)end;node.extra={};node[{}]=false end
 root.data={};root.catalog=nil;root.self=false;keyOnly.child=nil;keyOnly.self=nil;keyChild.parent=nil
 observe(prefix..':changed',view)
 assert(select('#',restore())==0,'restore return arity');observe(prefix..':restored',view)
 for i,node in ipairs(nodes)do fields(node,expected[i])end
 fields(root,{data=nodes[1],catalog=nodes[1],self=root,[keyOnly]='key-only'})
 fields(keyOnly,{self=keyOnly,child=keyChild});fields(keyChild,{parent=keyOnly})
 assert(M.release(owner),'owner remains releasable after ordinary restore')
end

-- The graph traversal is iterative. Leaf-first anchors let the shared graph
-- observer serialize the entire deep graph without using a deep JS call stack.
do
 local root={id=0};local current=root;local chain={root};local depth=2048
 for i=1,depth do current.next={id=i};current=current.next;chain[#chain+1]=current end
 local view={}
 for i=#chain,1,-1 do view[string.format('node%05d',#chain-i)]=chain[i]end
 observe('deep:before',view);local restore=M.capture(root)
 for i,node in ipairs(chain)do node.id=-i;node.next=nil;node.added=false end
 observe('deep:changed',view);restore();observe('deep:restored',view)
 for i,node in ipairs(chain)do fields(node,{id=i-1,next=chain[i+1]})end
end

-- Metatables are not raw edges. Neither metamethods nor meta-only children are
-- traversed. A metatable reached through a raw edge is an ordinary table.
do
 local calls=0
 local function trap()calls=calls+1;error('snapshot invoked a metamethod')end
 local metaOnly={value=1}
 local mt={__index=trap,__newindex=trap,__pairs=trap,__len=trap,metaOnly=metaOnly}
 local root=setmetatable({enabled=false},mt)
 local view={root=root,mt=mt,metaOnly=metaOnly}
 observe('meta:before',view);local restore=M.capture(root)
 rawset(root,'enabled',true);rawset(root,'added',1);metaOnly.value=2
 restore();observe('meta:restored',view)
 fields(root,{enabled=false});assert(getmetatable(root)==mt and metaOnly.value==2 and calls==0,'raw visibility and meta-only boundary')
 local replacement={replacement=true};setmetatable(root,replacement)
 restore();observe('meta:replacement',view)
 assert(getmetatable(root)==replacement,'restore does not replace metatables')
 rawset(root,'rawMeta',mt);restore=M.capture(root);metaOnly.value=3;mt.added=true
 restore();observe('meta:raw-reachable',view)
 assert(metaOnly.value==2 and rawget(mt,'added')==nil,'raw-reachable metatable subtree restores')
end

-- Independent and nested savepoints remain usable in any order; ownership
-- consumption never changes the ordinary reusable restore closure.
do
 local child={value=1};local root={child=child};local other={value=9}
 local outer,owner=M.capture(root,child);local independent=M.capture(other)
 child.value=2;local inner=M.capture(root);child.value=3;other.value=10
 observe('nested:changed',{root=root,other=other})
 inner();assert(child.value==2,'inner savepoint');observe('nested:inner',{root=root,other=other})
 outer();independent();assert(child.value==1 and other.value==9,'independent outer savepoints')
 observe('nested:outer',{root=root,other=other})
 inner();assert(child.value==2,'nested restore survives outer restore');outer()
 assert(M.ownedRestore(owner,child)==outer,'ordinary restore cannot consume owner')
 assert(M.ownedRestore(owner,child)==nil,'owner single consume')
 child.value=-1;outer();assert(child.value==1,'consumed owner does not disable restore')
end

-- Observe pcall status, complete return tuples (including zero vs nil), error
-- text, closure identity, wrong targets and all owner/release lifecycle edges.
do
 local fn=function()end;local thread=coroutine.create(fn)
 for index,value in ipairs({false,0,'',fn,thread,io.stdout})do
  local ok,err=result('invalid-root-'..index,M.capture,value)
  assert(not ok and err=='snapshot requires a table','invalid root error')
 end
 local ok,err=result('invalid-root-nil',M.capture,nil)
 assert(not ok and err=='snapshot requires a table','nil root error')
 local child,keyOnly={},{};local root={child=child,[keyOnly]=false};local other={}
 for index,value in ipairs({false,0,'',fn,thread,io.stdout,other})do
  ok,err=result('invalid-target-'..index,M.capture,root,value)
  assert(not ok and err=='snapshot target is not captured','invalid/unreachable target error')
 end
 local hidden={};local mt={hidden=hidden};setmetatable(root,mt)
 ok,err=result('meta-only-target',M.capture,root,hidden)
 assert(not ok and err=='snapshot target is not captured','meta-only target is not raw reachable')
 local returns=table.pack(M.capture(root,nil));assert(returns.n==1,'nil target returns one value')
 local restore,owner=M.capture(root,keyOnly)
 assert(restore==owner and select('#',M.capture(root,root))==2,'target arity and function identity')
 result('target-functions',function()return restore,owner,restore==owner end)
 for index,value in ipairs({false,0,'',fn,thread,io.stdout,{},restore})do
  local success,returned=result('wrong-owner-'..index,M.ownedRestore,value,other)
  assert(success and returned==nil,'wrong owner returns zero values')
 end
 result('nil-owner',M.ownedRestore,nil,keyOnly)
 assert(M.ownedRestore(nil,keyOnly)==nil,'nil owner')
 result('cross-target',M.ownedRestore,owner,child);assert(M.ownedRestore(owner,child)==nil,'cross target cannot consume')
 result('nil-target',M.ownedRestore,owner,nil)
 result('ordinary-restore',restore)
 ok,returns=result('consume',M.ownedRestore,owner,keyOnly);assert(ok and returns==restore,'key-only owner')
 ok,returns=result('consume-twice',M.ownedRestore,owner,keyOnly);assert(ok and returns==nil,'owner single consume')
 ok,returns=result('release-consumed',M.release,owner);assert(ok and returns==false,'consumed release')
 local _,fresh=M.capture(root,child)
 ok,returns=result('release',M.release,fresh);assert(ok and returns==true,'fresh release')
 ok,returns=result('release-twice',M.release,fresh);assert(ok and returns==false,'release once')
 ok,returns=result('consume-released',M.ownedRestore,fresh,child);assert(ok and returns==nil,'released owner cannot consume')
 for index,value in ipairs({false,0,'',fn,thread,io.stdout,{}})do
  ok,returns=result('release-invalid-'..index,M.release,value);assert(ok and returns==false,'invalid release')
 end
 result('release-nil',M.release,nil)
 local equalMeta={__eq=function()return true end};setmetatable(child,equalMeta)
 local twin=setmetatable({},equalMeta);local owned,token=M.capture(root,child)
 assert(child==twin and not rawequal(child,twin),'fixture exercises table __eq')
 ok,returns=result('equal-not-identical-target',M.ownedRestore,token,twin);assert(ok and returns==nil,'owner target must be raw-identical')
 assert(M.ownedRestore(token,child)==owned,'wrong equal target cannot consume owner')
 local _,otherOwner=M.capture(other,other)
 assert(M.ownedRestore(otherOwner,root)==nil and M.ownedRestore(otherOwner,other)==otherOwner,'cross-graph owner')
end
observe('contract:complete',{complete=true})
if not SNAPSHOT_GRAPH_WRITE then print('SNAPSHOT_FLAT_CONTRACT_PASS')end
