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
H.finish(1,'LUA_POTION_BASIC_FIVE_PASS')
