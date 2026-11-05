local root,controller
local elapsed,index=0,1
-- Only semantic functions used by the actual native handlers, no injected input.
local events={{.2,'play','enter'},{.5,'play','down'},{.6,'play','cancel'},{.7,'play','enter'},{1.0,'play','down'},{1.1,'play','up'},{1.2,'play','activate'},{1.4,'back','enter'},{1.6,'back','down'},{1.7,'back','up'},{1.8,'back','cancel'},{2,'back','activate'},{2.2,'quit','enter'},{2.5,'quit','activate'},{2.7,'cancelExit','activate'},{2.9,'play','enter'},{3.1,'play','activate'},{3.2,'back','enter'},{3.3,'back','down'},{3.4,'back','activate'},{3.6,'play','activate'},{3.8,'back','activate'},{4,'quit','activate'},{4.2,'confirmExit','activate'},{4.6,'cancelExit','activate'},{4.8,'play','activate'},{5.0,'selected','enter'},{5.2,'selected','leave'},{5.4,'embark','enter'},{5.6,'embark','down'},{5.7,'embark','up'},{5.8,'embark','cancel'},{6.0,'back','activate'}}
local function bind(c)
 function c:rebind()
  local token=self.generation
  for id,b in pairs(self.buttons)do
   local node=root:GetChild(b.panel):GetChild(id);local hit=node:GetChild(id..'Hit')
   hit:RemoveAllCursorEventListeners();hit:RemoveAllNavigationEventListeners()
   hit.raycastTarget=not b.disabled and self.page==b.page
   local function emit(phase)return function()return self:signal(token,id,phase)end end
   local e=Enum.CursorEventType
   hit:AddCursorEventListener(e.CursorEnter,emit('enter'));hit:AddCursorEventListener(e.CursorExit,emit('leave'))
   hit:AddCursorEventListener(e.CursorDown,emit('down'));hit:AddCursorEventListener(e.CursorUp,emit('up'));hit:AddCursorEventListener(e.CursorClick,emit('activate'))
   local n=Enum.ControllerNavigationEventType
   hit:AddNavigationEventListener(n.Focus,emit('focus'));hit:AddNavigationEventListener(n.LostFocus,emit('blur'));hit:AddNavigationEventListener(n.Confirm,emit('activate'));hit:AddNavigationEventListener(n.Cancel,function()if self.page=='exit'then return self:signal(token,'cancelExit','activate')else return self:signal(token,id,'cancel')end end)
  end
 end
 c:rebind()
end
function OnStart()
 script:EnableUpdate(true)
 root=script.object;local w,h=game.GetUICanvasSize();local scale=math.min(w/1280,h/720);root:SetLocalScale(scale,scale,1)
 -- HOST_TESTS_HERE
 controller=NewMenuController(root,INITIAL_PAGE);bind(controller)
 assert(root:GetChild('mainMenu'):GetChild('collection'):GetChild('collectionHit').raycastTarget==false)
 assert(root:GetChild('mainMenu'):GetChild('history'):GetChild('historyHit').raycastTarget==false)
 print('MENU_REFINED_READY updates=true semantic_callbacks_shared=true pointer_verified=false')
end
function OnUpdate(dt)
 controller:tick(dt)
 if not AUTOMATIC_DEMO then return end
 elapsed=elapsed+dt
 while events[index] and elapsed+.00001>=events[index][1]do
  local e=events[index];assert(controller:signal(controller.generation,e[2],e[3]),'timeline semantic signal rejected')
  print('MENU_KEYFRAME '..string.format('%.2f',elapsed)..' '..e[2]..' '..e[3]..' page='..controller.page..' x='..controller.buttons.play.x..' glow='..controller.buttons.play.alpha)
  index=index+1
 end
 local play=controller.buttons.play;local face=root:GetChild('mainMenu'):GetChild('play'):GetChild('face');local x,y=face:GetAnchoredPosition();assert(math.abs(x-play.x)<.000001 and y==0,'real Host face position mismatch');assert(face:GetChild('glow').imageColor==math.floor(play.alpha*255+.5)*16777216+16777215,'real Host glow alpha mismatch')
 for id,b in pairs(controller.buttons)do
  local n=root:GetChild(b.panel):GetChild(id)
  if b.kind=='banner'then assert(n:GetChild('normal').visible==(b.brightness==1));assert(n:GetChild('hover').visible==(b.brightness==1.18));assert(n:GetChild('pressed').visible==(b.brightness==.92))end
  if b.disabled then assert(not n:GetChild(id..'Hit').raycastTarget and b.x==0 and b.alpha==0)end
 end
 if elapsed+.00001>=6.2 and not controller.demoDone then
  controller.demoDone=true;assert(controller.page=='menu');assert(not controller.exitAttempted);assert(play.x==0 and play.alpha==0 and not play.down)
  print('MENU_NATIVE_SEMANTIC_PASS timeline=33 real_host_geometry=true old_states_reset=true input_verified=false')
 end
end
function OnDestroy()if controller then controller.generation=controller.generation+1;controller:reset()end end
