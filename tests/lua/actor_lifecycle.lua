package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local A,C=require('abyss_actor'),require('abyss_combat')
local D=require('abyss_watcher_final_cards').withCards(require('abyss_silent_final_cards').withCardDefinitions(require('abyss_warrior_strength_cards').withCards(require('abyss_data'))))
local ids,previous,serial={},{},0
-- Freshly visit every reachable field and metatable, retaining allocation IDs
-- across checkpoints. Changed definitions plus prior definitions reconstruct
-- the entire graph, including detached tables retained by the caller.
local function graph(root)
 local visited,definitions={},{}
 local function scalar(v)
  if type(v)=='string'then return string.format('%q',v)end
  return type(v)..':'..tostring(v)
 end
 local function read(v)
  local kind=type(v)
  if kind~='table'and kind~='function'then return scalar(v)end
  if not ids[v]then serial=serial+1;ids[v]=serial end
  local id=ids[v];if visited[id]then return kind..':'..id end;visited[id]=true
  local entries={}
  if kind=='table'then
   local keys={};for k in pairs(v)do keys[#keys+1]=k end
   table.sort(keys,function(a,b)return scalar(a)<scalar(b)end)
   for _,k in ipairs(keys)do entries[#entries+1]=read(k)..'='..read(v[k])end
  end
  local definition=kind..':'..id..'{'..table.concat(entries,';')..'}meta='..read(getmetatable(v))
  if previous[id]~=definition then definitions[#definitions+1]={id,definition};previous[id]=definition end
  return kind..':'..id
 end
 local reference=read(root)
 table.sort(definitions,function(a,b)return a[1]<b[1]end)
 local result={reference};for _,v in ipairs(definitions)do result[#result+1]=v[2]end
 return table.concat(result,'\n')
end
local trace={}
local function eq(a,b,label)assert(a==b,'[ACTOR_LIFECYCLE] '..label..': '..tostring(a)..' ~= '..tostring(b))end
local function fresh()
 local s=C.new(D,{seed=42,cardRandomSeed='42',enemies={'cultist'},deck={'strike','defend'}})
 s.events={};return s,s.enemies[1]
end
local function rootFor(s)
 return {state=s,results={},anchors={player=s.player,enemy=s.enemies[1],statuses=s.player.statuses,
  enemyStatuses=s.enemies[1].statuses,events=s.events,hand=s.hand,draw=s.draw,discard=s.discard,
  powerOrder=s.player.powerOrder,enemyPowerOrder=s.enemies[1].powerOrder},trace=trace}
end
local checks=0
local function step(root,label,fn)
 local result=table.pack(pcall(fn))
 -- Lua adds implementation-specific source coordinates to string assertions.
 -- Object errors retain identity and all their fields in the graph.
 if not result[1]and type(result[2])=='string'then result[2]=result[2]:gsub('^.-:%d+: ','')end
 root.results[#root.results+1]={label=label,result=result};checks=checks+1
 return table.unpack(result,1,result.n)
end
local function checkpoint(root,label)
 local snapshot=graph(root)
 if ACTOR_LIFECYCLE_TRACE then print('ACTOR_LIFECYCLE_CHECKPOINT '..checks..' '..label..'\n'..snapshot)end
end
for _,monster in ipairs({false,true})do
 local s,e=fresh();local a=monster and e or s.player;local root=rootFor(s)
 for _,case in ipairs({{'strength',-1200},{'strength',2400},{'dexterity',-1},{'weak',2},{'weak',0},
  {'plated_armor',1000},{'plated_armor',1},{'painful_stabs',-1},{'painful_stabs',2},
  {'unawakened',-1},{'regrow',-1},{'wraith_form',-1},{'entangled',2}})do
  step(root,'raw '..tostring(monster)..' '..case[1],function()return A.addStatus(a,case[1],case[2])end)
 end
 for _,amount in ipairs({2147483647,1.5,-1,'1'})do
  step(root,'raw invalid or overflow '..tostring(amount),function()return A.addStatus(a,'weak',amount)end)
 end
 step(root,'unknown raw',function()return A.addStatus(a,'missing',1)end)
 for _,id in ipairs({'slow','time_warp','invincible','strength','dexterity','weak','vulnerable'})do
  for _,amount in ipairs({0,1,0})do
   step(root,'status '..id..' '..amount,function()return A.status(s,a,id,amount,s.player,false)end)
  end
 end
 step(root,'monster source status',function()return A.status(s,a,'frail',2,e,true)end)
 step(root,'anonymous source status',function()return A.status(s,a,'frail',1,nil,true)end)
 checkpoint(root,'status matrix '..tostring(monster))
end
do
 local s,e=fresh();local root=rootFor(s)
 s.relics={'snake_skull'}
 for _,bonus in ipairs({0,1,2})do
  step(root,'prepared poison '..bonus,function()return A.applyPower(s,e,'poison',1,s.player,false,bonus)end)
 end
 step(root,'immediate poison bonus',function()return A.applyPower(s,e,'poison',1,s.player)end)
 step(root,'poison overflow',function()return A.applyPower(s,e,'poison',2147483647,s.player)end)
 step(root,'artifact',function()return A.applyPower(s,e,'artifact',2,e)end)
 step(root,'blocked zero strength',function()return A.applyPower(s,e,'strength',0,s.player)end)
 step(root,'blocked weak',function()return A.applyPower(s,e,'weak',2,s.player)end)
 for _,id in ipairs({'demon_form','brutality','devotion','noxious_fumes','demon_form'})do
  step(root,'post draw '..id,function()return A.applyPower(s,s.player,id,1,s.player)end)
 end
 step(root,'bad constricted source',function()return A.applyPower(s,s.player,'constricted',2,e)end)
 e.ai.policy='spire_growth'
 step(root,'first constricted',function()return A.applyPower(s,s.player,'constricted',2,e)end)
 local first=s.constrictedSource;e.ai.policy='cultist'
 local e2={id='other',name='other',ai={policy='spire_growth'}}
 step(root,'stack constricted keeps source',function()return A.applyPower(s,s.player,'constricted',1,e2)end)
 eq(s.constrictedSource,first,'Constricted owner link')
 e.hp=0
 step(root,'dead unknown target short circuit',function()return A.applyPower(s,e,'missing',-1)end)
 step(root,'focus before active gate',function()return A.applyPower(s,e,'focus',1)end)
 checkpoint(root,'application gates')
end
for _,first in ipairs({'loss','wraith'})do for _,artifact in ipairs({0,1,2})do
 local s,e=fresh();local root=rootFor(s);local a=s.player
 local function loss()A.addTemporaryStrength(a,5,s);A.addTemporaryDexterity(a,4,s)end
 local function wraith()A.applyPower(s,a,'wraith_form',-2,a)end
 if first=='loss'then loss();wraith()else wraith();loss()end
 A.applyPower(s,a,'ritual',3,a);A.applyPower(s,a,'entangled',1,e);A.applyPower(s,a,'artifact',artifact,a)
 root.anchors.temporaryPowerOrder=a.temporaryPowerOrder;root.anchors.powerOrder=a.powerOrder
 step(root,'owner end '..first..' artifact '..artifact,function()return A.endTurn(s,a)end)
 step(root,'second owner end',function()return A.endTurn(s,a)end)
 checkpoint(root,'owner end '..first..' artifact '..artifact)
end end
do
 local s,e=fresh();local root=rootFor(s)
 A.addTemporaryStrength(e,3);A.addTemporaryDexterity(e,2);e.statuses.malleable=8
 root.anchors.temporaryPowerOrder=e.temporaryPowerOrder;root.anchors.enemyPowerOrder=e.powerOrder
 step(root,'monster owner end',function()return A.endTurn(s,e)end)
 e.hp=0;step(root,'inactive owner end',function()return A.endTurn(s,e)end)
 checkpoint(root,'monster end')
end
do
 local s=fresh();local root=rootFor(s);local a=s.player
 a.temporaryStrength=2;a.temporaryDexterity=1;a.statuses.strength=2;a.statuses.dexterity=1
 a.statuses.ritual=1;a.statuses.wraith_form=-1
 step(root,'legacy owner end fallback',function()return A.endTurn(s,a)end)
 checkpoint(root,'legacy fallback')
end
do
 local s,e=fresh();local root=rootFor(s)
 local oldAdd,oldActive,oldStatus,oldApply=A.addStatus,A.isActive,A.status,A.applyPower
 A.addStatus=function(...)trace[#trace+1]={'addStatus',...};return oldAdd(...)end
 A.isActive=function(...)trace[#trace+1]={'isActive',...};return oldActive(...)end
 A.status=function(...)trace[#trace+1]={'status',...};return oldStatus(...)end
 A.applyPower=function(state,target,...)
  trace[#trace+1]={'applyPower',state,target,target.temporaryStrength,target.temporaryDexterity,...}
  return oldApply(state,target,...)
 end
 step(root,'dynamic application hooks',function()return A.applyPower(s,e,'weak',2,s.player)end)
 A.addTemporaryStrength(s.player,2,s)
 step(root,'dynamic owner end hooks',function()return A.endTurn(s,s.player)end)
 local sentinel={kind='actor-lifecycle-error'};root.sentinel=sentinel
 A.addStatus=function()error(sentinel,0)end
 local ok,why=step(root,'same thrown error object',function()return A.status(s,e,'weak',1,s.player)end)
 eq(ok,false,'dynamic add throws');eq(why,sentinel,'error object identity')
 A.addStatus,A.isActive,A.status,A.applyPower=oldAdd,oldActive,oldStatus,oldApply
 checkpoint(root,'dynamic methods and object failure')
end
do
 local s,e=fresh();local root=rootFor(s);local playing
 for _,card in ipairs(s.hand)do if card.cardId=='strike'then playing=card end end
 s.catalog.cards.strike.effects={{op='applyStatus',status='strength',value=1},{op='applyStatus',status='weak',value=1}}
 local callback=function(value)return value end
 s.lifecycleCallback=callback;s.lifecycleNested={callback=callback}
 root.anchors.callback=callback;root.anchors.nested=s.lifecycleNested
 eq(rawequal(s.lifecycleCallback,root.anchors.callback),true,'function alias before rollback')
 eq(rawequal(s.lifecycleNested.callback,root.anchors.callback),true,'nested function alias before rollback')
 checkpoint(root,'shared function before rollback')
 local saved={};local function capture(t)
  if type(t)~='table'or saved[t]then return end
  local values={};saved[t]=values;for k,v in pairs(t)do values[k]=v;capture(k);capture(v)end
 end;capture(s)
 local sentinel={kind='actor-lifecycle-rollback'};root.sentinel=sentinel
 local old=A.status;A.status=function(state,target,id,...)
  if id=='weak'then
   error(sentinel,0)
  end
  return old(state,target,id,...)
 end
 local ok,why=step(root,'public card late status rollback',function()return C.play(s,playing.uid,1)end)
 A.status=old;eq(ok,false,'public late throw');eq(why,sentinel,'rollback error object')
 eq(rawequal(s.lifecycleCallback,root.anchors.callback),true,'same function restored after rollback')
 eq(rawequal(s.lifecycleNested.callback,root.anchors.callback),true,'nested function restored after rollback')
 eq(rawequal(s.lifecycleNested,root.anchors.nested),true,'same function-owning table after rollback')
 for original,values in pairs(saved)do
  for k,v in pairs(values)do eq(original[k],v,'rollback original '..tostring(k))end
  for k,v in pairs(original)do eq(v,values[k],'rollback no inserted '..tostring(k))end
 end
 step(root,'public card retry',function()return C.play(s,playing.uid,1)end)
 step(root,'public combat owner end',function()return C.endTurn(s)end)
 checkpoint(root,'public rollback retry and owner end')
end
print('ACTOR_LIFECYCLE_PASS '..checks)
