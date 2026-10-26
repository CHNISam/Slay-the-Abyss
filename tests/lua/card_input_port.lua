local H = dofile('tests/lua/support/battle_gesture_fixture.lua')
local passed = 0
local function test(name, fn)
    fn(); passed = passed + 1; print('PASS source card input ' .. name)
end

test('card center follows pointer even when grabbed away from center', function()
    local _, _, panel, event = H.setup()
    local card = panel:GetChild('card1')
    event('card1', 'down', 7, card.x + 35, card.y + 20)
    event('card1', 'drag', 7, 75, 20)
    assert(card.x == 75 and card.y == 20, 'grab offset still displaces card center')
end)

test('source relative rise permits a low battlefield release', function()
    local host, _, _, event = H.setup()
    event('card1', 'down', 7, -60, -280)
    event('card1', 'drag', 7, 0, -175)
    event('dragLayer', 'up', 7, 0, -175)
    assert(host.run.combat.energy == 2 and host.run.combat.player.block == 5)
end)

test('release on empty ground retains target mode and later enemy click commits once', function()
    local host, ui, panel, event, tap, drain = H.setup({'strike'}, {'cultist', 'jaw_worm'})
    local battle, uid = host.run.combat, host.run.combat.hand[1].uid
    local hp = battle.enemies[2].hp
    event('card1', 'down', 7)
    event('card1', 'drag', 7, -285, 0)
    event('dragLayer', 'up', 7, -285, 0)
    event('card1', 'endDrag', 7, -285, 0)
    assert(ui.selected == uid and ui.carry and ui.carry.aiming, 'empty release discarded original target mode')
    assert(panel:GetChild('card1').x == 0, 'target card must dock in screen center')
    assert(battle.energy == 3 and #battle.hand == 1)
    tap('enemy2', 8); drain()
    event('card1', 'up', 7, -285, 0)
    assert(battle.energy == 2 and battle.enemies[2].hp == hp - 6 and ui.carry == nil)
end)

test('short out-of-zone drag enters click-drag but long drag returns card', function()
    for _, seconds in ipairs({0.1, 0.45}) do
        local host, ui, _, event, tap = H.setup()
        event('card1', 'down', 7)
        event('card1', 'drag', 7, 0, -240)
        host:update(seconds)
        event('dragLayer', 'up', 7, 0, -240)
        if seconds < 0.4 then
            assert(ui.carry and ui.selected, 'short release must retain click-drag control')
            tap('playArea', 8)
            assert(host.run.combat.energy == 2)
        else assert(ui.carry == nil and ui.selected == nil and host.run.combat.energy == 3) end
    end
end)

test('persistent target can be cancelled with same card and cannot cross turns', function()
    for _, cancel in ipairs({'same', 'turn'}) do
        local host, ui, _, event, tap = H.setup({'strike'})
        event('card1', 'down', 7); event('card1', 'drag', 7, -285, 0)
        event('dragLayer', 'up', 7, -285, 0)
        assert(ui.carry)
        if cancel == 'same' then tap('card1', 8)
        else host.run.combat.turn = host.run.combat.turn + 1; ui:render() end
        assert(ui.carry == nil and ui.selected == nil and host.run.combat.energy == 3)
    end
end)

test('released pointer moves the aim and pulling below the source floor cancels', function()
    local x, y = 355, 360
    local host, ui, panel, event = H.setup({'strike'}, nil, {position=function() return x,y end})
    event('card1', 'down', 7); event('card1', 'drag', 7, -285, 0)
    event('dragLayer', 'up', 7, -285, 0)
    local enemy = panel:GetChild('enemy1')
    x, y = enemy.x + 640, enemy.y + 360
    host:update(0.01)
    assert(panel:GetChild('dragLayer').visible and panel:GetChild('dragLayer'):GetChild('reticle').x == enemy.x)
    assert(not panel:GetChild('dragLayer'):GetChild('hit').visible, 'released aim must not block enemy clicks')
    x,y = 640, 10; host:update(0.01)
    assert(ui.carry == nil and ui.selected == nil and host.run.combat.energy == 3)
end)

test('touch follows the finger with original upward offset and touch drop line', function()
    local host, _, panel, event = H.setup(nil, nil, {touchScreen=function() return true end})
    event('card1', 'down', 7)
    event('card1', 'drag', 7, 40, -150)
    assert(panel:GetChild('card1').x == 40 and panel:GetChild('card1').y == 30)
    event('dragLayer', 'up', 7, 40, -150)
    assert(host.run.combat.energy == 3, 'touch uses 350 rather than PC 300 threshold')
end)

test('right click cancels held and released aim without spending or a late release', function()
    for _, released in ipairs({false,true}) do
        local host,ui,panel,event = H.setup({'strike'}, nil, {keyEvents={KeyboardSprintKeyDown='right'}})
        event('card1','down',7); event('card1','drag',7,-285,0)
        if released then event('dragLayer','up',7,-285,0) end
        assert(panel.keyListeners and panel.keyListeners.right and panel.keyListeners.right())
        event('card1','up',7,0,0);event('card1','click',7)
        assert(ui.carry == nil and ui.gesture == nil and ui.selected == nil and host.run.combat.energy == 3)
    end
end)

print('LUA_CARD_INPUT_PORT_PASS ' .. passed)
