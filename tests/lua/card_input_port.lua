local H = dofile('tests/lua/support/battle_gesture_fixture.lua')
local passed, failed = 0, 0
local function test(name, fn)
    local ok,why=pcall(fn)
    if ok then passed=passed+1; print('PASS source card input '..name)
    else failed=failed+1; print('FAIL source card input '..name..': '..tostring(why)) end
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

test('native targeting keeps the whole card and its description in the safe canvas', function()
    local Theme=require('abyss_theme')
    local _,_,panel,event=H.setup({'dropkick'})
    event('card1','down',7);event('card1','drag',7,-285,0)
    local card=panel:GetChild('card1')
    assert(card.y-Theme.layout.card.size[2]*card.scale[2]/2>=-360+Theme.canvas.safe.y,
        'docked description falls below the safe canvas')
end)

test('resize immediately redraws a released aim and removes its overlay', function()
    local host,ui,panel,event=H.setup({'strike'})
    event('card1','down',7);event('card1','drag',7,-285,0);event('dragLayer','up',7,-285,0)
    assert(ui.carry and panel:GetChild('dragLayer').visible)
    host:resize(1600,900);host:update(0.01)
    assert(ui.carry==nil and ui.selected==nil and not panel:GetChild('dragLayer').visible,
        'resize left the released targeting overlay visible')
end)

test('combat hover lifts the real card and clears after exit or a changed hand', function()
    local host,ui,panel,event=H.setup()
    local card=panel:GetChild('card1')
    local y=card.y
    event('card1','enter',7)
    assert(ui.hover==1 and card.y>y and card.raised,'combat render erased hand hover')
    event('card1','exit',7)
    assert(ui.hover==nil and card.y==y)
    event('card1','enter',7)
    table.remove(host.run.combat.hand,1);ui:render()
    assert(ui.hover==nil,'hover transferred to a new card in the same slot')
end)

test('combat hover keeps the hit rectangle fixed for one, five and ten card hands', function()
    local function hitBounds(card)
        local hit=card:GetChild('hit')
        local a=(card.localRotationZ or 0)*math.pi/180
        local z=a+(hit.localRotationZ or 0)*math.pi/180
        local s=card.localScaleX or 1
        local dx,dy=(hit.x or 0)*s,(hit.y or 0)*s
        local x,y=card.x+math.cos(a)*dx-math.sin(a)*dy,card.y+math.sin(a)*dx+math.cos(a)*dy
        local w=hit.sizeDeltaX*s*(hit.localScaleX or 1)/2
        local h=hit.sizeDeltaY*s*(hit.localScaleY or 1)/2
        local rx,ry=math.abs(math.cos(z))*w+math.abs(math.sin(z))*h,math.abs(math.sin(z))*w+math.abs(math.cos(z))*h
        return {x-rx,x+rx,y-ry,y+ry}
    end
    for _,count in ipairs({1,5,10}) do
        local deck={};for i=1,count do deck[i]='defend' end
        local host,ui,panel,event=H.setup(deck)
        H.F.Combat.draw(host.run.combat,count)
        assert(#host.run.combat.hand==count)
        host:refresh()
        for i=1,count do
            local name='card'..i
            local card=panel:GetChild(name)
            local before=hitBounds(card)
            event(name,'enter',7)
            local after=hitBounds(card)
            for edge=1,4 do assert(math.abs(before[edge]-after[edge])<0.000001,'hover moved its pointer hit rectangle') end
            assert(card.y-card.sizeDeltaY*card.localScaleY/2>=before[3]-0.000001)
            assert(card.y+card.sizeDeltaY*card.localScaleY/2<=before[4]+0.000001)
            event(name,'exit',7)
        end
        host.run.phase='reward'
        host.run.rewards={gold=0,goldClaimed=true,cards={'defend'},cardResolved=false,manualContinue=true}
        host:refresh();ui.rewardScreen='cards';ui:render()
        local hit=panel:GetChild('card1'):GetChild('hit')
        assert(hit.x==0 and hit.y==0 and hit.localRotationZ==0 and hit.localScaleX==1,
            'reward card inherited the inverse hand-hit transform')
    end
end)

print('LUA_CARD_INPUT_PORT_PASS ' .. passed)
assert(failed==0,'source input failures: '..failed)
