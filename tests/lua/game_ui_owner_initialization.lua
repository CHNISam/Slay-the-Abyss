local testStart=dofile('tests/lua/support/game_ui_fixture.lua').start
package.path='src/lua/?.lua;build/lua/?.lua;tests/lua/?.lua;'..package.path
local F=require('support.game_ui_fixture')
local Run,Map,C=require('abyss_run'),require('abyss_map'),require('abyss_combat')
local originalRun,originalMap=Run.new,Map.generate
local runs,maps=0,0
Run.new=function(...)runs=runs+1;return originalRun(...)end
Map.generate=function(...)maps=maps+1;return originalMap(...)end
local data=C.copy(F.Data);local first=F.fixture(data)
assert(runs==0 and maps==0,'menu constructed unused Run/Map owners')
assert(first.run==nil and first.map==nil and first.nodeUI.run==nil and first.mapUI.map==nil)
assert(first.mapUI.visible==false and first.nodeUI.visible==false)
assert(first:openExit());assert(first:closeExit());assert(runs==0 and maps==0)
first:resize(1280,720);assert(first:update(.05))
assert(first.mapUI:choose('not-bound')==false);assert(first.nodeUI:press('confirm')==false)
local mapController,nodeController=first.mapUI,first.nodeUI
-- Neither failed factory publishes a partial owner or consumes the replay seed.
Run.new=function()error('Run factory failure')end
assert(not pcall(testStart,first));assert(first.run==nil and first.map==nil and first.seed==1)
assert(first:closeCharacters())
Run.new=function(...)runs=runs+1;return originalRun(...)end
Map.generate=function()error('Map factory failure')end
assert(not pcall(testStart,first));assert(first.run==nil and first.map==nil and first.seed==1)
assert(first.mapUI==mapController and first.nodeUI==nodeController)
assert(first:closeCharacters())
Map.generate=function(...)maps=maps+1;return originalMap(...)end
-- Caller edits before Start are still observed; each successful Run detaches them.
data.rules.player.maxHp=91
assert(testStart(first));assert(first.run.hp==91 and first.run.maxHp==91);assert(first.nodeUI.run==first.run and first.mapUI.map==first.map)
assert(first.mapUI==mapController and first.nodeUI==nodeController)
local beforeRuns,beforeMaps=runs,maps;local second=F.fixture(data)
assert(runs==beforeRuns and maps==beforeMaps,'another menu allocated discarded owners')
assert(testStart(second));assert(runs==beforeRuns+1 and maps==beforeMaps+1);local a,b=first.run,second.run
assert(a~=b and a.data~=b.data and a.data~=data and b.data~=data)
assert(a.data.cards.cards~=b.data.cards.cards and a.data.rules~=b.data.rules)
a.data.rules.player.maxHp=99;assert(data.rules.player.maxHp==91 and b.data.rules.player.maxHp==91)
local function strike(bundle)for _,card in ipairs(bundle.cards.cards)do if card.id=='strike'then return card end end end
strike(a.data).effects[1].value=17;assert(strike(data).effects[1].value==6 and strike(b.data).effects[1].value==6)
assert(Run.startCombat(a,'cultist_solo'));assert(Run.startCombat(b,'cultist_solo'))
assert(a.combat~=b.combat and a.combat.player~=b.combat.player and a.combat.catalog.cards.strike~=b.combat.catalog.cards.strike)
a.combat.player.hp=1;assert(b.combat.player.hp==91 and data.rules.player.maxHp==91)
a.combat.catalog.cards.strike.effects[1].value=23;assert(b.combat.catalog.cards.strike.effects[1].value==6 and strike(data).effects[1].value==6)
local oldMap=first.map;local oldBattle=a.combat;a.phase='defeat';first:refresh()
Map.generate=function()error('restart Map factory failure')end
assert(not pcall(testStart,first));assert(first.run==a and first.map==oldMap and first.nodeUI.run==a and first.mapUI.map==oldMap)
assert(first:closeCharacters())
Map.generate=function(...)maps=maps+1;return originalMap(...)end
assert(testStart(first));assert(first.run~=a and first.map~=oldMap and first.run.maxHp==91)
assert(a.combat==oldBattle and oldBattle.player.hp==1 and oldBattle.catalog.cards.strike.effects[1].value==23)
Run.new,Map.generate=originalRun,originalMap
print('GAME_UI_OWNER_INITIALIZATION_PASS no discarded menu owners; hidden unbound controllers; failed Run/Map retry; caller/two Run/two battle isolation')
