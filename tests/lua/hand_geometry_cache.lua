local F=dofile('tests/lua/support/game_ui_fixture.lua')
local CardView=require('abyss_battle_card_view')
local Run=require('abyss_run')
local host,root=F.fixture();assert(F.start(host));assert(Run.startCombat(host.run,'cultist_solo'));host:refresh()
local panel=root:GetChild('battlePanel')
local box=panel:GetChild('card1')
local function bind()
 local view={run=host.run,active=true,canvasWidth=1280,canvasHeight=720,cardPositions={}}
 local function noop()end
 local cardView=CardView.new(view,{
  child=function(name)return panel:GetChild(name)end,show=noop,ink=noop,tint=noop,picture=noop,platform={},
  placeCard=function(control,count,index)
   control:SetAnchoredPosition(index*100,-200);control:SetLocalScale(1,1,1);control.localRotationZ=0
   return {index*100,-200,baseY=-200}
  end,
 })
 local function render()return cardView.renderCards(F.Data,F.Presentation,host.run.combat,true,true,false,false)end
 return cardView,view,render
end
local a,view,render=bind()
render();a.update(10)
local hit=box:GetChild('hit')
local positions,original=0,box.SetAnchoredPosition
box.SetAnchoredPosition=function(self,...)positions=positions+1;return original(self,...)end
positions=0;a.update(1/60);assert(positions==0,'stable pose missed cache')
-- Rendering first invokes the external hand-layout writer, which must revoke
-- the promise even when the interpolated pose itself has not changed.
render();assert(box.localRotationZ~=0,'layout overwrote cached hand angle')
positions=0;a.update(1/60);assert(positions==0)
local b,_,renderB=bind();renderB();b.update(10)
positions=0;a.update(1/60);assert(positions==1,'shared native owner was ignored')
positions=0;a.update(1/60);assert(positions==0)
-- A same-name native replacement cannot inherit the previous hit promise.
local fresh=F.control({name='hit',kind='cursorArea'},box);box.children.hit=fresh
a.update(1/60);assert(fresh.sizeDeltaX and fresh.scale and fresh.localRotationZ~=nil,'new hit was not initialized')
box.children.hit=hit;a.update(1/60)
for _,writer in ipairs({{box,'SetAnchoredPosition'},{box,'SetLocalScale'},
 {hit,'SetAnchoredPosition'},{hit,'SetSizeDelta'},{hit,'SetLocalScale'}})do
 local control,method=writer[1],writer[2]
 for _,failure in ipairs({'false','throw'})do
  renderB();b.update(10)
  local saved=control[method];local fail,calls=true,0
  control[method]=function(self,...)
   calls=calls+1;local result=saved(self,...)
   if fail then if failure=='throw'then error('partial hand failure')end;return false end
   return result
  end
  -- A different native owner forces the original owner's actual pose writer.
  local ok=pcall(a.update,1/60)
  if failure=='throw' then assert(not ok)end
  fail=false
  local before=calls;a.update(10)
  assert(calls>before,'failed hand geometry promise survived')
  before=calls;a.update(1/60);assert(calls==before,'successful retry was not retained')
  control[method]=saved
 end
end
for _,control in ipairs({box,hit})do
 renderB();b.update(10)
 local originalMeta=getmetatable(control);local throwing={}
 for key,value in pairs(originalMeta)do throwing[key]=value end
 local called=false
 throwing.__newindex=function(self,key,value)
  if key=='localRotationZ'then called=true;rawset(self,key,value);error('partial hand rotation failure')end
  return originalMeta.__newindex(self,key,value)
 end
 rawset(control,'localRotationZ',nil);setmetatable(control,throwing)
 local ok,why=pcall(a.update,1/60)
 assert(called and not ok and tostring(why):find('partial hand rotation failure',1,true),'rotation failure was swallowed')
 setmetatable(control,originalMeta)
 local before=positions;a.update(1/60)
 assert(positions>before,'failed hand geometry promise survived')
end
local meta=getmetatable(hit)
local expired={};for k,v in pairs(meta)do expired[k]=v end
expired.__index=function(control,key)if key=='alive'then return false end;return meta.__index(control,key)end
local saved=hit.SetSizeDelta
hit.SetSizeDelta=function()error('expired hand hit')end
setmetatable(hit,expired)
local ok,why=pcall(a.update,1/60)
assert(not ok and tostring(why):find('expired hand hit',1,true),'dead native guard was bypassed')
setmetatable(hit,meta);hit.SetSizeDelta=saved;a.update(1/60)
-- Nested same-pose updates have unknown native completion order. Neither the
-- nested promise nor the old outer promise may survive, even after a throw.
for _,failure in ipairs({'success','false','throw'})do
 local saved=hit.SetAnchoredPosition;local armed=false;local calls=0
 hit.SetAnchoredPosition=function(self,...)
  calls=calls+1
  if armed then
   armed=false;a.update(1/60)
   if failure=='throw'then error('outer hand failure')end
   if failure=='false'then return false end
  end
  return saved(self,...)
 end
 render()
 -- Revoke via a different binding, then challenge the original owner.
 local c,_,renderC=bind();renderC();c.update(10);armed=true
 local ok,why=pcall(a.update,1/60)
 if failure=='throw'then assert(not ok and tostring(why):find('outer hand failure',1,true))else assert(ok,why)end
 local before=calls;a.update(1/60)
 assert(calls>before,'overlapping hand write was incorrectly cached')
 before=calls;a.update(1/60);assert(calls==before,'reentry retry did not settle')
 hit.SetAnchoredPosition=saved
end
print('HAND_GEOMETRY_CACHE_PASS ownership/render/new-hit/false/throw/reentry')
