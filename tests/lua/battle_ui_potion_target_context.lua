local H = dofile("tests/lua/support/potion_targeting_fixture.lua")
local setup,Run,Combat,F,eq,untouched = H.setup,H.Run,H.Combat,H.F,H.eq,H.untouched
local test,finish = H.suite("LUA_POTION_TARGET_CONTEXT")

for _,overlay in ipairs({'Deck','Potions','Exit'}) do
 test('opening and closing '..overlay..' cancels pending',function()
  local h,u,p,r,e,click=setup();local b=h.run.combat;local a,z=b.enemies[1].hp,b.enemies[2].hp
  click('potion1');assert(h['open'..overlay](h));assert(h['close'..overlay](h));click('enemy2');untouched(h,a,z);eq(u.potionAim,nil)
 end)
end
test('resize cancels pending even on click-only host',function()
  local h,u,p,r,e,click=setup();local b=h.run.combat;local a,z=b.enemies[1].hp,b.enemies[2].hp
  click('potion1');h:resize(1600,900);click('enemy2');untouched(h,a,z);eq(u.potionAim,nil)
end)
test('detail overlay cancels pending instead of reviving on dismissal',function()
  local h,u,p,r,e,click=setup();local b=h.run.combat;local a,z=b.enemies[1].hp,b.enemies[2].hp
  click('potion1');assert(u:showStatus(0));click('enemy2');click('enemy2');untouched(h,a,z);eq(u.potionAim,nil)
end)
test('new turn rejects pending before render',function()
  local h,u,p,r,e,click=setup();click('potion1');assert(Run.endTurn(h.run));local z=h.run.combat.enemies[2].hp
  click('enemy2');eq(h.run.potions[1],'fire_potion');eq(h.run.combat.enemies[2].hp,z);eq(u.potionAim,nil)
end)
test('run replacement cancels pending',function()
  local h,u,p,r,e,click=setup();click('potion1');local old=h.run
  h.run=Run.new(F.Data,4);u.run=h.run;h.nodeUI.run=h.run -- same controller rebinding as GameUI:start
  assert(Run.startCombat(h.run,'small_slimes'));assert(Run.obtainPotion(h.run,'fire_potion'));h:refresh()
  local z=h.run.combat.enemies[2].hp;click('enemy2');eq(h.run.combat.enemies[2].hp,z);eq(h.run.potions[1],'fire_potion');eq(old.potions[1],'fire_potion');eq(u.potionAim,nil)
end)
test('combat replacement cancels pending',function()
  local h,u,p,r,e,click=setup();click('potion1');h.run.combat=Combat.new(F.Data,{enemies={'cultist','jaw_worm'}});h:refresh()
  local z=h.run.combat.enemies[2].hp;click('enemy2');eq(h.run.combat.enemies[2].hp,z);eq(h.run.potions[1],'fire_potion');eq(u.potionAim,nil)
end)
finish()
