-- Controlled legal rooms, not a natural route or native-client/device proof.
-- Real competition profile, source catalog, generated UI, Nodes and Run commands;
-- only native controls are mocked by the existing fixture. Reuse one control tree.
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local H=dofile('tests/helpers/act2_event_ui.lua')
local Pool=require('abyss_event_pool')
local Pending=require('abyss_relic_pending')
local initialOptions=dofile('tests/fixtures/two-act-selection-options.lua')
local M={H=H,states=0,clicks=0,options=0}
local base=H.Run.new(H.Data,42,{experimental=true,campaign=true,
 campaignProfile='competition-two-act',character='ironclad'})
assert(base.campaignProfile=='competition-two-act'and base.character=='ironclad')
assert(base.data.originalV4Role==nil)
assert(H.Run.obtainCard(base,'inflame'))
assert(H.Run.obtainCard(base,'regret'))
for _,id in ipairs({'Anchor','Lantern','Golden Idol','Blood Vial'})do assert(H.Run.obtainRelic(base,id))end
base.hp,base.gold=50,300
base.potions={'fire_potion'}
function M.run()return H.snapshot(base)end
local maps={}
function M.room(id,act)
 local r=M.run();r.act=act
 if not maps[act]then
  local map=H.Map.generate(r.data,42,act)
  -- Reach a legal floor for late Act1 encounters and Act2-only shared events.
  local target=act==1 and 8 or 24
  while map.floor<target-1 do assert(H.Map.choose(map,H.Map.available(map)[1].id))end
  maps[act]=map
 end
 local map=H.Copy(maps[act]);r.floor=map.floor
 local first=assert(H.Map.available(map)[1])
 for _,node in ipairs(map.nodes)do if node.id==first.id then node.type,node.eventId='event',id end end
 local ok,why=H.Nodes.enter(r,map,first.id);assert(ok,id..' entry: '..tostring(why))
 return r,map
end
local cached
function M.ui(r,map)
 if not cached then cached={H.setup(r,map)}
 else cached[1].run,cached[1].map=r,map;cached[1]:render();cached[1]:setVisible(true)end
 return table.unpack(cached)
end
function M.click(click,key,path)
 local ui=cached[1];local run=ui.run;local before=H.snapshot(run)
 local mode,picker,selected,page=ui.mode,ui.picker,ui.selected,ui.pendingPage
 -- A local picker opening/selection may change only UI state. An accepted
 -- gameplay command must change its actual Run even if rendering also clears
 -- selection or changes the picker mode afterwards.
 local choose=H.Nodes.chooseEvent
 H.Nodes.chooseEvent=function(owner,...)
  local prior=H.snapshot(owner);local accepted,reason=choose(owner,...)
  assert(not accepted or not pcall(H.same,owner,prior),'SELECTION_NO_PROGRESS '..path..' command')
  return accepted,reason
 end
 local called,ok,why=pcall(click,key);H.Nodes.chooseEvent=choose
 assert(called,ok);assert(ok,path..' '..key..': '..tostring(why))
 local unchanged=pcall(H.same,run,before)
 if key=='confirm'then assert(not unchanged,'SELECTION_NO_PROGRESS '..path..' confirm')end
 assert(key:match('^pickerView/card%d+$')or not unchanged or ui.mode~=mode or ui.picker~=picker or ui.selected~=selected or ui.pendingPage~=page,
  'SELECTION_NO_PROGRESS '..path..' '..key)
 M.clicks=M.clicks+1
end
function M.resolvePending(r,ui,click,path)
 local count=0
 while Pending.owner(r)do
  count=count+1;assert(count<=40,path..' pending did not finish')
  local view=Pending.view(r);assert(#view.rows>0,path..' empty pending choice')
  local chosen=1
  if view.rows[1].potion and H.Run.potionCount(r)>=H.Run.potionCapacity(r)then
   chosen=nil
   for i,row in ipairs(view.rows)do if row.token.kind=='done'or row.token.choice==0 then chosen=i;break end end
   assert(chosen,path..' full potion slots have no exit')
  end
  assert(ui:setPage(math.floor((chosen-1)/3)+1))
  M.click(click,'eventView/option'..((chosen-1)%3+1),path)
 end
 return count
end
local function match(r,ui,click,path)
 -- Inspect the private board only in this controlled test; UI stays concealed.
 while r.nodeFlow.event.stage=='play'do
  local event=r.nodeFlow.event;local first,pair={}
  for i,card in ipairs(event.board)do if not event.removed[i]then
   if first[card.cardId]then pair={first[card.cardId],i};break end
   first[card.cardId]=i
  end end
  assert(pair,path..' missing matching pair')
  for _,i in ipairs(pair)do M.click(click,'pickerView/forgeGrid/card'..i,path)end
  ui:update(1.1)
 end
 if r.nodeFlow.event.stage=='cleanup'then ui:update(1.1)end
 assert(r.nodeFlow.event.stage=='result',path..' board did not resolve')
end
function M.walk(r,map,seen,depth,path)
 assert(depth<=12,path..' event chain did not finish')
 if r.phase~='node'or r.nodeFlow.complete then return end
 local event=r.nodeFlow.event
 local state=event.id..':'..tostring(event.stage)..':'..tostring(event.choice)
 local enabled={}
 for _,row in ipairs(H.Nodes.view(r,map).node.event.options)do if row.enabled then enabled[#enabled+1]=row.choice end end
 table.sort(enabled)
 if path==event.id then
  assert(table.concat(enabled,',')==initialOptions[event.id],
   'SELECTION_OPTIONS_CHANGED '..event.id..': '..table.concat(enabled,','))
 end
 if seen[state]then return end;seen[state]=true;M.states=M.states+1
 local ui,_,shown,click=M.ui(r,map)
 if Pending.owner(r)then M.resolvePending(r,ui,click,path);ui:render()end
 if event.id=='match_game'and event.stage=='play'then
  match(r,ui,click,path);return M.walk(r,map,seen,depth+1,path..'/board')
 end
 if shown('pickerView')then
  local count=0
  for i=1,6 do
   if ui.actions.confirm and ui.actions.confirm.enabled then break end
   local key='pickerView/card'..i
   if ui.actions[key]and ui.actions[key].enabled and shown(key)then M.click(click,key,path);count=count+1 end
  end
  assert(ui.actions.confirm and ui.actions.confirm.enabled,path..' cannot confirm '..count..' selected cards')
  M.click(click,'confirm',path)
  return M.walk(r,map,seen,depth+1,path..'/pick')
 end
 local keys={}
 for i=1,4 do local key='eventView/option'..i
  if shown(key)and ui.actions[key]and ui.actions[key].enabled then keys[#keys+1]=key end
 end
 assert(#keys>0,path..' event has no enabled exit')
 for _,key in ipairs(keys)do
  local child,childMap=H.snapshot(r),H.Copy(map)
  local _,_,_,childClick=M.ui(child,childMap)
  M.click(childClick,key,path);M.options=M.options+1
  M.walk(child,childMap,seen,depth+1,path..'/'..key:sub(-1))
 end
end
function M.cases()
 local cases,seen={},{}
 for act=1,2 do
  local pool=Pool.new('full',false,act)
  local context={act=act,floor=act==1 and 8 or 24,hp=50,gold=300,cursed=true,relicCount=5,elapsedSeconds=0}
  for _,kind in ipairs({'act','shrine','once'})do for _,source in ipairs(pool[kind])do
   if Pool.isEligible(source,context)and not seen[source]then
    local id=assert(Pool.contentId[source],source..' has no gameplay mapping')
    cases[#cases+1]={source=source,id=id,act=act};seen[source]=true
   end
  end end
 end
 -- SecretPortal is Act3-only. NoteForYourself is not inserted: it requires
 -- persistent cross-run history, outside the current competition profile.
 assert(not seen.SecretPortal and not seen.NoteForYourself)
 assert(#cases==42,'current legal two-act source event set changed: '..#cases)
 return cases
end
function M.events(act)
 local count=0
 for _,case in ipairs(M.cases())do if case.act==act then
  local r,map=M.room(case.id,act)
  M.walk(r,map,{},0,case.id)
  count=count+1;print('PASS legal event '..case.source)
 end end
 print('TWO_ACT_SELECTION_EVENTS_PASS '..act..' '..count..' '..M.states..' '..M.clicks..' '..M.options)
end
return M
