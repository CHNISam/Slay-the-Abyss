local Map=require('abyss_map')
local E=require('abyss_emerald_elite')
local R=require('abyss_sts_random')
local Copy=require('abyss_copy').copy
assert(type(Map.prepareEmeraldBoost)=='function','missing source Map boost boundary')
assert(type(Map.commitEmeraldBoost)=='function','missing source Map boost commit')
local Data={rules={map={floors=17,generatedRows=15,bossFloor=16,bossTreasureFloor=17,restFloor=15,treasureFloor=9,
 nodeTypes={'combat','elite','camp','shop','event','treasure','boss'}}},enemies={encounters={}}}
local active={endingUnlocked=true,emeraldOwned=false}
local function same(a,b)
 assert(type(a)==type(b))
 if type(a)~='table'then assert(a==b,tostring(a)..' ~= '..tostring(b));return end
 for k,v in pairs(a)do same(v,b[k])end
 for k in pairs(b)do assert(a[k]~=nil,tostring(k))end
end
local function route(map,target)
 local index={};for _,node in ipairs(map.nodes)do index[node.id]=node end
 local function find(id)
  if id==target then return {id}end
  for _,nextId in ipairs(index[id].nextIds)do
   local path=find(nextId)
   if path then table.insert(path,1,id);return path end
  end
 end
 for _,node in ipairs(Map.available(map))do local path=find(node.id);if path then return path end end
 error('selected source elite has no path')
end
local function beforeSelected(map)
 local path=route(map,map.emeraldSelection.nodeId)
 for i=1,#path-1 do assert(Map.choose(map,path[i]))end
 return path[#path]
end
local maps={}
do
 for act=1,4 do
  local old=Map.generate(Data,'42',act)
  same(Map.generate(Data,'42',act,{endingUnlocked=false,emeraldOwned=false}),old)
  same(Map.generate(Data,'42',act,{endingUnlocked=true,emeraldOwned=true}),old)
  assert(not old.emeraldSelection and not old.mapRng and not old.emeraldBoost)
  local current=Map.generate(Data,'42',act,active)
  if act==4 then same(current,old)else
   maps[act]=current
   local selected,nextRng=E.select(old,R.restore(old.randomState),active)
   same(current.emeraldSelection,selected);same(current.mapRng,R.snapshot(nextRng))
   assert(current.mapRng.counter==old.randomState.counter+1)
   local plain=Copy(current);plain.emeraldSelection,plain.mapRng=nil,nil
   local count=0
   for _,node in ipairs(plain.nodes)do
    if node.hasEmeraldKey then assert(node.id==selected.nodeId);count=count+1;node.hasEmeraldKey=nil end
   end
   assert(count==1);same(plain,old)
  end
 end
end
do
 for act=1,3 do
  local map=Copy(maps[act]);local nodeId=map.emeraldSelection.nodeId
  local draw=R.randomIntBetween;local calls=0
  R.randomIntBetween=function(...)calls=calls+1;return draw(...)end
  assert(not Map.prepareEmeraldBoost(map,nodeId),'distant elite is unavailable')
  R.randomIntBetween=draw;assert(calls==0,'unavailable node must not even prepare a private draw')
  beforeSelected(map)
  local snapshot=Copy(map);local boost,nextRng=Map.prepareEmeraldBoost(map,nodeId)
  assert(boost and boost.effect.nodeId==nodeId)
  same(map,snapshot);same(boost.beforeRng,map.mapRng);same(boost.afterRng,nextRng)
  local effect,after=E.prepare(map.emeraldSelection,R.restore(map.mapRng))
  same(boost.effect,effect);same(nextRng,R.snapshot(after))
  assert(not Map.commitEmeraldBoost(map,nodeId,boost),'must choose before publishing boost')
  assert(Map.choose(map,nodeId));assert(Map.commitEmeraldBoost(map,nodeId,boost))
  same(map.mapRng,nextRng);same(map.emeraldBoost,boost)
  local committed=Copy(map);assert(not Map.commitEmeraldBoost(map,nodeId,boost));same(map,committed)
  assert(not Map.prepareEmeraldBoost(map,nodeId))
  same(Map.restore(Data,Map.snapshot(map),active),map)
 end
end
do
 local map=Copy(maps[1]);local nodeId=beforeSelected(map)
 local boost=assert(Map.prepareEmeraldBoost(map,nodeId));assert(Map.choose(map,nodeId))
 for _,field in ipairs({'runSeed','mapSeed','mapSignature','nodeId'})do
  local wrong=Copy(boost);wrong[field]='foreign';local before=Copy(map)
  assert(not Map.commitEmeraldBoost(map,nodeId,wrong),field);same(map,before)
 end
 for _,field in ipairs({'beforeRng','afterRng'})do
  local wrong=Copy(boost);wrong[field].counter=wrong[field].counter+1
  assert(not Map.commitEmeraldBoost(map,nodeId,wrong),field)
 end
 local wrong=Copy(boost);wrong.effect.roll=(wrong.effect.roll+1)%4
 assert(not Map.commitEmeraldBoost(map,nodeId,wrong))
 wrong=Copy(boost);wrong.extra=true;assert(not Map.commitEmeraldBoost(map,nodeId,wrong))
 assert(Map.commitEmeraldBoost(map,nodeId,boost))
 boost.effect.roll=(boost.effect.roll+1)%4
 assert(map.emeraldBoost.effect.roll~=boost.effect.roll,'map must detach caller boost')
end
do
 local map=Copy(maps[2]);local nodeId=beforeSelected(map)
 same(Map.restore(Data,Map.snapshot(map),active),map)
 local boost=assert(Map.prepareEmeraldBoost(map,nodeId));assert(Map.choose(map,nodeId))
 assert(not Map.restore(Data,Map.snapshot(map),active),'uncommitted reached elite cannot restore')
 assert(Map.commitEmeraldBoost(map,nodeId,boost))
 local snapshot=Map.snapshot(map)
 assert(not Map.restore(Data,snapshot),'snapshot must not grant its own qualification')
 assert(not Map.restore(Data,snapshot,{endingUnlocked=false,emeraldOwned=false}))
 assert(not Map.restore(Data,snapshot,{endingUnlocked=true,emeraldOwned=true}))
 local changed=Copy(snapshot);changed.mapRng.counter=changed.mapRng.counter+1
 assert(not Map.restore(Data,changed,active))
 changed=Copy(snapshot);changed.emeraldBoost.effect.roll=(changed.emeraldBoost.effect.roll+1)%4
 assert(not Map.restore(Data,changed,active))
 changed=Copy(snapshot);changed.emeraldSelection.nodeId='foreign'
 assert(not Map.restore(Data,changed,active))
end
do
 local map=Copy(maps[3]);local nodeId=beforeSelected(map);local snapshot=Copy(map)
 assert(not Map.prepareEmeraldBoost(map,'foreign'));same(map,snapshot)
 local wrong=Copy(map);wrong.mapRng={}
 assert(not Map.prepareEmeraldBoost(wrong,nodeId))
 wrong=Copy(map);wrong.emeraldSelection.x=nil
 assert(not Map.prepareEmeraldBoost(wrong,nodeId))
 wrong=Copy(map);wrong.act=false
 assert(not Map.prepareEmeraldBoost(wrong,nodeId))
 wrong=Copy(map)
 for _,node in ipairs(wrong.nodes)do if node.id==nodeId then node.hasEmeraldKey=nil end end
 assert(not Map.prepareEmeraldBoost(wrong,nodeId))
 assert(not pcall(Map.generate,Data,'42',1,{endingUnlocked='yes',emeraldOwned=false}))
 assert(not Map.restore(Data,snapshot,{endingUnlocked=true}))
end
do
 local old=Map.generate(Data,'42',1)
 assert(not Map.prepareEmeraldBoost(old,Map.available(old)[1].id))
 same(Map.restore(Data,Map.snapshot(old)),old)
 local map=Copy(maps[1]);local nodeId=beforeSelected(map)
 local boost,nextRng=Map.prepareEmeraldBoost(map,nodeId)
 nextRng.counter=nextRng.counter+7;assert(boost.afterRng.counter~=nextRng.counter)
 same(Map.restore(Data,Map.snapshot(map),active),map)
end
print('EMERALD_MAP 6 groups; 0 failed; battle integration NOT_RUN')
