local H=dofile('tests/lua/support/potion_basic_five_fixture.lua')
local Run,C,A,Data=H.Run,H.C,H.A,H.Data
local test,eq,same,battle,refuse,starter,use=H.test,H.eq,H.same,H.battle,H.refuse,H.starter,H.use
test('five production bottles use normal obtain/view/use and preserve surrounding fixed slots',function()
 for _,id in ipairs({'swift_potion','weak_potion','fear_potion','ancient_potion','liquid_bronze'}) do
  local run=battle({'fire_potion',id,'block_potion'},nil,'louse_pair')
  local targeted=id=='weak_potion' or id=='fear_potion'
  local before=C.copy(run);local view=Run.potionView(run)[2]
  eq(view.id,id);eq(view.needTarget,targeted);assert(view.canUse);same(run,before)
  use(run,2,targeted and 2 or nil);eq(run.potions[1],'fire_potion');eq(run.potions[3],'block_potion')
 end
end)
test('target, phase, slot and overflow failures leave all Run fields and identities unchanged',function()
 for _,id in ipairs({'swift_potion','weak_potion','fear_potion','ancient_potion','liquid_bronze'}) do
  local run=battle({id},nil,'louse_pair')
  refuse(run,0,1,'invalid_potion_slot');refuse(run,1.5,1,'invalid_potion_slot')
  if id=='weak_potion' or id=='fear_potion' then
   refuse(run,1,nil,'invalid_target');refuse(run,1,3,'invalid_target')
   run.combat.enemies[2].escaped=true;refuse(run,1,2,'invalid_target')
   run.combat.enemies[2].escaped=false;run.combat.enemies[2].hp=0;refuse(run,1,2,'invalid_target')
  end
  run.combat.phase='enemy';refuse(run,1,1,'not_player_turn');run.combat.phase='player'
  run.phase='map';refuse(run,1,1,'not_in_combat')
 end
 for _,spec in ipairs({{'ancient_potion','artifact'},{'liquid_bronze','thorns'},{'weak_potion','weak'},{'fear_potion','vulnerable'}}) do
  local run=battle({spec[1]},nil,'louse_pair')
  local actor=spec[1]=='weak_potion' or spec[1]=='fear_potion'
  actor=actor and run.combat.enemies[2] or run.combat.player
  actor.statuses[spec[2]]=2147483647;refuse(run,1,2,'effect_overflow')
 end
end)
H.finish(2,'LUA_POTION_BASIC_FIVE_PASS')
