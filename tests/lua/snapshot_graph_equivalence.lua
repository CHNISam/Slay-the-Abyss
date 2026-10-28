local old=dofile('tests/lua/support/snapshot_legacy_20261028.lua')
local new=require('abyss_snapshot')
local checks=0
local function equal(a,b)return rawequal(a,b)or type(a)=='number'and a~=a and b~=b end
local function exercise(M,seed)
 local nodes={};for i=1,36 do nodes[i]={id=i,label='node'..i}end
 local random=seed
 local function pick()random=(random*25173+13849)%65536;return random%#nodes+1 end
 local fn=function()return seed end
 for i,node in ipairs(nodes)do
  if i%3==0 then node.value=false else node.value=i end
  node.shared=nodes[1];node.self=node;node.next=nodes[i%#nodes+1]
  node[nodes[pick()]]=nodes[pick()];node['slot'..pick()]=nodes[pick()]
  node.callback=fn;node.inf=math.huge;node.nan=0/0
 end
 local library={id=2,definitions={enabled=false,rule=7}}
 local root={nodes=nodes,data=library,catalog=library}
 -- This component is reachable only through a table key, not through values.
 local keyOnly={label='keyOnly',enabled=false};local keyChild={label='keyChild'}
 keyOnly.child=keyChild;keyOnly.self=keyOnly;keyChild.parent=keyOnly
 root[keyOnly]='table-key-only edge'
 local original={};local pending={root};local top=1
 while top>0 do local node=pending[top];pending[top]=nil;top=top-1
  if not original[node]then local copy={};original[node]=copy;for k,v in next,node do copy[k]=v;if type(k)=='table'then top=top+1;pending[top]=k end;if type(v)=='table'then top=top+1;pending[top]=v end end end
 end
 local restore,owner=M.capture(root,keyOnly);assert(restore==owner)
 assert(M.ownedRestore(owner,{})==nil,'cross-graph targets cannot consume owner')
 assert(M.ownedRestore(owner,keyOnly)==restore);assert(M.ownedRestore(owner,keyOnly)==nil,'single-use capability')
 for node in next,original do for k in next,node do node[k]=nil end;node.changed={seed=seed};node[{}]='added table key'end
 restore()
 for node,copy in next,original do
  for k,v in next,copy do assert(equal(rawget(node,k),v),'all original fields and identities must restore')end
  for k in next,node do assert(copy[k]~=nil,'all newly added fields must disappear')end
 end
 assert(root.data==root.catalog and root.nodes==nodes,'shared data/catalog and array owners retained')
 assert(root[keyOnly]=='table-key-only edge'and keyOnly.child==keyChild and keyChild.parent==keyOnly and keyOnly.self==keyOnly,'key-only graph and identities retained')
 assert(keyOnly.enabled==false and nodes[3].value==false,'false values must not turn into absent fields')
 root.data.id=-1;restore();assert(root.data.id==2,'restore remains reusable independently of owner capability')
 local _,fresh=M.capture(root,nodes[1]);assert(M.release(fresh));assert(not M.release(fresh));assert(M.ownedRestore(fresh,nodes[1])==nil)
 assert(not pcall(M.capture,false));assert(not pcall(M.capture,root,{}));assert(not pcall(M.capture,root,false))
 checks=checks+1
end
for seed=1,48 do exercise(old,seed);exercise(new,seed)end
for _,M in ipairs({old,new})do
 local root={};local current=root;for i=1,20000 do current.next={value=i};current=current.next end
 local leaf=current;local restore=M.capture(root);leaf.value=-1;root.extra=leaf;restore();assert(leaf.value==20000 and root.extra==nil,'deep graph stays iterative and complete')
end
print('SNAPSHOT_EQUIVALENCE_PASS '..checks)
