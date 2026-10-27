-- Real Host and Nodes entry; controlled terminal boundaries are NOT natural
-- playthrough evidence. No key flags or permanent victory history are injected.
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Map=require('abyss_map')
local Run=require('abyss_run')
local count=0
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function test(name,fn)fn();count=count+1;print('PASS ending host '..count..' '..name)end
local function fixture(options)
 local root=F.Viewport.apply(F.control({children=F.Layout}),1280,720)
 options.imageSource,options.prologue,options.campaign='static',false,true
 options.color=function(r,g,b,a)return{r=r,g=g,b=b,a=a}end
 options.newSeed=options.newSeed or function()return'42'end
 local ui=F.GameUI.new(root,F.Data,F.Presentation,'click',options);root.ui=ui
 return ui
end
local function terminal(ui)
 local run,map=ui.run,ui.map
 run.act=3 -- controlled chapter boundary; freeze its real birth before canonical generation.
 local third=Map.generate(run.data,run.runSeed,3,assert(Run.freezeMapContext(run)))
 for k in pairs(map)do map[k]=nil end;for k,v in pairs(third)do map[k]=v end
 while Map.available(map)[1].floor<51 do assert(Map.choose(map,Map.available(map)[1].id))end
 run.act,run.floor,run.phase=3,50,'map';run.encounterTier,run.encounterId='boss','controlled_third_boss'
 run.lastResult={outcome='victory',encounterId=run.encounterId}
 run.nodeFlow={id=map.currentNodeId,floor=50,type='boss',complete=true,result='boss_victory',
  mapSeed=map.seed,mapSignature=map.sourceSignature}
 assert(F.Nodes.enter(run,map,Map.available(map)[1].id));eq(run.phase,'victory');eq(run.floor,51)
end
test('Host reads qualification before first map generation and missing provider remains unknown',function()
 local calls={};local generate=Map.generate
 local ui=fixture({readEndingHistory=function()calls[#calls+1]='history';return{version=1,wins={ironclad=true,silent=true,defect=true}}end})
 Map.generate=function(...)calls[#calls+1]='map';assert(calls[1]=='history','ENDING_HISTORY_BEFORE_MAP');return generate(...)end
 local ok,why=pcall(function()assert(ui:start())end);Map.generate=generate;assert(ok,why)
 eq(calls[1],'history');eq(calls[2],'map');eq(ui.run.endingUnlocked,true)
 local unknown=fixture({});assert(unknown:start());eq(unknown.run.endingUnlocked,false)
 eq(unknown.run.endingHistory.known,false)
end)
test('Host records actual normal-ending command once and only a later run receives new qualification',function()
 local writes=0;local persisted={version=1,wins={ironclad=false,silent=true,defect=true}}
 local ui=fixture({readEndingHistory=function()return persisted end,writeEndingHistory=function(delta)
  writes=writes+1;eq(delta.version,1);eq(delta.wins.ironclad,true)
  eq(delta.wins.silent,nil);eq(delta.wins.defect,nil);return false
 end})
 assert(ui:start());local ended=ui.run;eq(ended.endingUnlocked,false)
 terminal(ui);ui:refresh();eq(writes,1);eq(ended.endingUnlocked,false)
 eq(ended.endingHistoryResult.persistence,'write_failed');eq(ended.endingHistoryResult.wins.ironclad,true)
 ui:refresh();ui:refresh();eq(writes,1)
 assert(ui:start());assert(ui.run~=ended);eq(ui.run.endingUnlocked,true);eq(writes,1)
 eq(persisted.wins.ironclad,false,'provider readback must stay detached')
end)
test('Host locks explicit replay seed into the origin rather than trusting mutable rule state',function()
 local writes=0;local ui=fixture({seed=42,readEndingHistory=function()
  return{version=1,wins={ironclad=false,silent=true,defect=true}}
 end,writeEndingHistory=function()writes=writes+1;return true end})
 assert(ui:start());terminal(ui);ui.run.seedSet=false;ui:refresh();eq(writes,0)
 assert(ui:start());eq(ui.run.endingUnlocked,false);eq(writes,0)
end)
print('ENDING_HISTORY_HOST '..count..' passed')
