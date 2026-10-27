-- Component-only source queues/navigation and mocked native controls. No live
-- input, natural acquisition, history unlock or platform acceptance is claimed.
local H=dofile('tests/helpers/act2_event_ui.lua')
local Source=dofile('tests/lua/support/sapphire_source_fixture.lua')
local base=H.Run.new(H.Data,'42',{experimental=true,campaign=true});base.endingUnlocked=true
local baseMap=H.Map.generate(base.data,'42');local first=H.Map.available(baseMap)[1]
for _,node in ipairs(baseMap.nodes)do if node.id==first.id then node.type='treasure'end end
local function fixture(gold,legacy)
 local run,map=H.snapshot(base),H.Copy(baseMap)
 if legacy then run.relicPool=nil else Source.stage(run,{gold=gold and '42' or nil})end
 assert(H.Nodes.enter(run,map,first.id));return run,map
end
local function references(root)
 local refs,seen={},{}
 local function walk(owner)
  if seen[owner]then return end;seen[owner]=true
  for key,value in pairs(owner)do if type(value)=='table'then
   refs[#refs+1]={owner,key,value};walk(value)
  end end
 end
 walk(root);return refs
end
local function refused(run,map,command)
 local before,mbefore=H.snapshot(run),H.Copy(map)
 local refs,mrefs=references(run),references(map)
 local called,ok,why=pcall(command);assert(called,'refusal threw: '..tostring(ok))
 H.eq(ok,false);assert(type(why)=='string');H.same(run,before);H.same(map,mbefore)
 for _,owners in ipairs({refs,mrefs})do for _,ref in ipairs(owners)do H.eq(ref[1][ref[2]],ref[3])end end
 return why
end
H.test('byte-equal reward-items replacement retires both original source gestures; fresh plain gestures work',function()
 for _,path in ipairs({'treasureView/take','confirm'})do
  local run,map=fixture();local ui,get,shown,click=H.setup(run,map)
  assert(click('treasureView/chest') and shown(path))
  local token=assert(H.Nodes.treasureSource(run,map));local hit=get(path..'/hit')
  local handler=ui.actions[path].handler;hit:emit('down',91)
  run.nodeFlow.reward.items=H.Copy(run.nodeFlow.reward.items)
  H.eq(token.itemsSignature,assert(H.Nodes.treasureSource(run,map)).itemsSignature)
  H.eq(refused(run,map,function()hit:emit('up',91);return hit:emit('click',91)end),'stale_action')
  H.eq(refused(run,map,handler),'stale_action')
  ui:render()
  local expected,em=H.snapshot(run),H.Copy(map)
  local choice=path=='confirm' and 'sapphire' or 'relic'
  assert(H.Nodes.chooseTreasure(expected,em,assert(H.Nodes.treasureSource(expected,em)),choice))
  assert(click(path,92));H.same(run,expected);H.same(map,em)
 end
end)
H.test('selected gold and relic row metatables refuse before graph copy; unchanged plain rows still claim',function()
 for _,kind in ipairs({'gold','relic'})do
  local run,map=fixture(kind=='gold');assert(H.Nodes.openTreasure(run))
  local row
  for _,item in ipairs(run.nodeFlow.reward.items)do if item.kind==kind then row=item;break end end
  assert(row);local token=assert(H.Nodes.treasureRewardSource(run,row.slot))
  local beforeGold,beforeRelics=run.gold,#run.relics
  local meta={};setmetatable(row,meta)
  local projected,reason=H.Nodes.treasureRewardSource(run,row.slot)
  H.eq(projected,nil);H.eq(reason,'treasure_source_mismatch')
  H.eq(refused(run,map,function()return H.Nodes.claimTreasureReward(run,token)end),'treasure_source_mismatch')
  H.eq(getmetatable(row),meta);H.eq(run.gold,beforeGold);H.eq(#run.relics,beforeRelics)
  setmetatable(row,nil)
  local expected=H.snapshot(run);assert(H.Nodes.claimTreasureReward(expected,token))
  assert(H.Nodes.claimTreasureReward(run,token));H.same(run,expected)
  if kind=='gold'then H.eq(run.gold,beforeGold+23);H.eq(#run.relics,beforeRelics)
  else H.eq(#run.relics,beforeRelics+1);H.eq(run.keys.sapphire,false)end
 end
end)
H.test('ignored malformed-row child refusal poisons an enclosing permanent transaction',function()
 local run,map=fixture(true);assert(H.Nodes.openTreasure(run))
 local row=run.nodeFlow.reward.items[1];H.eq(row.kind,'gold')
 local token=assert(H.Nodes.treasureRewardSource(run,row.slot));local called=false
 H.eq(refused(run,map,function()return H.Run.transaction(run,function(staged)
  staged.gold=staged.gold+91;setmetatable(staged.nodeFlow.reward.items[1],{})
  local ok,why=H.Nodes.claimTreasureReward(staged,token)
  H.eq(ok,false);H.eq(why,'treasure_source_mismatch');called=true
  return true -- Intentionally ignore the failed child command.
 end)end),'treasure_source_mismatch')
 assert(called);assert(H.Nodes.claimTreasureReward(run,token))
end)
H.test('legacy nil-items source choices remain valid through unchanged generated UI controls',function()
 for _,path in ipairs({'treasureView/take','confirm'})do
  local run,map=fixture(false,true);assert(not run.nodeFlow.chest and not run.nodeFlow.reward.items)
  local _,_,shown,click=H.setup(run,map);assert(click('treasureView/chest') and shown(path))
  local expected,em=H.snapshot(run),H.Copy(map)
  assert(H.Nodes.chooseTreasure(expected,em,assert(H.Nodes.treasureSource(expected,em)),path=='confirm' and 'sapphire' or 'relic'))
  assert(click(path));H.same(run,expected);H.same(map,em)
 end
end)
print('SOURCE_TREASURE_OWNER_GUARDS '..H.count..' passed')
