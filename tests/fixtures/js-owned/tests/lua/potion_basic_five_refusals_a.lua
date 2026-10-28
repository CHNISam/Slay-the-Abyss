local H=dofile('tests/lua/support/potion_basic_five_fixture.lua')
local Run,C,A,Data=H.Run,H.C,H.A,H.Data
local test,eq,same,battle,refuse,starter,use=H.test,H.eq,H.same,H.battle,H.refuse,H.starter,H.use
test('target phase slot failures preserve complete Swift and Weak Run graphs',function()
 for _,id in ipairs({'swift_potion','weak_potion'}) do
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
end)
H.finish(1,'LUA_POTION_BASIC_FIVE_REFUSALS_A_PASS')
