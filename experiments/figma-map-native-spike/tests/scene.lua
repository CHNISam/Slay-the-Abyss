local function control(spec)
 local c={name=spec.name,children={},listeners={},visible=spec.visible~=false}
 function c:GetChild(name)return self.children[name]end
 function c:GetChildren()local list={};for _,v in pairs(self.children)do list[#list+1]=v end;return list end
 function c:SetVisible(v)self.visible=v end
 function c:SetAnchoredPosition(x,y)self.x,self.y=x,y end
 function c:SetSizeDelta(w,h)assert(w>=0 and h>=0);self.w,self.h=w,h end
 function c:SetLocalScale(x,y,z)self.localScaleX,self.localScaleY=x,y end
 function c:SetImage(_,id)self.image=id end
 function c:AddCursorEventListener(e,f)assert(not self.listeners[e]);self.listeners[e]=f end
 for _,s in ipairs(spec.children or{})do c.children[s.name]=control(s)end
 return c
end
Color=function(r,g,b,a)return{r=r,g=g,b=b,a=a}end
Enum={ImageSource={StaticReference='static'},CursorEventType={CursorClick='click',CursorDown='down',CursorUp='up',CursorDrag='drag',CursorExit='exit',CursorEndDrag='end'}}
local root=control({children=dofile('controls.lua').controls})
script={object=root,EnableUpdate=function()end}
local width,height=1600,900;game={GetUICanvasSize=function()return width,height end}
coroutine=nil -- actual Simulator LuaHost has no coroutine global
dofile('scene.generated.lua');local session=OnStart();local function noListeners(n)assert(next(n.listeners)==nil,'preparation must not bind navigation');for _,c in pairs(n.children)do noListeners(c)end end;noListeners(root:GetChild('mapRoot'));assert(root:GetChild('mapRoot').visible==false,'map root must stay hidden during fixture preparation');assert(session.map.floor==0,'real-wins fixture must yield before blocking startup');for i=1,1000 do if session.ready then break end;OnUpdate(.1)end;assert(session.ready,'fixture must reach actual ready');assert(root:GetChild('mapRoot').visible==true,'ready must reveal actual native root');OnUpdate(.016)
local function snapshot(value,seen)
 if type(value)~='table'then return tostring(value)end
 seen=seen or{};if seen[value]then return '<ref>'end;seen[value]=true;local keys={};for k in pairs(value)do keys[#keys+1]=k end;table.sort(keys,function(a,b)return tostring(a)<tostring(b)end);local out={};for _,k in ipairs(keys)do out[#out+1]=tostring(k)..'='..snapshot(value[k],seen)end;return '{'..table.concat(out,';')..'}'
end
local before=snapshot(session.run)..snapshot(session.map)
for f=0,17 do session.ui:setScroll(f*100);OnUpdate(.016)end
assert(before==snapshot(session.run)..snapshot(session.map),'scroll must not mutate same-run state or RNG')
session.ui:focusCurrent()
assert(session.ui.canvasWidth==1600 and session.ui.scale==1.25,'use actual canvas on startup')
width,height=2340,1080;OnUpdate(.016);assert(session.ui.canvasWidth==2340 and session.ui.scale==1.5,'mobile aspect uses real canvas')
assert(root:GetChild('mapRoot'):GetChild('mapBackdrop').w==2340,'backdrop fills actual width')
local panel=root:GetChild('mapRoot'):GetChild('stage'):GetChild('mapPanel')
local chosen
for _,g in pairs(panel.children)do for name,n in pairs(g.children)do if name:match('^node%d+$')and n.visible and n:GetChild('hit').visible then chosen=n:GetChild('hit');print('AVAILABLE_NATIVE_TARGET '..name..'/hit');break end end;if chosen then break end end
assert(chosen,'real available node target')
assert(chosen.listeners.click(),'actual Nodes.enter must succeed')
OnUpdate(.016)
assert(not chosen.listeners.click(),'second click must not enter again')
assert(session and session.run,'standalone entry exposes real session handle')
local owner,combat=session.run,session.run.combat
for i=1,9 do OnUpdate(.1)end
assert(not session.ui.visible,'entered room must leave interactive map')
root:GetChild('roomPanel'):GetChild('roomRoute'):GetChild('hit').listeners.click()
assert(session.ui.visible and not session.ui.navigationEnabled,'preview remains read-only')
root:GetChild('mapRoot'):GetChild('stage'):GetChild('previewReturn'):GetChild('hit').listeners.click()
assert(not session.ui.visible and session.run==owner and owner.combat==combat,'return must preserve actual room owner')
local settled=snapshot(session.run)..snapshot(session.map);for i=1,10 do OnUpdate(.1)end;assert(settled==snapshot(session.run)..snapshot(session.map),'completed fixture must not rerun commands')
print('SCENE_PASS actual Run Map Nodes start and single entry; no synthetic completion')
