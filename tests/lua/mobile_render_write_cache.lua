local MapUI=require('abyss_map_ui')
local Actors=require('abyss_battle_render_actors')
local Theme=require('abyss_theme')
local function control()
 local state={textWrites=0,imageWrites=0,sizeWrites=0}
 local c={SetVisible=function()end,SetAnchoredPosition=function()end}
 function c:SetSizeDelta(w,h)
  state.sizeWrites=state.sizeWrites+1
  if state.failSize then state.failSize=false;return false end
  state.width,state.height=w,h
 end
 function c:SetImage(source,id)
  state.imageWrites=state.imageWrites+1
  if state.failImage then state.failImage=false;return false end
  state.source,state.image=source,id
 end
 return setmetatable(c,{__index=function(_,k)
  if k=='text' then error('native text readback must not be needed')end
 end,__newindex=function(self,k,v)
  if k=='text'then
   state.textWrites=state.textWrites+1
   if state.failText then state.failText=false;error('one rejected text write')end
   state.text=v
  else rawset(self,k,v)end
 end}),state
end
local function box()
 local children,states={},{}
 for _,name in ipairs({'icon','ring','intentIcon','intent','intentHit','intentBadge','intentExtra','intentLabel'})do children[name],states[name]=control()end
 return {GetChild=function(_,name)return assert(children[name])end},children,states
end
local tests={}
local function test(name,fn)tests[#tests+1]={name,fn}end
local function fx(b)return {box=b,size=44,scale=.5,state='locked'}end
local function render(b,platform)
 platform=platform or {imageSource='static'}
 local deps={picture=function(c,id)return c:SetImage(platform.imageSource,type(id)=='table' and id.id or id)end,tint=function()end,ink=function()end}
 return Actors.install({}, {}, {platform=platform},deps).renderEnemyIntent
end
local face={kind='attack',value='6'}
test('stable map rooms submit each size once; scale changes repaint',function()
 local b,children,s=box();local f=fx(b)
 for _=1,300 do MapUI.paintRoom(f)end
 assert(s.icon.sizeWrites==1 and s.ring.sizeWrites==1,'stable map room rewrote native sizes')
 f.scale=.75;MapUI.paintRoom(f);assert(s.icon.sizeWrites==2 and s.ring.sizeWrites==2)
 local replacement,rs=control();children.icon=replacement;MapUI.paintRoom(f)
 assert(rs.sizeWrites==1,'replacement map native control was skipped')
 local fresh=fx(b);fresh.scale=f.scale;MapUI.paintRoom(fresh)
 assert(rs.sizeWrites==2,'new map view ownership reused stale cache')
end)
test('map rejected setter retries same dimensions',function()
 local b,_,s=box();local f=fx(b);s.icon.failSize=true
 MapUI.paintRoom(f);MapUI.paintRoom(f)
 assert(s.icon.sizeWrites==2 and s.icon.width,'map failed size was cached')
 MapUI.paintRoom(f);assert(s.icon.sizeWrites==2)
end)
test('idle intent avoids repeated text and image writes without readback',function()
 local b,_,s=box();local draw=render(b)
 for _=1,300 do draw(b,face,100,nil,true,1)end
 assert(s.intent.textWrites==1 and s.intentIcon.imageWrites==1,'idle intent repeated native writes')
 draw(b,{kind='defend',value='12'},100,nil,true,.5)
 assert(s.intent.text=='12' and s.intent.textWrites==2 and s.intentIcon.imageWrites==2,'changed intent did not paint')
end)
test('new native objects and controller binding repaint; image source change repaints',function()
 local b,children,s=box();local platform={imageSource='static'};local draw=render(b,platform)
 draw(b,face,100,nil,true,1)
 local replacement,rs=control();children.intentIcon=replacement;draw(b,face,100,nil,true,1)
 assert(rs.imageWrites==1)
 platform.imageSource='other';draw(b,face,100,nil,true,1);assert(rs.imageWrites==2 and rs.source=='other')
 draw=render(b,platform);draw(b,face,100,nil,true,1)
 assert(rs.imageWrites==3 and s.intent.textWrites==2,'controller rebind did not repaint')
end)
test('rejected image and throwing text writes retry',function()
 local b,_,s=box();local draw=render(b);s.intentIcon.failImage=true
 draw(b,face,100,nil,true,1);draw(b,face,100,nil,true,1)
 assert(s.intentIcon.imageWrites==2 and s.intentIcon.image,'failed image write was cached')
 s.intent.failText=true
 assert(not pcall(draw,b,{kind='attack',value='7'},100,nil,true,1))
 draw(b,{kind='attack',value='7'},100,nil,true,1)
 assert(s.intent.text=='7' and s.intent.textWrites==3,'failed text write was cached')
end)
test('cached native handles still pass through dead-object guards',function()
 local b,children=box();local f=fx(b);MapUI.paintRoom(f)
 children.icon.alive=false
 children.icon.SetSizeDelta=function()error('native map object expired')end
 assert(not pcall(MapUI.paintRoom,f),'map cache bypassed expired native handle')
 local b2,c=box();local draw=render(b2);draw(b2,face,100,nil,true,1)
 c.intentIcon.alive=false
 c.intentIcon.SetImage=function()error('native intent object expired')end
 assert(not pcall(draw,b2,face,100,nil,true,1),'intent cache bypassed expired native handle')
end)
local failures=0
for _,t in ipairs(tests)do local ok,why=pcall(t[2]);if ok then print('ok '..t[1])else failures=failures+1;print('FAIL '..t[1]..': '..tostring(why))end end
assert(failures==0,tostring(failures)..' focused render cache regressions failed')
-- The real battle adapter must propagate a rejected native SetImage result.
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local ui,root=F.fixture();assert(F.start(ui,'ironclad'))
assert(require('abyss_run').startCombat(ui.run,'cultist_solo'));ui:refresh()
local actor=F.actorControl(root:GetChild('battlePanel'),'enemy1')
local icon=actor:GetChild('intentIcon');local attempts=0;local original=icon.SetImage
icon.SetImage=function(self,...)
 attempts=attempts+1
 if attempts==1 then return false end
 return original(self,...)
end
local old=Theme.icon.intent.buff;Theme.icon.intent.buff=123456789
ui:update(1/60);ui:update(1/60);ui:update(1/60)
Theme.icon.intent.buff=old
assert(attempts==2,'production image adapter cached a rejected native setter')
print('ok production image adapter retries rejected native setter')
