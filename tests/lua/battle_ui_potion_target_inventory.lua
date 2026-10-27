local first,last=...
first,last=first or 1,last or 4
assert(type(first)=='number'and type(last)=='number'and first%1==0 and last%1==0 and first>=1 and last<=7 and first<=last,'invalid potion inventory slice')
local registered,executed=0,0
local H = dofile("tests/lua/support/potion_targeting_fixture.lua")
local setup,Run,Combat,F,eq,untouched = H.setup,H.Run,H.Combat,H.F,H.eq,H.untouched
local test,finish = H.suite("LUA_POTION_TARGET_INVENTORY")
local originalTest=test
test=function(name,fn)
 registered=registered+1
 if registered<first or registered>last then return end
 executed=executed+1
 return originalTest(name,fn)
end

for _,id in ipairs({'fire_potion','block_potion'}) do
 test('real discard/refill '..id..' cannot inherit old pending without redraw',function()
  local h,u,p,r,e,click=setup();click('potion1');assert(Run.discardPotion(h.run,1));assert(Run.obtainPotion(h.run,id));local z=h.run.combat.enemies[2].hp
  click('enemy2');eq(h.run.potions[1],id);eq(h.run.combat.enemies[2].hp,z);eq(h.run.combat.player.block,0);eq(u.potionAim,nil)
 end)
end
test('other-slot real use changes inventory and invalidates pending',function()
  local h,u,p,r,e,click=setup();assert(Run.obtainPotion(h.run,'energy_potion'));h:refresh();click('potion1')
  assert(Run.usePotion(h.run,2));click('enemy2');eq(h.run.potions[1],'fire_potion');eq(u.potionAim,nil);eq(h.run.combat.energy,5)
end)
test('switch same-ID bottle only arms new physical slot',function()
  local h,u,p,r,e,click=setup();assert(Run.obtainPotion(h.run,'fire_potion'));h:refresh();click('potion1');click('potion2');eq(Run.potionCount(h.run),2)
  click('enemy2');eq(h.run.potions[1],'fire_potion');eq(h.run.potions[2],nil)
end)
test('dead enemy is rejected and never retargets to survivor',function()
  local h,u,p,r,e,click=setup();click('potion1');local b=h.run.combat
  for _=1,5 do
    if b.enemies[1].hp<=0 then break end
    local uid;for _,c in ipairs(b.hand) do if Combat.cardDefinition(b,c).type=='attack' and Combat.canPlay(b,c.uid,1) then uid=c.uid;break end end
    assert(uid);assert(Run.play(h.run,uid,1))
  end
  eq(b.enemies[1].hp,0);local z=b.enemies[2].hp;click('enemy1');eq(h.run.potions[1],'fire_potion');eq(b.enemies[2].hp,z)
  -- The integrated controller cancels when the live roster changes.
  click('enemy2');eq(b.enemies[2].hp,z);eq(h.run.potions[1],'fire_potion')
  assert(p:GetChild('enemy1').visible and p:GetChild('enemy1'):GetChild('name').text==b.enemies[2].name)
  assert(not p:GetChild('enemy2').visible)
  click('potion1');click('enemy1');eq(b.enemies[2].hp,z-20);eq(h.run.potions[1],nil)
end)
test('paired touch begins only on Click and confirms exactly once',function()
  local h,u,p,r,e,click,tap,drain=setup(true);local z=h.run.combat.enemies[2].hp
  e('potion1','down',7);e('potion1','up',7);eq(u.potionAim,nil);e('potion1','click',7);assert(u.potionAim);eq(h.run.potions[1],'fire_potion')
  e('potion1','click',7);assert(u.potionAim);tap('enemy2',8);eq(h.run.combat.enemies[2].hp,z-20)
  e('enemy2','click',8);eq(h.run.combat.enemies[2].hp,z-20)
end)
test('foreign or missing touch cannot confirm released enemy token',function()
  local h,u,p,r,e,click,tap=setup(true);tap('potion1',7);e('enemy2','down',8);e('enemy2','up',8)
  e('enemy2','click',9);e('enemy2','click');eq(h.run.potions[1],'fire_potion');e('enemy2','click',8);eq(h.run.potions[1],nil)
end)
finish()
assert(registered==7,'all original potion inventory cases must register')
assert(executed==last-first+1,'all selected potion inventory cases must execute')
print('POTION_TARGET_INVENTORY_PART '..first..' '..last..' '..executed)
