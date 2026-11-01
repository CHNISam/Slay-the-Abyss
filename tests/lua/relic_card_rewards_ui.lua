package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Run,C,Pending=require('abyss_run'),require('abyss_combat'),require('abyss_relic_pending')
local ui,root=F.fixture();assert(F.start(ui))
assert(Run.obtainRelic(ui.run,'prayer_wheel'));assert(Run.obtainRelic(ui.run,'singing_bowl'))
assert(Run.startRoomCombat(ui.run,'normal'))
for _,e in ipairs(ui.run.combat.enemies)do C.damage(ui.run.combat,ui.run.combat.player,e,20000,true)end
assert(Run.finishCombat(ui.run));ui:refresh();assert(ui.mode=='battle')
assert(F.click(root,'battlePanel','cardReward'));assert(ui.mode=='node'and Pending.owner(ui.run))
local function choose(index,choice)
 for i,row in ipairs(Pending.view(ui.run).rows)do if row.token.index==index and row.token.choice==choice then
  assert(ui.nodeUI:setPage(math.floor((i-1)/3)+1))
  return ui.nodeUI:press('eventView/option'..((i-1)%3+1))
 end end
 error('missing UI choice')
end
local old=ui.nodeUI.actions['eventView/option1'].handler
local maxHp,size=ui.run.maxHp,#ui.run.deck
assert(choose(2,'bowl'));assert(ui.run.maxHp==maxHp+2 and #ui.run.deck==size)
assert(not old());assert(choose(1,1));assert(#ui.run.deck==size+1)
assert(ui.run.rewards.cardResolved and not Pending.owner(ui.run));assert(ui.mode=='battle')
print('RELIC_CARD_REWARDS_UI_PASS ordinary reward button, all groups, Bowl, stale source, return')
