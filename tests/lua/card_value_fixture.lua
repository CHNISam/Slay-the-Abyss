package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local view,root=F.fixture()
local update=dofile('tools/card-value-feedback/fixture.lua').start(view)
for index=1,8 do
    update(index==1 and 0 or 7)
    assert(view.run.phase=='combat')
    local panel=root:GetChild('battlePanel')
    assert(panel.visible)
    local seen={}
    for i,instance in ipairs(view.run.combat.hand) do
        local box=panel:GetChild('card'..i)
        seen[instance.cardId]=box
    end
    if index==2 then assert(seen.defend:GetChild('valueFeedback'):GetChild('value1').text=='3↓') end
    if index==3 then assert(seen.defend:GetChild('valueFeedback'):GetChild('value1').text=='8↑') end
    if index==4 then assert(seen.strike:GetChild('valueFeedback'):GetChild('value1').text=='4↓') end
    if index==5 then assert(seen.strike:GetChild('valueFeedback'):GetChild('value1').text=='9↑') end
    if index==6 then assert(not seen.strike:GetChild('valueFeedback').visible) end
    if index==8 then assert(#view.run.combat.hand==10) end
end
print('LUA_CARD_VALUE_FIXTURE_PASS 8')
