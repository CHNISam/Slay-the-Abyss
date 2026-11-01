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
assert(mapControl('next').visible and mapControl('previous').visible)
assert(mapControl('focus')==nil,'retired recenter must have no hidden hit area')
usingController=false;ui:update(.01)
assert(not mapControl('next').visible and not mapControl('previous').visible)
assert(not mapControl('next'):GetChild('hit').visible and not mapControl('previous'):GetChild('hit').visible)
local map, floor, node = assert(ui.map), ui.run.floor, ui.mapUI.map.currentNodeId
assert(ui.mapUI:scrollBy(200) and ui.mapUI.scroll>0)
assert(root:GetChild('exitEntry'):GetChild('open'):GetChild('hit').click() and not ui.mapUI.visible)
assert(root:GetChild('runMenu'):GetChild('resume'):GetChild('hit').click() and ui.mapUI.visible)
ui:update(1)
assert(ui.mapUI.scroll==0,'PC menu return must actually return to current position')
assert(ui.map==map and ui.mapUI.map==map and ui.run.floor==floor and ui.mapUI.map.currentNodeId==node,
    'PC menu return must not navigate to a room or advance the floor')
usingController=true;ui:update(.01)
assert(mapControl('next').visible)
local nextHit=mapControl('next'):GetChild('hit')
api.setFocus(nextHit);ui:syncController();assert(nextHit.navigationListeners.confirm())
ui:update(1);assert(ui.mapUI.scroll>0)
assert(root:GetChild('exitEntry'):GetChild('open'):GetChild('hit').click() and not ui.mapUI.visible)
api.setFocus(root:GetChild('runMenu'):GetChild('resume'):GetChild('hit'));ui:syncController()
assert(focus.navigationListeners.confirm());ui:update(1)
assert(ui.mapUI.visible and ui.mapUI.scroll==0)
assert(ui.map==map and ui.run.floor==floor and ui.mapUI.map.currentNodeId==node)
assert(ui:openExit());exit:GetChild('help'):GetChild('hit').click()
assert(ui.controlsOpen and not ui.mapUI.navigationEnabled)
assert(ui:closeExit() and ui:closeExit() and ui.mapUI.navigationEnabled)
print('NATIVE_UI_PARITY_PASS')
