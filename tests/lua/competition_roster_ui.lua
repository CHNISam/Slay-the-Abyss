local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Select=require('abyss_character_select')
local focus
local api={events={Confirm='confirm',Cancel='cancel',Focus='focus'},directions={Left='left',Right='right'},
 modes={Specified='specified'},getFocus=function()return focus end,setFocus=function(c)focus=c end,isController=function()return true end}
local canvas=F.control({children=F.Layout})
local root=F.Viewport.apply(canvas,1280,720)
local seeds=0
local cursor={CursorDown='down',CursorUp='up',CursorExit='exit',CursorEndDrag='enddrag'}
local ui=F.GameUI.new(root,F.Data,F.Presentation,'click',{campaign=true,campaignProfile='competition-two-act',
 imageSource='static',color=function(r,g,b,a)return {r=r,g=g,b=b,a=a}end,
 controllerApi=api,cursorEvents=cursor,newSeed=function()seeds=seeds+1;return 3 end})
local function hit(name)return root:GetChild('characterPanel'):GetChild(name):GetChild('hit')end
assert(ui:start()and not ui.run and not ui.map)
local panel=root:GetChild('characterPanel')
for i=1,3 do
 local control=hit('character'..i)
 assert(not panel:GetChild('character'..i).visible and not control.canControllerFocus)
 assert(not control.click()and not control.navigationListeners.confirm())
end
assert(panel:GetChild('character4').visible and panel:GetChild('traveler').visible)
assert(hit('character4').canControllerFocus and hit('traveler').canControllerFocus)
assert(hit('character4').navigation.right.target==hit('traveler'))
assert(hit('traveler').navigation.right.target==hit('character4'))
for _,id in ipairs({'hutao','arlecchino','furina'})do assert(not ui:selectCharacter(id))end
assert(ui:selectCharacter('traveler')and ui.characterSelection.info.id=='ironclad')
for i,id in ipairs(Select.elements)do
 local box=panel:GetChild('elements'):GetChild('element'..i)
 if i==1 then assert(box.visible)else
  assert(not box.visible and not box:GetChild('hit').canControllerFocus)
  assert(not box:GetChild('hit').click()and not ui:selectElement(id))
 end
end
assert(ui.characterSelection.info.id=='ironclad'and seeds==0 and not ui.run)
-- A stale/corrupt info object must be refused before sampling a new seed.
local valid=ui.characterSelection.info
ui.characterSelection.info={id='silent'}
assert(not ui:confirmCharacter()and seeds==0 and not ui.run)
ui.characterSelection.info=valid
local confirm=hit('confirm')
confirm.listeners.down({touchId=1});assert(ui:selectCharacter('raiden'))
confirm.listeners.up({touchId=1});assert(not confirm.click({touchId=1})and seeds==0)
confirm.listeners.down({touchId=2});ui:resize(1600,900)
confirm.listeners.up({touchId=2});assert(not confirm.click({touchId=2})and seeds==0)
assert(ui:closeCharacters()and ui.characterSelection.info==nil)
assert(ui:start()and ui:selectCharacter('raiden'))
assert(ui:confirmCharacter()and seeds==1 and ui.run.character=='raiden'and ui.run.characterProfile.role=='RD')
assert(not ui:confirmCharacter()and seeds==1)
-- Host configuration can carry a prepared identity even when the nominal
-- selection is Geo. Refuse before sampling a seed, not by throwing from Run.
local prepared=require('abyss_run_card_catalog').prepareSelected(F.Data,'silent')
local blockedRoot=F.Viewport.apply(F.control({children=F.Layout}),1280,720)
local samples=0
local blocked=F.GameUI.new(blockedRoot,prepared,F.Presentation,'click',{
 campaign=true,campaignProfile='competition-two-act',imageSource='static',
 color=function(r,g,b,a)return {r=r,g=g,b=b,a=a}end,newSeed=function()samples=samples+1;return 3 end})
assert(blocked:start()and blocked:selectCharacter('traveler'))
local called,accepted,why=pcall(blocked.confirmCharacter,blocked)
assert(called and not accepted and why=='competition_character_unavailable'and samples==0 and not blocked.run,
 'configured-source denial sampled seed or escaped as a runtime error: '..tostring(samples)..'/'..tostring(accepted))
print('COMPETITION_ROSTER_UI_PASS native controls/direct config/controller/stale confirm; native/natural NOT_RUN')
