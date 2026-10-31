-- Actual GameUI owner and public Nodes/Run commands with generated controls.
-- The first fifteen map floors are a controlled prefix, not a natural route;
-- Boss entry and death below are real commands, never a fabricated outcome.
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Run,Map=require('abyss_run'),require('abyss_map')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function new()
 local canvas=F.control({children=F.Layout});local root=F.Viewport.apply(canvas,1280,720)
 local reads=0
 local ui=F.GameUI.new(root,F.Data,F.Presentation,'click',{seed=42,imageSource='static',
  color=function(r,g,b,a)return {r=r,g=g,b=b,a=a}end,campaign=true,campaignProfile='competition-two-act',
  readNeowHistory=function()reads=reads+1;return {bossCount=1}end})
 root.ui=ui
 return ui,root,function()return reads end
end
local function click(root,path)assert(F.click(root,'nodePanel',path))end
local function start(ui,root,offers)
 assert(F.start(ui));eq(ui.run.nodeFlow.event.id,'neow');click(root,'eventView/option1')
 eq(#ui.run.nodeFlow.event.rewards,offers)
end
local function finishMini(ui,root)
 click(root,'eventView/option2');click(root,'eventView/option1');eq(ui.run.phase,'map')
end
local function die(ui)
 for _=1,50 do if ui.run.phase~='combat'then break end;assert(Run.endTurn(ui.run))end
 eq(ui.run.phase,'defeat');eq(ui.run.hp,0);ui:refresh();eq(ui.mode,'defeat')
end
local ui,root,reads=new();start(ui,root,2);eq(ui.run.neowHistorySource,'fresh-start');eq(reads(),0)
finishMini(ui,root)
-- A complete legal map prefix isolates the session-history boundary. The
-- Boss floor and combat outcome are produced by public entry/end-turn commands.
while Map.available(ui.map)[1].floor<16 do assert(Map.choose(ui.map,Map.available(ui.map)[1].id))end
ui.run.floor=ui.map.floor;ui.run.nodeFlow=nil;ui:refresh()
local boss=F.Nodes.available(ui.run,ui.map)[1];eq(boss.floor,16)
assert(ui.mapUI:choose(boss.id));eq(ui.run.floor,16);eq(ui.run.nodeFlow.type,'boss');eq(ui.run.phase,'combat')
die(ui);local ended=ui.run;start(ui,root,4);assert(ui.run~=ended)
eq(ui.run.neowHistorySource,'session-completed-run');eq(reads(),0)
local other,otherRoot,otherReads=new();start(other,otherRoot,2)
eq(other.run.neowHistorySource,'fresh-start');eq(otherReads(),0)
finishMini(other,otherRoot)
local first=F.Nodes.available(other.run,other.map)[1];assert(other.mapUI:choose(first.id));eq(other.run.floor,1)
die(other);start(other,otherRoot,2);eq(other.run.neowHistorySource,'session-completed-run')
print('NEOW_COMPETITION_RESTART_PASS first2 boss4 newHost2 earlyDeath2; controlled prefix, real Boss entry/death and generated controls')
