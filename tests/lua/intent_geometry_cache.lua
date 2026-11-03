local Actors=require('abyss_battle_render_actors')
local Theme=require('abyss_theme')
local tests={}
local function test(name,fn)tests[#tests+1]={name,fn}end
local names={'intentIcon','intent','intentHit'}
local face={kind='attack',value='6'}
local function geometry(x,y,size)return {intentX=x or 12,intentY=y or 90,intentWidth=size or 16}end
local function fixture()
 local handles,trace={},{}
 local function make(name)
  local c={alive=true,name=name,sizeWrites=0,positionWrites=0,sameSize=0,samePosition=0}
  function c:SetVisible(v)self.visible=v end
  local function write(self,kind,a,b)
   self[kind..'Writes']=self[kind..'Writes']+1;trace[#trace+1]=name..':'..kind
   assert(self.alive,'expired intent geometry handle: '..kind)
   local keys=kind=='size' and {'w','h'} or {'x','y'}
   local same=kind=='size' and 'sameSize' or 'samePosition'
   if self[keys[1]]==a and self[keys[2]]==b then self[same]=self[same]+1 end
   local callback=self[kind..'Callback'];self[kind..'Callback']=nil
   if callback and self.applyAfterCallback then callback()end
   self[keys[1]],self[keys[2]]=a,b
   if callback and not self.applyAfterCallback then callback()end
   local failure=self[kind..'Failure'];self[kind..'Failure']=nil
   if failure=='throw'then error('partially applied intent '..kind)end
   if failure=='false'then return false end
  end
  function c:SetSizeDelta(w,h)return write(self,'size',w,h)end
  function c:SetAnchoredPosition(x,y)return write(self,'position',x,y)end
  handles[name]=c;return c
 end
 for _,name in ipairs({'intentIcon','intent','intentHit','intentBadge','intentExtra','intentLabel'})do make(name)end
 local box={GetChild=function(_,name)return assert(handles[name])end}
 local function bind(owner)
  return Actors.install(owner or {},{},{platform={imageSource='static'}},{
   picture=function(c,id)c.image=id end,tint=function(c,t)c.tint=t end,ink=function(c,t)c.ink=t end,
  }).renderEnemyIntent
 end
 return box,handles,bind,make,trace
end
local function assertGeometry(h,g,value)
 local L,S=Theme.layout,Theme.space
 local width=math.max(L.intent.valueWidth,utf8.len(value or '6')*L.intent.numberSize)
 assert(h.intentIcon.w==math.min(g.intentWidth,L.intent.size) and h.intentIcon.h==h.intentIcon.w)
 assert(h.intentIcon.x==g.intentX and h.intentIcon.y==g.intentY)
 assert(h.intent.w==width and h.intent.h==L.nativeText.lineHeight)
 assert(h.intent.x==g.intentX+L.intent.size/2+S.xs+width/2 and h.intent.y==g.intentY)
 assert(h.intentHit.x==g.intentX and h.intentHit.y==g.intentY)
 assert(h.intentHit.w==64*Theme.canvas.base[1]/1920 and h.intentHit.h==64*Theme.canvas.base[2]/1080)
end
for count=1,5 do
 test(count..' enemies retain geometry for 300 unchanged frames',function()
  local fixtures={};local size,position,sameSize,samePosition=0,0,0,0
  for i=1,count do local b,h,bind=fixture();fixtures[i]={b=b,h=h,draw=bind(),g=geometry(i*3,80+i)}end
  for _=1,300 do for _,f in ipairs(fixtures)do f.draw(f.b,face,100,f.g,true,1)end end
  for _,f in ipairs(fixtures)do
   assertGeometry(f.h,f.g)
   for _,name in ipairs(names)do local c=f.h[name]
    size=size+c.sizeWrites;position=position+c.positionWrites
    sameSize=sameSize+c.sameSize;samePosition=samePosition+c.samePosition
   end
  end
  print('INTENT_GEOMETRY frames=300 enemies='..count..' size='..size..' position='..position..' sameSize='..sameSize..' samePosition='..samePosition)
  assert(size==count*3 and position==count*3,'unchanged intent geometry resubmitted')
 end)
end
test('geometry dimensions, portrait fallback and digit width update independently',function()
 local b,h,bind=fixture();local draw=bind();local g=geometry();draw(b,face,100,g,true,1)
 for _,key in ipairs({'intentX','intentY','intentWidth'})do g[key]=g[key]+1;draw(b,face,100,g,true,.4);assertGeometry(h,g)end
 for _,text in ipairs({'123456789×12','','6'})do
  draw(b,{kind='attack',value=text},100,g,true,.4)
  assertGeometry(h,g,text:gsub('×','x'));assert(h.intent.text==text:gsub('×','x'))
 end
 local old=Theme.layout.nativeText.lineHeight
 Theme.layout.nativeText.lineHeight=old+1;draw(b,face,100,g,true,1);assert(h.intent.h==old+1)
 Theme.layout.nativeText.lineHeight=old;draw(b,face,100,g,true,1);assertGeometry(h,g)
 draw(b,face,120,nil,true,1);assert(h.intentIcon.x==0 and h.intentIcon.y==60)
 draw(b,face,160,nil,true,1);assert(h.intentIcon.y==80 and h.intentHit.y==80)
end)
test('hidden return preserves visibility, tone and nongeometry writes',function()
 local b,h,bind=fixture();local draw=bind();local g=geometry()
 for _,allowed in ipairs({true,false,true})do
  draw(b,face,100,g,allowed,.25);assertGeometry(h,g)
  assert(h.intentIcon.visible==allowed and h.intent.visible==allowed and h.intentHit.visible==allowed)
  for _,name in ipairs({'intentBadge','intentExtra','intentLabel'})do assert(not h[name].visible)end
  assert(h.intent.ink.a==255*.25)
 end
 draw(b,{kind='defend',value='6'},100,g,true,.75)
 assert(not h.intent.visible and h.intentIcon.visible and h.intentIcon.tint.a==255*.75)
 for _,name in ipairs(names)do assert(h[name].sizeWrites==1 and h[name].positionWrites==1)end
end)
test('A B A owners, rebinding and fresh same-name handles repaint',function()
 local b,h,bind,make=fixture();local owner={};local a,c=bind(owner),bind({});local g=geometry()
 a(b,face,100,g,true,1);c(b,face,100,g,true,1);a(b,face,100,g,true,1)
 for _,name in ipairs(names)do assert(h[name].sizeWrites==3 and h[name].positionWrites==3,'shared handle ownership was ignored')end
 bind(owner)(b,face,100,g,true,1)
 for _,name in ipairs(names)do assert(h[name].sizeWrites==4 and h[name].positionWrites==4,'binding reused a prior promise')end
 for _,name in ipairs(names)do local fresh=make(name);a(b,face,100,g,true,1);assert(fresh.sizeWrites==1 and fresh.positionWrites==1)end
end)
for _,failure in ipairs({'false','throw'})do
 for _,kind in ipairs({'size','position'})do
  test('partial '..kind..' '..failure..' retries changed and previous geometry',function()
   for _,name in ipairs(names)do for _,retryOld in ipairs({false,true})do
    local b,h,bind=fixture();local a,c=bind(),bind();local g=geometry();a(b,face,100,g,true,1)
    local target=h[name];target[kind..'Failure']=failure
    local changed=geometry(33,121,21)
    assert(pcall(c,b,{kind='attack',value='123456789'},100,changed,true,1)==(failure=='false'),'throw/false propagation changed')
    local before=target[kind..'Writes']
    local draw,nextGeometry,nextFace=a,g,face
    if not retryOld then draw,nextGeometry,nextFace=c,changed,{kind='attack',value='123456789'}end
    draw(b,nextFace,100,nextGeometry,true,1)
    assert(target[kind..'Writes']==before+1,'failed geometry promise survived')
    assertGeometry(h,nextGeometry,nextFace.value)
    draw(b,nextFace,100,nextGeometry,true,1);assert(target[kind..'Writes']==before+1,'retry success was not cached')
   end end
  end)
 end
end
for _,kind in ipairs({'size','position'})do
 test('expired handles still reach native '..kind..' guard',function()
  for _,name in ipairs(names)do
   local b,h,bind=fixture();local draw=bind();draw(b,face,100,geometry(),true,1)
   local c=h[name];c.alive=false
   -- Let the earlier size setter pass to independently reach the position guard.
   if kind=='position'then c.SetSizeDelta=function()end end
   if kind=='size' and name=='intentHit'then c.SetAnchoredPosition=function()end end
   local ok,why=pcall(draw,b,face,100,geometry(),true,1)
   assert(not ok and tostring(why):find('expired intent geometry handle: '..kind,1,true),'dead native guard was bypassed')
  end
 end)
 test('reentrant '..kind..' setters cannot leave stale successful promises',function()
  for _,name in ipairs(names)do for _,applyAfter in ipairs({false,true})do
   local b,h,bind=fixture();local a,c=bind(),bind();local old=geometry();a(b,face,100,old,true,1)
   local target=h[name];target.applyAfterCallback=applyAfter
   local changed=geometry(33,121,21)
   local nested=false;target[kind..'Callback']=function()nested=true;a(b,face,100,old,true,1)end
   c(b,{kind='attack',value='123456789'},100,changed,true,1);assert(nested,'native reentry was not exercised')
   local before=target[kind..'Writes'];c(b,{kind='attack',value='123456789'},100,changed,true,1)
   assert(target[kind..'Writes']==before+1,'overlapping native write was incorrectly cached')
   assertGeometry(h,changed,'123456789')
   c(b,{kind='attack',value='123456789'},100,changed,true,1);assert(target[kind..'Writes']==before+1)
  end end
 end)
 for _,failure in ipairs({'false','throw'})do
  test('reentrant '..kind..' '..failure..' cannot retain a nested successful promise',function()
   for _,name in ipairs(names)do
    local b,h,bind=fixture();local a,c=bind(),bind();local old=geometry();a(b,face,100,old,true,1)
    local target=h[name];target.applyAfterCallback=true
    target[kind..'Callback']=function()
     a(b,face,100,old,true,1);target[kind..'Failure']=failure
    end
    assert(pcall(c,b,{kind='attack',value='123456789'},100,geometry(33,121,21),true,1)==(failure=='false'))
    local before=target[kind..'Writes'];a(b,face,100,old,true,1)
    assert(target[kind..'Writes']==before+1,'failed outer write retained a nested promise')
    assertGeometry(h,old)
   end
  end)
 end
end
test('first publication keeps original size/position order',function()
 local b,_,bind,_,trace=fixture();bind()(b,face,100,geometry(),true,1)
 assert(table.concat(trace,',')=='intentIcon:size,intentIcon:position,intent:size,intent:position,intentHit:position,intentHit:size')
end)
local failed=0
for _,t in ipairs(tests)do local ok,why=pcall(t[2]);print((ok and 'ok ' or 'FAIL ')..t[1]..(ok and '' or ': '..tostring(why)));if not ok then failed=failed+1 end end
assert(failed==0,tostring(failed)..' intent geometry regressions failed')
print('INTENT_GEOMETRY_CACHE_PASS')
