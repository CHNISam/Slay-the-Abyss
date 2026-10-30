local F=dofile('tests/lua/support/game_ui_fixture.lua')
local calls=0
local ui,root=F.fixture(nil,function(victory)assert(victory==false);calls=calls+1;return true end)
local function click(panel,name)
 local box=root:GetChild(panel):GetChild(name)
 assert(box.visible and root:GetChild(panel).visible,'exit action is hidden')
 return box:GetChild('hit').click()
end
assert(ui:start() and ui.characterOpen and ui.run==nil)
assert(ui:selectCharacter('traveler') and ui:selectElement('ironclad'))
local selection=ui.characterSelection.info
assert(click('exitEntry','open') and click('runMenu','abandon'))
assert(click('exitPanel','cancel'),'selection input guard blocked exit cancellation')
assert(ui.characterOpen and ui.characterSelection.info==selection and calls==0 and ui.run==nil)
assert(click('exitEntry','open') and click('runMenu','abandon'))
assert(click('exitPanel','confirm'),'selection input guard blocked exit confirmation')
assert(calls==1 and ui.settlementRequested and ui.run==nil)
assert(not ui:confirmExit() and calls==1,'duplicate settlement request')
print('CHARACTER_SELECTION_EXIT_PASS')
