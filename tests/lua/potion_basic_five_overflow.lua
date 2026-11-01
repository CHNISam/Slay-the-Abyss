local H=dofile('tests/lua/support/potion_basic_five_fixture.lua')
local Run,C,A,Data=H.Run,H.C,H.A,H.Data
local test,eq,same,battle,refuse,starter,use=H.test,H.eq,H.same,H.battle,H.refuse,H.starter,H.use
test('all four original overflow refusals preserve complete Run fields and identities',function()
 for _,spec in ipairs({{'ancient_potion','artifact'},{'liquid_bronze','thorns'},{'weak_potion','weak'},{'fear_potion','vulnerable'}}) do
  local run=battle({spec[1]},nil,'louse_pair')
  local actor=spec[1]=='weak_potion' or spec[1]=='fear_potion'
  actor=actor and run.combat.enemies[2] or run.combat.player
  actor.statuses[spec[2]]=2147483647;refuse(run,1,2,'effect_overflow')
 end
end)
H.finish(1,'LUA_POTION_BASIC_FIVE_OVERFLOW_PASS')
