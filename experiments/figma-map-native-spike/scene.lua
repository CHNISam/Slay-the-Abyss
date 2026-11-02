-- Standalone MAP slice, not a fake full game. The same attach() accepts GameUI.mapUI.
local Map,Run,Nodes=require('abyss_map'),require('abyss_run'),require('abyss_nodes')
local data=require('abyss_data');local ui,run,map;local pendingRoom,room,returnButton;local setup,session,loading
local function initializeUI()
 local mapRoot=script.object:GetChild('mapRoot');room=script.object:GetChild('roomPanel');returnButton=mapRoot:GetChild('stage'):GetChild('previewReturn')
 ui=require('abyss_map_ui').new(mapRoot,map,function(node)
  local ok,why=Nodes.enter(run,map,node.id)
  print('FIGMA_SLICE_CHOOSE '..node.id..' '..tostring(ok)..' '..tostring(why)..' phase='..tostring(run.phase))
  -- The full GameUI host changes room here. This standalone slice stays in
  -- read-only map preview after entering; no fake combat completion/unlock.
  if ok then pendingRoom=.8 end
  return ok,why
 end,Enum.CursorEventType.CursorClick,{color=Color,imageSource=Enum.ImageSource.StaticReference,cursor=Enum.CursorEventType,available=function(m)return Nodes.available(run,m)end})
 require('presentation').attach(ui,mapRoot,{color=Color,run=function()return run end,clickEvent=Enum.CursorEventType.CursorClick,available=function(m)return Nodes.available(run,m)end})
 local w,h=1280,720;if game and game.GetUICanvasSize then w,h=game.GetUICanvasSize()end;ui:resize(w,h);if FIGMA_SCENARIO=='real-wins'then ui:setNavigationEnabled(true)end;script:EnableUpdate(true)
 room:GetChild('roomRoute'):GetChild('hit'):AddCursorEventListener(Enum.CursorEventType.CursorClick,function()room:SetVisible(false);ui:setVisible(true);ui:setNavigationEnabled(false);returnButton:SetVisible(true)end)
 returnButton:GetChild('hit'):AddCursorEventListener(Enum.CursorEventType.CursorClick,function()ui:setVisible(false);room:SetVisible(true)end)
 ui:setVisible(true);session.ui=ui;session.ready=true;loading:SetVisible(false)
 print('FIGMA_SLICE_READY real_run=true real_map=true rules=17floors seed=42')
end
function OnStart()
 script.object.showCursor=true
 loading=script.object:GetChild('loadingPanel');loading:SetVisible(true)
 script.object:GetChild('mapRoot'):SetVisible(false);script.object:GetChild('roomPanel'):SetVisible(false)
 local w,h=1280,720;if game and game.GetUICanvasSize then w,h=game.GetUICanvasSize()end;loading:GetChild('loadingBackdrop'):SetSizeDelta(w,h)
 run=Run.new(data,'42',{character='ironclad',experimental=true,campaign=true,campaignProfile='competition-two-act'})
 local context,reason=Run.freezeMapContext(run);assert(context,reason)
 map=Map.generate(run.data,'42',run.act or 1,context)
 session={run=run,map=map,ready=false}
 script:EnableUpdate(true)
 if FIGMA_SCENARIO=='real-wins' then
  setup=require('scenario').new(run,map,3)
  print('FIGMA_FIXTURE_LOADING real_commands_incremental=true')
 else initializeUI()end
 return session
end
function OnUpdate(dt)
 if setup then
  local ok,reason=pcall(setup.step,setup)
  if not ok then setup=nil;session.blocked=tostring(reason);loading:GetChild('loadingTitle').text='测试局准备失败，请检查日志';print('FIGMA_SLICE_BLOCKED '..tostring(reason));return end
  if reason==true then setup=nil;initializeUI()end
  return
 end
 if ui then
 if game and game.GetUICanvasSize then local w,h=game.GetUICanvasSize();if w~=ui.canvasWidth or h~=ui.canvasHeight then ui:resize(w,h)end end
 ui:update(dt)end
 if pendingRoom then pendingRoom=pendingRoom-math.max(0,math.min(dt or 0,.1));if pendingRoom<=0 then pendingRoom=nil;ui:setVisible(false);room:SetVisible(true);room:GetChild('roomTitle').text='真实房间 · '..tostring(run.phase)end end
end
