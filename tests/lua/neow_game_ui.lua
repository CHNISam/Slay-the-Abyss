local testStart=dofile('tests/lua/support/game_ui_fixture.lua').start
-- Actual generated GameUI/Nodes/core. Provider values are staged test input;
-- the death below is produced by real end-turn commands, not a forged result.
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Run=require('abyss_run')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function fixture(seed,provider,prologue,settle)
 local canvas=F.control({children=F.Layout});local root=F.Viewport.apply(canvas,1280,720)
 local ui=F.GameUI.new(root,F.Data,F.Presentation,'click',{seed=seed,imageSource='static',
  color=function(r,g,b,a)return {r=r,g=g,b=b,a=a}end,prologue=prologue==true,readNeowHistory=provider,settle=settle})
 root.ui=ui;return ui,root
end
local function nodeClick(root,button)return F.click(root,'nodePanel',button)end
local n=0
local function test(name,fn)fn();n=n+1;print('PASS neow host '..n..' '..name)end
test('unknown first load keeps existing playable opening and displays exact history blocker',function()
 local ui,root=fixture(42);assert(testStart(ui));eq(ui.mode,'map');eq(ui.run.neowStatus,'unavailable')
 eq(ui.run.neowUnavailableReason,'neow_history_unavailable');eq(ui.run.nodeFlow,nil);eq(ui.run.hp,80);eq(ui.run.maxHp,80)
 assert(F.mapControl(root:GetChild('mapPanel'),'notice').text:find('未取得上一局历史',1,true));assert(F.Nodes.available(ui.run,ui.map)[1])
end)
test('normal Start accepts explicit platform mini history and generated buttons return to first legal room',function()
 local calls=0;local ui,root=fixture(42,function(role)calls=calls+1;eq(role,'ironclad');return {bossCount=0}end)
 assert(testStart(ui));eq(calls,1);eq(ui.mode,'node');eq(ui.run.nodeFlow.event.stage,'neow_intro')
 assert(nodeClick(root,'eventView/option1'));assert(nodeClick(root,'eventView/option2'));eq(ui.run.maxHp,88)
 assert(nodeClick(root,'eventView/option1'));eq(ui.mode,'map');eq(ui.run.neowStatus,'complete');eq(ui.map.floor,0)
 local first=F.Nodes.available(ui.run,ui.map)[1];assert(ui.mapUI:choose(first.id));eq(ui.run.phase,'combat')
end)
test('approved prologue hands off to the full-source Neow only after its fade',function()
 local ui,root=fixture(4,function()return {bossCount=1}end,true)
 assert(testStart(ui));eq(ui.mode,'node');eq(ui.run.phase,'node');eq(ui.run.nodeFlow.event.id,'neow')
 assert(ui.prologue:covering());assert(ui.prologue:skip());ui:update(1);ui:update(1)
 eq(ui.mode,'node');assert(root:GetChild('nodePanel').visible);assert(not root:GetChild('mapPanel').visible)
 assert(nodeClick(root,'eventView/option1'));eq(#ui.run.nodeFlow.event.rewards,4)
 assert(nodeClick(root,'eventView/option1'));eq(ui.nodeUI.picker,'neow_card')
 assert(nodeClick(root,'pickerView/card1'));assert(nodeClick(root,'confirm'));eq(ui.run.deck[1].upgraded,true)
 assert(nodeClick(root,'eventView/option1'));eq(ui.mode,'map')
end)
test('real first-room death creates next-run mini qualification only inside the same host',function()
 local ui,root=fixture(42);assert(testStart(ui));local first=F.Nodes.available(ui.run,ui.map)[1]
 assert(ui.mapUI:choose(first.id));eq(ui.run.phase,'combat')
 for _=1,40 do if ui.run.phase~='combat'then break end;assert(Run.endTurn(ui.run))end
 eq(ui.run.phase,'defeat');eq(ui.run.hp,0);local ended=ui.run;ui:refresh();eq(ui.mode,'defeat')
 assert(testStart(ui));assert(ui.run~=ended);eq(ui.run.neowHistorySource,'session-completed-run');eq(ui.mode,'node')
 assert(nodeClick(root,'eventView/option1'));eq(#ui.run.nodeFlow.event.rewards,2)
 local other=fixture(42);assert(testStart(other));eq(other.run.neowStatus,'unavailable')
end)
test('failed explicit settlement is not recorded as abandonment; accepted request records current floor only',function()
 local accepted=false;local ui,root=fixture(42,nil,false,function()return accepted end)
 assert(testStart(ui));assert(ui:openExit());local ok=ui:confirmExit();eq(ok,false);eq(ui.run.neowStatus,'unavailable')
 accepted=true;assert(ui:confirmExit());eq(ui.settlementRequested,true)
 -- The platform exits this level after acceptance. A new host has no invented
 -- persistent readback; its unknown initial history remains unavailable.
 local other=fixture(42);assert(testStart(other));eq(other.run.neowStatus,'unavailable')
end)
print('NEOW_GAME_UI '..n..' passed')
