local Actors=require('abyss_battle_render_actors')
local names={'intentIcon','intent','intentHit','intentBadge','intentExtra','intentLabel'}
local function fixture()
 local handles={}
 local function make(name)
  local c={name=name,alive=true,writes=0}
  function c:SetVisible(value)
   assert(self.alive,'expired visibility handle');self.writes=self.writes+1
   local callback=self.callback;self.callback=nil
   if callback and self.applyAfter then callback()end
   self.visible=value
   if callback and not self.applyAfter then callback()end
   local fail=self.failure;self.failure=nil
   if fail=='throw'then error('visibility partial failure')end
   if fail=='false'then return false end
  end
  function c:SetSizeDelta()end
  function c:SetAnchoredPosition()end
  handles[name]=c;return c
 end
 for _,name in ipairs(names)do make(name)end
 local box={GetChild=function(_,name)return assert(handles[name])end}
 local function bind()
  return Actors.install({},{},{platform={imageSource='static'}},{picture=function()end,tint=function()end,ink=function()end}).renderEnemyIntent
 end
 local function draw(fn,allowed,kind)
  fn(box,{kind=kind or 'attack',value='6'},100,{intentX=1,intentY=2,intentWidth=3},allowed,1)
 end
 return handles,bind,draw,make
end
local h,bind,draw=fixture();local a=bind()
for _=1,300 do draw(a,true)end
for _,name in ipairs(names)do assert(h[name].writes==1,'unchanged visibility resubmitted')end
for _,allowed in ipairs({false,true})do draw(a,allowed);for _,name in ipairs({'intentIcon','intent','intentHit'})do assert(h[name].visible==allowed,'visibility transition lost')end end
draw(a,true,'defend');assert(not h.intent.visible and h.intentIcon.visible)
local b=bind();draw(b,true);local prior=h.intentIcon.writes;draw(a,true);assert(h.intentIcon.writes==prior+1,'visibility owner ignored')
for _,failure in ipairs({'false','throw'})do
 for _,applyAfter in ipairs({false,true})do
  for _,name in ipairs(names)do
   local hs,binder,paint=fixture();local first,second=binder(),binder();paint(first,true)
   local c=hs[name];c.applyAfter=applyAfter
   c.callback=function()paint(first,true);c.failure=failure end
   assert(pcall(paint,second,false)==(failure=='false'),'visibility error propagation changed')
   local count=c.writes;paint(first,true);assert(c.writes==count+1,'failed outer visibility retained nested promise')
   paint(first,true);assert(c.writes==count+1,'successful visibility retry not retained')
  end
 end
end
for _,applyAfter in ipairs({false,true})do
 local hs,binder,paint=fixture();local first,second=binder(),binder();paint(first,true)
 hs.intentIcon.applyAfter=applyAfter;hs.intentIcon.callback=function()paint(first,true)end
 paint(second,false);local n=hs.intentIcon.writes;paint(second,false)
 assert(hs.intentIcon.writes==n+1,'overlapping visibility cached')
end
local hs,binder,paint,make=fixture();local fn=binder();paint(fn,true)
hs.intentIcon.alive=false;assert(not pcall(paint,fn,true),'dead visibility guard bypassed')
local fresh=make('intentIcon');paint(fn,true);assert(fresh.writes==1 and fresh.visible,'fresh handle not initialized')
print('INTENT_VISIBILITY_CACHE_PASS first/300/switch/owner/reentry/failure/dead/fresh')
-- Exercise the actual escape writer captured by renderEnemies, without exporting
-- a production-only test hook or substituting its implementation.
local function escapeFixture()
 local handles={}
 local box={GetChild=function(_,name)
  if not handles[name] then
   local c={alive=true,writes=0}
   function c:SetSizeDelta()end
   function c:SetAnchoredPosition()end
   function c:SetVisible(value)
    self.writes=self.writes+1
    local callback=self.callback;self.callback=nil
    if callback and self.applyAfter then callback()end
    self.visible=value
    if callback and not self.applyAfter then callback()end
    local failure=self.failure;self.failure=nil
    if failure=='throw' then error('escape visibility partial failure')end
    if failure=='false' then return false end
   end
   handles[name]=c
  end
  return handles[name]
 end}
 local owner={feedback={escaping={enemy=true}}}
 local api=Actors.install(owner,{},{platform={imageSource='static'}},{picture=function()end,tint=function()end,ink=function()end})
 local hide
 for i=1,100 do
  local name,value=debug.getupvalue(api.renderEnemies,i)
  if not name then break end
  if name=='hideEscapingHud' then hide=value;break end
 end
 assert(hide,'actual escape visibility writer missing')
 local function draw()
  api.renderEnemyIntent(box,{kind='attack',value='6'},100,{intentX=1,intentY=2,intentWidth=3},true,1)
 end
 return handles,draw,function()hide(box,'enemy')end
end
for _,failure in ipairs({'success','false','throw'})do
 for _,applyAfter in ipairs({false,true})do
  for _,name in ipairs({'intentIcon','intentBadge','intentExtra','intent','intentHit'})do
   local handles,draw,hide=escapeFixture();draw()
   local control=handles[name];control.applyAfter=applyAfter
   control.callback=function()draw();control.failure=failure end
   local ok,why=pcall(hide)
   assert(ok==(failure~='throw'),'escape visibility error propagation changed')
   if not ok then assert(tostring(why):find('escape visibility partial failure',1,true),'escape visibility error lost')end
   local count=control.writes;draw()
   assert(control.writes==count+1,'escape writer retained nested visibility promise')
   assert(control.visible==(name=='intentIcon' or name=='intent' or name=='intentHit'),'escape visibility not restored')
   draw();assert(control.writes==count+1,'escape visibility retry not retained')
  end
 end
end
print('INTENT_ESCAPE_VISIBILITY_PASS success/false/throw before/after five-controls')
for _,failure in ipairs({'false','throw'})do
 for _,name in ipairs(names)do
  local handles,binder,paint=fixture();local first,second=binder(),binder();paint(first,true)
  local control=handles[name];control.failure=failure
  assert(pcall(paint,second,false)==(failure=='false'),'plain visibility failure propagation changed')
  local n=control.writes;paint(second,false)
  assert(control.writes==n+1,'rejected visibility write cached')
  paint(second,false);assert(control.writes==n+1,'plain successful retry not retained')
 end
end
print('INTENT_VISIBILITY_FAILURE_PASS six-controls false/throw')
