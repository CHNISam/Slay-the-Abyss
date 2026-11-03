local UI=require('abyss_map_ui')
local Layout=require('abyss_map_layout')
local function fixture()
 local controls,trace={},{}
 for _,name in ipairs({'icon','ring'})do
  local c={alive=true,writes=0};controls[name]=c
  function c:SetSizeDelta(w,h)
   assert(self.alive,'dead map size handle');self.writes=self.writes+1
   trace[#trace+1]=name..':'..w
   local fn,why,reject,after=self.callback,self.failure,self.reject,self.after
   self.callback,self.failure,self.reject=nil,nil,nil
   if fn and after then fn()end
   self.w,self.h=w,h
   if fn and not after then fn()end
   if why then error(why,0)end
   if reject then return false end
  end
 end
 local box={GetChild=function(_,name)return controls[name]end}
 local function fx(scale)return {box=box,size=30,scale=scale,state='locked',alpha=1}end
 return fx(.5),fx(.8),controls,trace
end
local function check(fx,controls,label)
 local sizes={icon=fx.size*Layout.sts.iconPerScale*UI.drawScale(fx),ring=fx.size*Layout.sts.circlePerScale*(fx.scale*.95+.2)}
 for name,size in pairs(sizes)do local c=controls[name];assert(c.w==size and c.h==size,label..' wrong '..name..' size')end
end
local cases=0
for _,failure in ipairs({'success','false','throw'})do
 for _,name in ipairs({'icon','ring'})do for _,after in ipairs({false,true})do
  for _,recoverOld in ipairs({false,true})do
   local a,b,controls=fixture();local target=controls[name]
   UI.paintRoom(a);check(a,controls,'initial')
   local err={kind='original error'}
   target.callback=function()UI.paintRoom(a)end
   target.after=after;target.failure=failure=='throw'and err or nil;target.reject=failure=='false'
   local ok,why=pcall(UI.paintRoom,b)
   assert(ok==(failure~='throw')and(ok or why==err),'original size failure changed')
   local next=recoverOld and a or b;local before=target.writes
   UI.paintRoom(next)
   check(next,controls,'nested map write after '..failure)
   assert(target.writes==before+1,'overlapping map size promise cached after '..failure)
   UI.paintRoom(next);assert(target.writes==before+1,'successful retry not cached')
   cases=cases+1
  end
 end end
end
-- Ordinary false/throw without reentry must invalidate the old owner's promise.
for _,failure in ipairs({'false','throw'})do for _,recoverOld in ipairs({false,true})do
 local a,b,controls=fixture();UI.paintRoom(a);local target=controls.icon;local err={}
 target.failure=failure=='throw'and err or nil;target.reject=failure=='false'
 local ok,why=pcall(UI.paintRoom,b);assert(ok==(failure~='throw')and(ok or why==err))
 local next=recoverOld and a or b;local before=target.writes;UI.paintRoom(next)
 assert(target.writes==before+1,'failed size promise survived');check(next,controls,'ordinary failure')
end end
local a,b,controls,trace=fixture();UI.paintRoom(a)
assert(trace[1]:sub(1,5)=='icon:'and trace[2]:sub(1,5)=='ring:','first setter order changed')
UI.paintRoom(b);UI.paintRoom(a);assert(controls.icon.writes==3,'owner switch skipped')
for _=1,300 do UI.paintRoom(a)end
assert(controls.icon.writes==3 and controls.ring.writes==3,'stable size writes regressed')
for _,name in ipairs({'icon','ring'})do
 local x,_,handles=fixture();UI.paintRoom(x);handles[name].alive=false
 local ok,why=pcall(UI.paintRoom,x)
 assert(not ok and tostring(why):find('dead map size handle',1,true),'dead size access bypassed')
end
local fresh,_,newHandles=fixture();UI.paintRoom(fresh);check(fresh,newHandles,'fresh handle')
print('MAP_SIZE_REENTRY_PASS '..cases..' overlap cases, failures, ownership, order, stable, dead, fresh')
