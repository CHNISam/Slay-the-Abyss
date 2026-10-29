-- Native Match board adapter. Gameplay and permanent rewards remain in Nodes.
-- Root augments its existing picker grid with Match-only backs and one retry.
local Theme=require('abyss_theme')
local CardDisplay=require('abyss_card_display')
local M={}
local faceFields={'glow','shadow','border','plate','roundShadow','roundFrame','roundBody','nameBand','nameRule',
 'artPlate','artWell','skin','name','art_attack','art_skill','art_power','art_status','typeEdge','typeTag',
 'tagEdge','tagBody','type','description','roleRing','roleMark','blockedVeil','blockedPill','blockedLock',
 'blockedReason','costHalo','costCore','costDisc','cost','costDirection','veil','stampPlate','stamp','artSamples'}
local textFields={name=true,type=true,description=true,cost=true}
function M.isBoard(event)
 return event and event.id=='match_game'and(event.stage=='play'or event.stage=='resolving'or event.stage=='cleanup')
end
function M.inputPaths()
 return {'pickerView/matchRetry'} -- Twelve forge-grid inputs already exist.
end
local function shown(control)
 while control do if not control.visible then return false end;control=control.parent end
 return true
end
local function sameClock(a,b)
 return a and b and a.run==b.run and a.map==b.map and a.flow==b.flow and a.event==b.event and a.token==b.token
end
local function ownership(ctx,view,panel,box,grid)
 local self=ctx.self;local run,map,flow=self.run,self.map,self.run.nodeFlow
 local event,revision=flow.event,flow.event.revision
 local root,parent=ctx.root,ctx.root.parent
 local epoch,mode,picker=ctx.matchEpoch,self.mode,self.picker
 local hit=box and box:GetChild('hit')
 local retired=false
 return function()
  if retired then return false end
  local attached=root:GetChild('pickerView')==panel and panel.parent==root and root.parent==parent
  if grid then attached=attached and panel:GetChild('forgeGrid')==grid and grid.parent==panel end
  local owner=grid or panel
  if box then attached=attached and owner:GetChild(box.name)==box and box.parent==owner and box:GetChild('hit')==hit and hit.parent==box end
  local valid=attached and shown(box or panel)and self.visible and not self.busy and self.run==run and self.map==map
   and self.view==view and ctx.matchEpoch==epoch and self.mode==mode and self.picker==picker
   and run.nodeFlow==flow and flow.event==event and event.revision==revision and not flow.complete
  if not valid then retired=true end
  return valid
 end
end
function M.install(ctx)
 ctx.matchEpoch=0
 local masks,headers,active={},{},false
 local function restoreFace(box)
  for name,record in pairs(masks[box]or {})do
   if box:GetChild(name)==record.control then
    record.control:SetVisible(record.visible)
    if textFields[name]then record.control.text=record.text end
   end
  end
 end
 local function concealFace(box)
  local saved=masks[box]or {};masks[box]=saved
  for _,name in ipairs(faceFields)do
   local ok,control=pcall(box.GetChild,box,name)
   if ok and control then
    if not saved[name]then saved[name]={control=control,visible=control.visible,text=textFields[name]and control.text or nil}end
    control:SetVisible(false);if textFields[name]then control.text=''end
   end
  end
  CardDisplay.clearNativeArt(box);ctx.artFaces[box]=nil
 end
 function ctx.resetMatch()
  ctx.matchEpoch=ctx.matchEpoch+1
  ctx.matchClock,ctx.matchRetry=nil,nil
  local picker=ctx.child('pickerView');local grid=picker:GetChild('forgeGrid')
  for i=1,12 do local box=grid:GetChild('card'..i);ctx.show(box:GetChild('matchBack'),false);restoreFace(box)end
  masks={}
  ctx.show(picker:GetChild('matchRetry'),false)
  if active then
   for name,saved in pairs(headers)do
    local box=picker:GetChild(name);local values=Theme.layout.nativeNode.picker[name]
    box:SetAnchoredPosition(values[1],values[2]);box:SetSizeDelta(values[3],values[4])
    box.text=saved.text;box:SetVisible(saved.visible)
   end
  end
  headers,active={},false
 end
 local function submit(choice,token,clock)
  ctx.matchRetry=nil
  local accepted,why=ctx.commit('chooseEvent',choice,function()return '留影牌局 · 剩余 '..ctx.self.run.nodeFlow.event.attemptsLeft..' 次机会'end,token)
  if not accepted then
   -- A rejected transaction retains the pair. Never retry every frame or
   -- silently abandon an earned award: expose one explicit recovery action.
   ctx.matchRetry=clock;ctx.self:render()
  end
  return accepted,why
 end
 function ctx.renderMatch(view,node)
  local panel=ctx.child('pickerView');local event=node and node.event
  if not M.isBoard(event)then ctx.resetMatch();return nil end
  if not active then
   for _,name in ipairs({'page','label','hint'})do local box=panel:GetChild(name);headers[name]={text=box.text,visible=box.visible}end
   active=true
  end
  local grid=panel:GetChild('forgeGrid');ctx.show(panel,true);ctx.show(grid,true)
  for _,name in ipairs({'previous','next','before','after','target','arrow','empty','forgePrevious','forgeNext'})do ctx.show(panel:GetChild(name),false)end
  for i=1,6 do ctx.show(panel:GetChild('card'..i),false)end
  local info=assert(event.match,'missing detached Match view')
  local layout=Theme.layout.nativeNode;local top=layout.topBar.plate
  panel:GetChild('page'):SetAnchoredPosition(0,top[2]-top[4]/2-Theme.space.s-Theme.font.title/2)
  panel:GetChild('page').text='留影牌局'
  for _,name in ipairs({'label','hint'})do
   local box=panel:GetChild(name);local values=layout.forge[name]
   box:SetAnchoredPosition(name=='label'and layout.forge.columns[1]or layout.forge.columns[6],layout.forge.page[2])
   box:SetSizeDelta(values[3],layout.forge.page[4]);ctx.show(box,true)
  end
  ctx.show(panel:GetChild('page'),true)
  panel:GetChild('label').text='剩余机会：'..info.attemptsLeft
  panel:GetChild('hint').text=event.stage=='play'and'请选择两张石牌'or event.stage=='cleanup'and'正在收好卡牌'or'记住翻开的牌面'
  for i,slot in ipairs(info.slots)do
   local box=grid:GetChild('card'..i);ctx.show(box,not slot.removed);box:SetLocalScale(1,1,1)
   local back=box:GetChild('matchBack');ctx.show(back,not slot.faceUp and not slot.removed);ctx.inspectCards[box]=nil
   for _,name in ipairs({'plate','glyph','label'})do back:GetChild(name).raycastTarget=false end
   if slot.faceUp and not slot.removed then restoreFace(box);ctx.fillCard(box,slot.cardId,slot.upgraded,{instance=slot})
   else concealFace(box)end
   local owned=ownership(ctx,view,panel,box,grid)
   ctx.action('pickerView/forgeGrid/card'..i,slot.enabled,function()
    if not owned()then return false,'stale_action'end
    return ctx.commit('chooseEvent','flip',function()return '留影牌局 · 请选择两张石牌'end,slot.token)
   end,'当前不能翻动这张石牌',nil,owned)
  end
  local choice=info.resolveToken and'resolve'or info.completionToken and'finish'or nil
  local scope={run=ctx.self.run,map=ctx.self.map,flow=ctx.self.run.nodeFlow,event=ctx.self.run.nodeFlow.event,
   token=info.resolveToken or info.completionToken,choice=choice,seconds=info.waitSeconds,owned=ownership(ctx,view,panel)}
  local retry=choice and sameClock(ctx.matchRetry,scope)
  local previous=ctx.matchClock
  ctx.matchClock=choice and not retry and scope or nil
  if ctx.matchClock then ctx.matchClock.elapsed=sameClock(previous,scope)and previous.elapsed or 0 end
  local retryBox=panel:GetChild('matchRetry');ctx.show(retryBox,retry);ctx.state(retryBox,retry)
  local retryOwned=ownership(ctx,view,panel,retryBox)
  ctx.action('pickerView/matchRetry',retry,function()
   if not retryOwned()or not sameClock(ctx.matchRetry,scope)then return false,'stale_action'end
   return submit(choice,scope.token,scope)
  end,'上次结算未改变资源，请重试',nil,retryOwned)
  if retry then panel:GetChild('hint').text='结算未完成，请重试'end
  return '留影牌局 · 剩余 '..info.attemptsLeft..' 次机会'
 end
 function ctx.updateMatch(dt)
  local clock=ctx.matchClock
  if not clock then return end
  if not clock.owned()then ctx.matchClock=nil;return end
  if type(dt)~='number'or dt~=dt or dt<0 or dt==math.huge then return end
  clock.elapsed=clock.elapsed+dt
  if clock.elapsed<clock.seconds then return end
  ctx.matchClock=nil
  return submit(clock.choice,clock.token,clock)
 end
end
return M
