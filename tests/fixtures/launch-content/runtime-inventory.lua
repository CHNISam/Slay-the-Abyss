-- Read-only inventory probe. Exhaust finite formation decisions rather than
-- sampling seeds or counting eager constructors which may be discarded.
local Queue,Bindings,Formation=require('abyss_encounter_queue'),require('abyss_room_encounters'),require('abyss_encounter_formation')
local function quote(s)return '"'..s:gsub('\\','\\\\'):gsub('"','\\"')..'"'end
local function json(value)
 if type(value)=='string'then return quote(value)end
 if type(value)~='table'then return tostring(value)end
 local rows={}
 if #value>0 then for _,v in ipairs(value)do rows[#rows+1]=json(v)end;return '['..table.concat(rows,',')..']'end
 for k,v in pairs(value)do rows[#rows+1]=quote(k)..':'..json(v)end;return '{'..table.concat(rows,',')..'}'
end
local records,index={},{}
for _,pool in ipairs({'weak','strong','elite'})do for _,item in ipairs(Queue.rules()[pool])do
 local source=item[1];local tier=pool=='elite' and 'elite' or 'normal'
 local row=index[source]
 if not row then
  local binding=assert(Bindings.resolve(source,tier))
  row={runtimeId=binding.id,sourceName=source,tier=tier,queuePools={},dynamic=binding.sourceEncounter~=nil,traces={}}
  records[#records+1]=row;index[source]=row
  if not row.dynamic then row.traces={{path='',members=binding.enemies}}end
 end
 row.queuePools[#row.queuePools+1]=pool
end end
for _,row in ipairs(records)do if row.dynamic then
 local leaves=0
 local function visit(prefix)
  local cursor,path=0,{}
  local function pick(kind,lo,hi)
   cursor=cursor+1
   if prefix[cursor]==nil then error({decision=true,kind=kind,lo=lo,hi=hi})end
   local choice=prefix[cursor];path[#path+1]=kind..':'..lo..':'..hi..':'..choice
   return choice
  end
  local ok,result=pcall(Formation.assemble,row.sourceName,{
   misc={boolean=function()return pick('B',0,1)==1 end,integer=function(lo,hi)return pick('I',lo,hi)end},
   visualFloat=function()return 0 end,construct=function(id)return {id=id}end})
  if not ok then
   assert(type(result)=='table' and result.decision,result)
   for choice=result.lo,result.hi do
    local nextPrefix={};for i,v in ipairs(prefix)do nextPrefix[i]=v end
    nextPrefix[#nextPrefix+1]=choice;visit(nextPrefix)
   end
  else
   local members={};for _,actor in ipairs(result)do members[#members+1]=actor.id end
   leaves=leaves+1;assert(leaves<=100000,'formation inventory exceeds finite budget')
   row.traces[#row.traces+1]={path=table.concat(path,'/'),members=members}
  end
 end
 visit({})
end end
local Run,Nodes,Map=require('abyss_run'),require('abyss_nodes'),require('abyss_map')
local run=Run.new(LAUNCH_DATA,'42');local map=Map.generate(LAUNCH_DATA,'42')
local source=Queue.peek(run.encounters,'normal');local first=Nodes.available(run,map)[1]
for _,node in ipairs(map.nodes)do if node.id==first.id then node.encounterId='medium_slimes'end end
assert(Nodes.enter(run,map,first.id))
assert(run.encounterSource==source and run.encounterId==Bindings.resolve(source,'normal').id,'formal Nodes entry bypassed source bindings')
local boss=Run.new(LAUNCH_DATA,'42');boss.floor=16;assert(Run.startRoomCombat(boss,'boss'))
local members={};for _,enemy in ipairs(boss.combat.enemies)do members[#members+1]=enemy.definitionId end
records[#records+1]={runtimeId=boss.encounterId,sourceName=boss.encounterSource,tier='boss',queuePools={'boss:guardian-unseen'},
 dynamic=false,traces={{path='',members=members}}}
for _,row in ipairs(records)do print('LAUNCH_RUNTIME\t'..json(row))end
print('LAUNCH_RUNTIME_ENTRY_PASS')
