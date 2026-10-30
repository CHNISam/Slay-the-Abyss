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
    if index==2 then assert(seen.defend:GetChild('label').text:find('<color=#EF7672>3↓</color>',1,true)) end
    if index==3 then assert(seen.defend:GetChild('label').text:find('<color=#7DC77A>8↑</color>',1,true)) end
    if index==4 then assert(seen.strike:GetChild('label').text:find('<color=#EF7672>4↓</color>',1,true)) end
    if index==5 then
        assert(seen.strike:GetChild('label').text:find('<color=#7DC77A>9↑</color>',1,true))
        local battle,ui=view.run.combat,view.battleUI
        local target=assert(require('abyss_monster_surfaces').get(panel):find(battle.enemies[2].id))
        assert(panel:GetChild('enemy2')==nil,'aim must use a dynamic actor, not a static slot')
        local hit=target:GetChild('hit')
        assert(ui.gesture.x==target.x+hit.x and ui.gesture.y==target.y+hit.y,'aim must follow the second actor hitbox')
        assert(ui.gesture.drawnTarget==2 and ui.gesture.drawnValid,'preview must target the vulnerable second enemy')
        local hp,energy=battle.enemies[2].hp,battle.energy
        ui:render()
        assert(battle.enemies[2].hp==hp and battle.energy==energy,'preview must not apply damage or spend energy')
        assert(battle.enemies[2].statuses.vulnerable==1 and next(battle.player.statuses)==nil)
        assert(seen.strike:GetChild('label').text:find('<color=#7DC77A>9↑</color>',1,true))
    end
    if index==6 then assert(not seen.strike:GetChild('label').text:find('<color=',1,true)) end
    if index==8 then assert(#view.run.combat.hand==10) end
end
print('LUA_CARD_VALUE_FIXTURE_PASS 8')
