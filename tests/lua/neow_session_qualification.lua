-- Controlled prior-run boundary, not a natural playthrough or persisted unlock.
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local function fixture()
 local root=F.Viewport.apply(F.control({children=F.Layout}),1280,720)
 local ui=F.GameUI.new(root,F.Data,F.Presentation,'click',{seed=42,campaign=true,
  campaignProfile='competition-two-act',imageSource='static',
  color=function(r,g,b,a)return {r=r,g=g,b=b,a=a}end,
  readNeowHistory=function()error('competition must not consult persistent history')end})
 root.ui=ui
 return ui,root
end
local function offers(ui,root)
 assert(F.start(ui));assert(F.click(root,'nodePanel','eventView/option1'))
 return ui.run.nodeFlow.event.rewards
end
local ui,root=fixture()
assert(#offers(ui,root)==2 and ui.run.neowHistorySource=='fresh-start')
assert(ui.run.nodeFlow.event.hpBonus==8)
-- Ending below the original floor threshold cannot manufacture four offers.
ui.run.floor=15;ui.run.phase='defeat';ui.run.hp=0;ui:refresh()
assert(#offers(ui,root)==2 and ui.run.neowHistorySource=='session-completed-run')
-- The threshold is reaching floor 16, not a permanent Boss-kill unlock.
ui.run.floor=16;ui.run.phase='defeat';ui.run.hp=0;ui:refresh()
assert(#offers(ui,root)==4 and ui.run.neowHistorySource=='session-completed-run')
local other,otherRoot=fixture()
assert(#offers(other,otherRoot)==2 and other.run.neowHistorySource=='fresh-start')
print('NEOW_SESSION_QUALIFICATION_PASS')
