local F=dofile('tests/lua/support/game_ui_fixture.lua')
local function start(character)
 local root=F.Viewport.apply(F.control({children=F.Layout}),1280,720)
 local last={}
 local portraits={sync=function(_,mode,open,stopped,id,warm)last={mode=mode,id=id,warm=warm}end,battlePose=function()end}
 local ui=F.GameUI.new(root,F.Data,F.Presentation,'click',{seed=1,imageSource='static',color=function(...)return {...}end,portraits=portraits})
 assert(last.mode=='menu' and last.warm==true,'title did not request hidden selection preloading')
 assert(F.start(ui,character))
 if character=='ironclad'then assert(ui.run.character==nil,'must exercise the actual production default, not an explicit class fixture')end
 local first=assert(F.Nodes.available(ui.run,ui.map)[1]);assert(ui.mapUI:choose(first.id))
 assert(last.mode=='battle' and last.id==character and not last.warm,'portrait did not receive actual gameplay class '..character)
end
start('ironclad');start('silent')
print('DEFAULT_TRAVELER_PORTRAIT_PASS')
