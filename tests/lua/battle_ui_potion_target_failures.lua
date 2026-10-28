local sliceFirst,sliceLast=...
sliceFirst,sliceLast=sliceFirst or 1,sliceLast or 3
local sliceRegistered,sliceExecuted=0,0
local H = dofile("tests/lua/support/potion_targeting_fixture.lua")
local setup,Run,Combat,F,eq,untouched = H.setup,H.Run,H.Combat,H.F,H.eq,H.untouched
local originalTest,finish = H.suite("LUA_POTION_TARGET_FAILURES")
local function test(name,fn)
    sliceRegistered=sliceRegistered+1
    if sliceRegistered>=sliceFirst and sliceRegistered<=sliceLast then
        originalTest(name,fn);sliceExecuted=sliceExecuted+1
        print("BATTLE_UI_POTION_TARGET_FAILURES_CASE "..sliceRegistered)
    end
end

test('core absent-target refusal remains atomic and does not default',function()
  local h,u=setup();local b=h.run.combat;local inv,events,energy=h.run.potions,#b.events,b.energy
  local a,z=b.enemies[1].hp,b.enemies[2].hp;local ok,why=Run.usePotion(h.run,1,nil)
  eq(ok,false);eq(why,'invalid_target');eq(h.run.potions,inv);untouched(h,a,z);eq(#b.events,events);eq(b.energy,energy)
end)
test('presentation preparation failure cannot consume bottle and requires fresh arming',function()
  local h,u,p,r,e,click=setup();local b=h.run.combat;local a,z=b.enemies[1].hp,b.enemies[2].hp
  click('potion1');local render=u.render;u.render=function()error('TARGET_PREPARE_FAILURE')end
  local ok=e('enemy2','click');u.render=render;eq(ok,false);untouched(h,a,z);eq(u.potionAim,nil);assert(not u.busy)
  click('enemy2');untouched(h,a,z);assert(u.info);p:GetChild('statusInfo'):GetChild('hit').click();click('potion1');click('enemy2');eq(b.enemies[2].hp,z-20)
end)
test('end-turn release predating bottle cannot execute through newer pending mode',function()
  local h,u,p,r,e,click,tap=setup(true);e('endTurn','down',6);e('endTurn','up',6);tap('potion1',7)
  local pending,turn=u.potionAim,h.run.combat.turn;e('endTurn','click',6)
  eq(u.potionAim,pending);eq(h.run.combat.turn,turn);eq(h.run.potions[1],'fire_potion')
end)
test('real pending transaction overflow is atomic and a fresh target retry succeeds',function()
  -- Synthetic supported-core boundary, not an Ironclad natural acquisition claim.
  local h,u,p,r,e,click,tap=setup(true)
  assert(Run.discardPotion(h.run,1));assert(Run.obtainPotion(h.run,'poison_potion'));h:refresh();tap('potion1',7)
  local b=h.run.combat
  assert(require('abyss_actor').applyPower(b,b.enemies[2],'poison',2147483647,b.player))
  local inv,energy,events=h.run.potions,b.energy,#b.events
  local a,z=b.enemies[1].hp,b.enemies[2].hp
  e('enemy2','down',8);e('enemy2','up',8);local ok,why=e('enemy2','click',8)
  eq(ok,false);eq(why,'effect_overflow');eq(u.potionAim,nil);assert(not u.busy)
  eq(h.run.potions,inv);eq(h.run.potions[1],'poison_potion');eq(b.energy,energy);eq(#b.events,events)
  eq(b.enemies[1].hp,a);eq(b.enemies[2].hp,z);eq(b.enemies[2].statuses.poison,2147483647)
  e('enemy2','click',8);eq(h.run.potions,inv)
  tap('potion1',9);tap('enemy1',10);eq(h.run.potions[1],nil);eq(b.enemies[1].statuses.poison,6)
  eq(b.enemies[2].statuses.poison,2147483647);eq(b.energy,energy)
end)
for _,kind in ipairs({'up','endDrag'}) do
 test('orphan enemy '..kind..' cannot use click-only fallback without a Down',function()
  local h,u,p,r,e,click,tap=setup(true);tap('potion1',7);local z=h.run.combat.enemies[2].hp
  e('enemy2',kind,8);e('enemy2','click',8);eq(h.run.potions[1],'fire_potion');eq(h.run.combat.enemies[2].hp,z)
  tap('enemy2',9);eq(h.run.potions[1],nil);eq(h.run.combat.enemies[2].hp,z-20)
 end)
end
test('genuinely click-only enemy remains usable after paired bottle input',function()
  local h,u,p,r,e,click,tap=setup(true);tap('potion1',7);local z=h.run.combat.enemies[2].hp
  click('enemy2');eq(h.run.potions[1],nil);eq(h.run.combat.enemies[2].hp,z-20)
end)
finish()

assert(sliceRegistered==7,"all 7 original cases must register")
assert(sliceExecuted==sliceLast-sliceFirst+1,"every selected original case must execute")
print("BATTLE_UI_POTION_TARGET_FAILURES_SLICE "..sliceFirst.." "..sliceLast.." "..sliceExecuted)
