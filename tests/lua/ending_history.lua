-- Pure history ownership boundaries; terminal fixtures are not natural wins.
local loaded,H=pcall(require,'abyss_ending_history')
assert(loaded,'ENDING_HISTORY_MODULE_MISSING: '..tostring(H))
local count=0
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function test(name,fn)fn();count=count+1;print('PASS ending history '..count..' '..name)end
local function snapshot(a,b,c)return {version=1,wins={ironclad=a,silent=b,defect=c}}end
local function start(owner,role,context,original)
 local run={character=role,campaign=true,act=1,floor=1,phase='map',runSeed='42',
  characterProfile=original and {originalV4=true,id=role}or nil}
 local state=H.begin(owner,run,context or {seedSet=false,isDailyRun=false,isTrial=false})
 assert(state);return run,state
end
local function terminal(run)
 local id='f51_l4';local map={act=3,floor=51,currentNodeId=id,runSeed='42',sourceSignature='source-map',
  path={'f50_l4',id},nodes={{id=id,floor=51,type='event',roomKind='ending'}}}
 run.act,run.floor,run.phase=3,51,'victory';run.encounterTier,run.encounterId='boss','actual_boss'
 run.lastResult={outcome='victory',encounterId='actual_boss'}
 run.nodeFlow={id=id,floor=51,type='event',roomKind='ending',complete=true,result='normal_victory',
  mapSeed='42',mapSignature=map.sourceSignature}
 return map
end
test('missing corrupt and failing providers retain unknown locked state',function()
 for _,provider in ipairs({{}, {read=function()error('offline')end},
  {read=function()return snapshot(true,true,1)end},{read=function()return {version=1,wins={ironclad=true,silent=true}}end},
  {read=function()return setmetatable(snapshot(true,true,true),{})end},
  {read=function()local s=snapshot(true,true,true);s.wins.watcher=true;return s end}})do
  local owner=H.new(provider);local state=H.read(owner)
  eq(state.known,false);eq(state.unlocked,false);eq(next(state.wins),nil)
 end
end)
test('provider values and public snapshots stay detached and are read once per owner',function()
 local values=snapshot(true,true,true);local calls=0
 local owner=H.new({read=function()calls=calls+1;return values end})
 local state=H.read(owner);eq(state.known,true);eq(state.unlocked,true)
 state.wins.ironclad=false;values.wins.defect=false
 eq(H.read(owner).unlocked,true);eq(calls,1);eq(H.read(H.new()).unlocked,false)
end)
test('default traveler plus real session Silent and Defect terminal commands unlock only next starts',function()
 local owner=H.new();local runs={}
 for _,role in ipairs({'traveler','silent','defect'})do
  local selected=role;if role=='traveler'then selected=nil end
  local run,before=start(owner,selected);runs[#runs+1]=run
  eq(before.unlocked,false);local map=terminal(run);assert(H.finish(owner,run,map))
  eq(before.unlocked,false,'begin status must not change retroactively')
  eq(H.finish(owner,run,map),false)
 end
 local _,nextState=start(owner,'watcher');eq(nextState.known,true);eq(nextState.unlocked,true)
 eq(nextState.persistence,'unavailable');eq(H.read(H.new()).unlocked,false)
end)
test('fixed-seed daily and trial victory cannot set WIN or write provider state',function()
 for _,key in ipairs({'seedSet','isDailyRun','isTrial'})do
  local writes=0;local owner=H.new({read=function()return snapshot(false,false,false)end,
   write=function()writes=writes+1;return true end})
  local context={seedSet=false,isDailyRun=false,isTrial=false};context[key]=true
  local run=start(owner,'ironclad',context);context[key]=false
  eq(H.finish(owner,run,terminal(run)),false)
  eq(H.read(owner).wins.ironclad,false);eq(writes,0)
 end
 local owner=H.new({read=function()return snapshot(true,true,true)end})
 local _,seeded=start(owner,'ironclad',{seedSet=true,isDailyRun=false,isTrial=false})
 eq(seeded.unlocked,true,'known wins permit seeded final act; seeded wins never create WIN')
 for _,key in ipairs({'isDailyRun','isTrial'})do
  local c={seedSet=false,isDailyRun=false,isTrial=false};c[key]=true
  local _,state=start(owner,'ironclad',c);eq(state.unlocked,false)
 end
end)
test('Watcher originals unknown roles changed identities and unregistered runs never contribute',function()
 for _,role in ipairs({'watcher','hutao','arlecchino','furina','raiden','HT','AR','FR','RD','unknown','ironclad'})do
  local owner=H.new();local run=start(owner,role,nil,role~='watcher'and role~='unknown')
  eq(H.finish(owner,run,terminal(run)),false);eq(next(H.read(owner).wins),nil)
 end
 local owner=H.new();local run=start(owner,'silent');run.character='ironclad'
 eq(H.finish(owner,run,terminal(run)),false);eq(next(H.read(owner).wins),nil)
 local foreign={};eq(H.finish(owner,foreign,terminal(foreign)),false)
 for _,marker in ipairs({'originalV4Role','originalV4Rules'})do
  local legacy={campaign=true,act=1,floor=1,phase='map',runSeed='42',data={[marker]='HT'}}
  local history=H.new();assert(H.begin(history,legacy,{seedSet=false,isDailyRun=false,isTrial=false}))
  eq(H.finish(history,legacy,terminal(legacy)),false);eq(next(H.read(history).wins),nil)
 end
 local warrior={campaign=true,act=1,floor=1,phase='map',runSeed='42',
  data={experimentalCharacter='ironclad',characterId='ironclad'}}
 local history=H.new();assert(H.begin(history,warrior,{seedSet=false,isDailyRun=false,isTrial=false}))
 assert(H.finish(history,warrior,terminal(warrior)),'ordinary legacy Ironclad is not an OriginalV4 role')
 eq(H.read(history).wins.ironclad,true)
end)
test('defeat abandon legacy Act1 and inconsistent source terminal cannot set WIN',function()
 local changes={
  function(r)r.phase='defeat'end,function(r)r.phase='combat'end,
  function(r)r.act=1;r.floor=17 end,function(r)r.nodeFlow.complete=false end,
  function(r)r.nodeFlow.result='ending_door'end,function(r)r.lastResult.outcome='escaped'end,
  function(r)r.lastResult.encounterId='foreign'end,function(r)r.encounterTier='normal'end,
  function(_,m)m.currentNodeId='foreign'end,function(_,m)m.runSeed='43'end,
  function(_,m)m.sourceSignature='foreign'end,function(_,m)m.nodes[1].roomKind='other'end,
  function(_,m)m.path[#m.path]='foreign'end,
 }
 for _,change in ipairs(changes)do
  local owner=H.new();local r=start(owner,'ironclad');local map=terminal(r);change(r,map)
  eq(H.finish(owner,r,map),false);eq(next(H.read(owner).wins),nil)
 end
end)
test('write uses one detached monotonic class delta and never overwrites unknown histories',function()
 local calls,delta=0,nil;local owner=H.new({write=function(value)
  calls=calls+1;delta=value;value.wins.ironclad=false;return true
 end})
 local run=start(owner);local map=terminal(run);assert(H.finish(owner,run,map));eq(calls,1)
 eq(delta.version,1);eq(delta.wins.silent,nil);eq(delta.wins.defect,nil)
 eq(H.read(owner).wins.ironclad,true);eq(H.read(owner).known,false)
 eq(H.finish(owner,run,map),false);eq(calls,1)
end)
test('failed persistence keeps authentic session progress but reports failure and cannot invent missing wins',function()
 for _,writer in ipairs({function()error('offline')end,function()return false end,function()return nil end})do
  local owner=H.new({read=function()return snapshot(false,true,true)end,write=writer})
  local run,before=start(owner);eq(before.unlocked,false)
  assert(H.finish(owner,run,terminal(run)));local state=H.read(owner)
  eq(state.wins.ironclad,true);eq(state.unlocked,true);eq(state.persistence,'write_failed')
  eq(H.read(H.new({read=function()error('offline')end})).unlocked,false)
 end
end)
print('ENDING_HISTORY '..count..' passed')
