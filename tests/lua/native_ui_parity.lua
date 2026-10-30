local F = dofile('tests/lua/support/game_ui_fixture.lua')
local focus, usingController = nil, true
local api = {events={Confirm='confirm',Cancel='cancel'},directions={Left='left',Right='right'},modes={Specified='specified'},
    getFocus=function()return focus end,setFocus=function(c)focus=c end,isController=function()return usingController end}
local calls=0
local ui,root=F.fixture(nil,function()calls=calls+1;return true end,nil,nil,false,nil,nil,api)
local exit=root:GetChild('exitPanel')
assert(ui:openExit())
exit:GetChild('help'):GetChild('hit').click()
assert(ui.controlsOpen and ui.exitOpen and exit:GetChild('guide').visible)
assert(not ui:confirmExit() and not ui:start() and calls==0)
assert(not exit:GetChild('confirm'):GetChild('hit').click())
ui:syncController()
assert(focus==exit:GetChild('guide'):GetChild('close'):GetChild('hit'))
assert(focus.navigationListeners.cancel())
assert(not ui.controlsOpen and ui.exitOpen and not exit:GetChild('guide').visible)
assert(ui:closeExit() and not ui.exitOpen and calls==0)
if ui:openMenu() then
    assert(not root:GetChild('runMenu'):GetChild('map').visible,'no grey map promise before departure')
    assert(ui:closeExit() and not ui.exitOpen)
end
assert(ui:start())
if ui.characterOpen then
    assert(ui:selectCharacter('traveler') and ui:selectElement('ironclad'))
    assert(not ui.run and ui:confirmCharacter())
    ui:update(1)
end
local function mapControl(name)
    local panel=root:GetChild('mapPanel')
    for _,group in pairs(panel.children)do if group.children[name]then return group.children[name]end end
end
assert(mapControl('next').visible and mapControl('focus').visible)
usingController=false;ui:update(.01)
assert(not mapControl('next').visible and not mapControl('focus').visible)
usingController=true;ui:update(.01)
assert(mapControl('next').visible)
local nextHit=mapControl('next'):GetChild('hit')
api.setFocus(nextHit);ui:syncController();assert(nextHit.navigationListeners.confirm())
ui:update(1);assert(ui.mapUI.scroll>0)
ui:update(.01);api.setFocus(mapControl('focus'):GetChild('hit'))
assert(focus.navigationListeners.confirm());ui:update(1);assert(ui.mapUI.scroll==0)
assert(ui:openExit());exit:GetChild('help'):GetChild('hit').click()
assert(ui.controlsOpen and not ui.mapUI.navigationEnabled)
assert(ui:closeExit() and ui:closeExit() and ui.mapUI.navigationEnabled)
-- TASK-4.16: tapping outside the run menu resumes; tapping the panel itself does not;
-- the guide's outside tap returns to the menu; never abandons or settles.
local runMenu=root:GetChild('runMenu')
assert(ui:openMenu() and runMenu.visible and ui.menuOpen)
assert(runMenu:GetChild('map').visible,'map entry shown once departed')
assert(runMenu:GetChild('catch').click() and ui.exitOpen and ui.menuOpen)
assert(runMenu:GetChild('blocker').click() and not ui.exitOpen and not ui.menuOpen and calls==0 and ui.run)
assert(ui:openMenu());runMenu:GetChild('help'):GetChild('hit').click()
local guide=exit:GetChild('guide')
assert(ui.controlsOpen and guide.visible)
assert(guide:GetChild('catch').click() and ui.controlsOpen)
assert(guide:GetChild('blocker').click() and not ui.controlsOpen and ui.menuOpen and ui.exitOpen and calls==0)
assert(runMenu:GetChild('blocker').click() and not ui.exitOpen and calls==0 and ui.run)
print('NATIVE_UI_PARITY_PASS')
