local H=dofile('tests/lua/support/potion_basic_five_fixture.lua')
local Run,C,A,Data=H.Run,H.C,H.A,H.Data
local test,eq,same,battle,refuse,starter,use=H.test,H.eq,H.same,H.battle,H.refuse,H.starter,H.use
test('Weak and Fear select only the requested enemy, stack duration, and decay on the next round',function()
 for _,spec in ipairs({{'weak_potion','weak'},{'fear_potion','vulnerable'}}) do
  for _,initial in ipairs({0,2}) do
   local run=battle({spec[1]},nil,'louse_pair');local s=run.combat
   if initial>0 then C.addStatus(s.enemies[2],spec[2],initial) end
   use(run,1,2);eq(s.enemies[2].statuses[spec[2]],initial+3);eq(s.enemies[1].statuses[spec[2]] or 0,0)
   assert(not s.enemies[2][spec[2]..'JustApplied'])
   if spec[2]=='weak' then eq(A.attackAmount(s,s.enemies[2],s.player,8),6)
   else eq(A.attackAmount(s,s.player,s.enemies[2],8),12) end
   assert(Run.endTurn(run));eq(s.enemies[2].statuses[spec[2]],initial+2)
  end
 end
end)
test('enemy Artifact blocks Weak or Fear as a successful consumed use, then the next bottle applies three',function()
 for _,spec in ipairs({{'weak_potion','weak'},{'fear_potion','vulnerable'}}) do
  local run=battle({spec[1],spec[1]},nil,'louse_pair');local s=run.combat
  C.addStatus(s.enemies[2],'artifact',1);use(run,1,2)
  eq(s.enemies[2].statuses.artifact,0);eq(s.enemies[2].statuses[spec[2]] or 0,0)
  use(run,2,2);eq(s.enemies[2].statuses[spec[2]],3)
 end
end)
test('Ancient stacks one Artifact per bottle and blocks one debuff per stack without end-turn decay',function()
 local run=battle({'ancient_potion','ancient_potion'},nil,'cultist_solo');local s=run.combat
 use(run,1);use(run,2);eq(s.player.statuses.artifact,2)
 assert(not A.applyPower(s,s.player,'weak',3,s.enemies[1],true));eq(s.player.statuses.artifact,1)
 eq(s.player.statuses.weak or 0,0);assert(Run.endTurn(run));eq(s.player.statuses.artifact,1)
 assert(not A.applyPower(s,s.player,'frail',1,s.enemies[1],true));eq(s.player.statuses.artifact,0)
 assert(A.applyPower(s,s.player,'weak',3,s.enemies[1],true));eq(s.player.statuses.weak,3)
end)
test('Liquid Bronze stacks three persistent Thorns and retaliates on each blocked attack without recursion',function()
 local run=battle({'liquid_bronze','liquid_bronze'},nil,'cultist_solo');local s=run.combat
 use(run,1);eq(s.player.statuses.thorns,3);use(run,2);eq(s.player.statuses.thorns,6)
 C.addStatus(s.enemies[1],'thorns',20);s.player.block=20
 local hp,enemyHp=s.player.hp,s.enemies[1].hp
 C.damage(s,s.enemies[1],s.player,1);eq(s.player.hp,hp);eq(s.enemies[1].hp,enemyHp-6)
 C.damage(s,s.enemies[1],s.player,1);eq(s.player.hp,hp);eq(s.enemies[1].hp,enemyHp-12)
 assert(Run.endTurn(run));eq(s.player.statuses.thorns,6)
end)
H.finish(4,'LUA_POTION_BASIC_FIVE_STATUS_PASS')
