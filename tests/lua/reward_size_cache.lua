local Layout=require('abyss_battle_reward_layout')
local Theme=require('abyss_theme')
local tests={}
local function test(name,fn)tests[#tests+1]={name,fn}end
local function fixture()
 local handles={};local total=0
 local function make(key)
  local c={writes=0,alive=true}
  function c:GetChild(name)return handles[key..'/'..name]end
  function c:SetSizeDelta(w,h)
   self.writes=self.writes+1;total=total+1
   assert(self.alive,'expired native size handle')
   self.w,self.h=w,h
   local failure=self.failure;self.failure=nil
   if failure=='throw'then error('size applied then threw')end
   if failure=='false'then return false end
   -- nil is a successful documented mock/native setter return.
  end
  function c:SetAnchoredPosition(x,y)self.x,self.y=x,y end
  function c:SetVisible(v)self.visible=v end
  handles[key]=c;return c
 end
 for _,name in ipairs({'rewardList','rewardList/border','rewardList/plate','rewardList/title','rewardList/subtitle','potionReward','goldReward','stolenGold','relicReward1','relicReward2','emeraldKeyReward','claimPotion','cardReward','continue'})do make(name)end
 local child=function(name)return assert(handles[name])end
 local owner={}
 local function frame(expanded)
  return {listing=true,manual=true,pendingPotion=expanded==true,run={rewards={goldClaimed=false,cardResolved=false,
   relics=expanded and {{claimed=false},{claimed=false}}or {},emeraldKey=expanded and {claimed=false}or nil}}}
 end
 return handles,child,owner,frame,make,function()return total end
end
local sizeNames={'rewardList','rewardList/border','rewardList/plate','rewardList/title','rewardList/subtitle','potionReward'}
test('300 unchanged renders retain geometry and omit all six size writes',function()
 local h,c,o,f,_,total=fixture();local state=f(false);Layout.render(state,c,o)
 local saved={};for key,v in pairs(h)do saved[key]={x=v.x,y=v.y,w=v.w,h=v.h,visible=v.visible}end
 local before=total();for _=1,300 do Layout.render(state,c,o)end
 print('REWARD_SIZE_MODULE repeated=300 sizeWrites='..(total()-before))
 assert(total()==before,'unchanged reward sizes resubmitted')
 for key,values in pairs(saved)do for k,v in pairs(values)do assert(h[key][k]==v,'stable geometry changed')end end
 for _,name in ipairs(sizeNames)do assert(h[name].writes==1,'each target must submit once')end
end)
test('ordinary expanded ordinary preserves approved geometry and row order',function()
 local h,c,o,f=fixture()
 for _,expanded in ipairs({false,true,false})do
  local state=f(expanded);Layout.render(state,c,o)
  local spec=expanded and Theme.layout.battleRewards.expanded or Theme.layout.battleRewards
  local box=h.rewardList
  assert(box.x==spec.stage[1] and box.y==spec.stage[2] and box.w==spec.stage[3] and box.h==spec.stage[4])
  assert(h.goldReward.y==spec.rowOrigin[2] and h.goldReward.x==spec.rowOrigin[1])
  assert(h.cardReward.y==spec.rowOrigin[2]-(state.rewardRows-1)*spec.rowStep)
  assert(h.claimPotion.visible==expanded and h.potionReward.visible==expanded)
 end
end)
test('width and height changes each repaint independently',function()
 local h,c,o,f=fixture();local spec=Theme.layout.battleRewards.stage
 local w,height=spec[3],spec[4];Layout.render(f(false),c,o)
 spec[3]=w+1;Layout.render(f(false),c,o);assert(h.rewardList.w==w+1 and h.rewardList.writes==2)
 spec[4]=height+1;Layout.render(f(false),c,o);assert(h.rewardList.h==height+1 and h.rewardList.writes==3)
 spec[3],spec[4]=w,height
end)
test('A B A ownership and fresh same-name handles repaint',function()
 local h,c,a,f,make=fixture();local b={};local state=f(false)
 Layout.render(state,c,a);Layout.render(state,c,b);Layout.render(state,c,a)
 for _,name in ipairs(sizeNames)do assert(h[name].writes==3,'shared handle owner not invalidated')end
 local fresh=make('rewardList/title');Layout.render(state,c,a);assert(fresh.writes==1,'new handle skipped')
end)
for _,failure in ipairs({'false','throw'})do
 test('partially applied '..failure..' clears old successful cache on every target',function()
  for _,name in ipairs(sizeNames)do
   local h,c,o,f=fixture();local state=f(false);Layout.render(state,c,o)
   local target=h[name];local w,height=target.w,target.h
   -- Switch owners so every target must be attempted, including unchanged dimensions.
   target.failure=failure
   local ok=pcall(Layout.render,f(true),c,{})
   assert(ok==(failure=='false'),'failure propagation changed')
   local before=target.writes
   Layout.render(state,c,o)
   assert(target.writes==before+1 and target.w==w and target.h==height,'old promise survived partial failure')
   Layout.render(state,c,o);assert(target.writes==before+1,'retry success was not cached')
  end
 end)
end
test('ownerless calls invalidate tracked handles but never cache their own writes',function()
 local h,c,o,f=fixture();Layout.render(f(false),c,o)
 Layout.render(f(true),c);Layout.render(f(false),c,o)
 for _,name in ipairs(sizeNames)do assert(h[name].writes==3,'ownerless write left stale owner promise')end
 Layout.render(f(false),c);Layout.render(f(false),c)
 for _,name in ipairs(sizeNames)do assert(h[name].writes==5,'legacy ownerless render unexpectedly cached')end
end)
for _,failure in ipairs({'false','throw'})do
 test('ownerless partial '..failure..' invalidates the former owner promise',function()
  local h,c,o,f=fixture();Layout.render(f(false),c,o)
  h.rewardList.failure=failure
  assert(pcall(Layout.render,f(true),c)==(failure=='false'))
  local before=h.rewardList.writes;Layout.render(f(false),c,o)
  assert(h.rewardList.writes==before+1 and h.rewardList.w==Theme.layout.battleRewards.stage[3])
 end)
end
test('expired native handles still reject repeated same dimensions',function()
 for _,name in ipairs(sizeNames)do
  local h,c,o,f=fixture();Layout.render(f(false),c,o);h[name].alive=false
  local ok,why=pcall(Layout.render,f(false),c,o)
  assert(not ok and tostring(why):find('expired native size handle',1,true),'cache swallowed dead-object validation')
  assert(h[name].writes==2,'dead object never reached native setter')
 end
end)
local failed=0
for _,t in ipairs(tests)do local ok,why=pcall(t[2]);print((ok and 'ok ' or 'FAIL ')..t[1]..(ok and '' or ': '..tostring(why)));if not ok then failed=failed+1 end end
assert(failed==0,tostring(failed)..' reward size regressions failed')
print('REWARD_SIZE_CACHE_PASS')
