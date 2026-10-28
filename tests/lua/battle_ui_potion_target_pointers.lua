local first,last=...
first,last=first or 1,last or 2
assert(type(first)=='number'and type(last)=='number'and first%1==0 and last%1==0 and first>=1 and last<=7 and first<=last,'invalid potion pointer slice')
local registered,executed=0,0
local H = dofile("tests/lua/support/potion_targeting_fixture.lua")
local setup,Run,Combat,F,eq,untouched = H.setup,H.Run,H.Combat,H.F,H.eq,H.untouched
local test,finish = H.suite("LUA_POTION_TARGET_POINTERS")
local originalTest=test
test=function(name,fn)
 registered=registered+1
 if registered<first or registered>last then return end
 executed=executed+1
 return originalTest(name,fn)
end

test('enemy Down predating pending cannot authorize potion use',function()
  local h,u,p,r,e,click,tap=setup(true);e('enemy2','down',8);tap('potion1',7);e('enemy2','up',8);e('enemy2','click',8)
  eq(h.run.potions[1],'fire_potion');tap('enemy2',9);eq(h.run.potions[1],nil)
end)
test('old enemy token cannot confirm newer same-ID bottle',function()
  local h,u,p,r,e,click,tap=setup(true);assert(Run.obtainPotion(h.run,'fire_potion'));h:refresh()
  tap('potion1',7);e('enemy2','down',8);e('enemy2','up',8);tap('potion2',9);e('enemy2','click',8)
  eq(Run.potionCount(h.run),2);tap('enemy2',10);eq(h.run.potions[1],'fire_potion');eq(h.run.potions[2],nil)
end)
test('enemy EndDrag cancels its token without spending pending bottle',function()
  local h,u,p,r,e,click,tap=setup(true);tap('potion1',7);e('enemy2','down',8);e('enemy2','up',8);e('enemy2','endDrag',8);e('enemy2','click',8)
  eq(h.run.potions[1],'fire_potion');eq(u.potionAim,nil)
  tap('enemy2',9);eq(h.run.potions[1],'fire_potion');assert(u.info);p:GetChild('statusInfo'):GetChild('hit').click()
  tap('potion1',10);tap('enemy2',11);eq(h.run.potions[1],nil)
end)
test('metadata-free pointer events preserve separate arming and confirmation',function()
  local h,u,p,r,e,click,tap=setup(true);tap('potion1');eq(h.run.potions[1],'fire_potion');tap('enemy2');eq(h.run.potions[1],nil)
end)
test('card selection cancels bottle and keeps C-mode target behavior',function()
  local h,u,p,r,e,click=setup();click('potion1');local b=h.run.combat;local slot
  for i,c in ipairs(b.hand) do if Combat.cardDefinition(b,c).type=='attack' and Combat.canPlay(b,c.uid,2) then slot=i;break end end
  assert(slot);local energy=b.energy;click('card'..slot);eq(u.potionAim,nil);assert(u.selected);click('enemy2');eq(h.run.potions[1],'fire_potion');assert(b.energy<energy)
end)
test('non-target potion keeps immediate action and cancels other pending',function()
  local h,u,p,r,e,click=setup();assert(Run.obtainPotion(h.run,'energy_potion'));h:refresh();click('potion1');click('potion2')
  eq(h.run.combat.energy,5);eq(h.run.potions[1],'fire_potion');eq(h.run.potions[2],nil);eq(u.potionAim,nil)
end)
test('repeat enemy and bottle callbacks during playback cannot spend refill',function()
  local h,u,p,r,e,click,tap,drain=setup(true);tap('potion1',7);e('enemy2','down',8);e('enemy2','up',8);e('enemy2','click',8);assert(u.busy)
  assert(Run.obtainPotion(h.run,'fire_potion'));local z=h.run.combat.enemies[2].hp
  e('enemy2','click',8);e('potion1','click',7);eq(h.run.potions[1],'fire_potion');eq(h.run.combat.enemies[2].hp,z);drain()
  e('enemy2','click',8);e('potion1','click',7);eq(h.run.potions[1],'fire_potion')
end)
finish()
assert(registered==7,'all original potion pointer cases must register')
assert(executed==last-first+1,'all selected potion pointer cases must execute')
print('POTION_TARGET_POINTER_PART '..first..' '..last..' '..executed)
