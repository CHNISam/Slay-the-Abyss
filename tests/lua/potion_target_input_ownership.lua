local H = dofile('tests/lua/support/potion_gesture_fixture.lua')
local test, finish = H.suite('LUA_POTION_TARGET_INPUT_OWNERSHIP')
local function setup()
    local h,u,p,e,t,d,deck,r,emit,tap = H.setup({'bash','defend'}, {'cultist','jaw_worm'})
    assert(H.Run.discardPotion(h.run, 1))
    assert(H.Run.obtainPotion(h.run, 'fire_potion'))
    h:refresh()
    return h,u,t,d,emit,tap
end
for _,kind in ipairs({'up','endDrag'}) do
    test('orphan enemy '..kind..' cannot enable click-only potion confirmation', function()
        local h,u,t,d,emit,tap = setup()
        tap(7)
        local hp = h.run.combat.enemies[2].hp
        emit('enemy2',kind,8); emit('enemy2','click',8)
        assert(h.run.potions[1]=='fire_potion', 'orphan release consumed potion')
        assert(h.run.combat.enemies[2].hp==hp, 'orphan release damaged enemy')
        if not u.potionAim then tap(9) end
        t('enemy2',10); d()
        assert(h.run.potions[1]==nil and h.run.combat.enemies[2].hp==hp-20)
    end)
end
for _,release in ipairs({false,true}) do
    test('end-turn '..(release and 'release' or 'press')..' predating aim cannot end turn', function()
        local h,u,t,d,emit,tap = setup()
        emit('endTurn','down',6)
        if release then emit('endTurn','up',6) end
        tap(7)
        local aim,turn = u.potionAim,h.run.combat.turn
        assert(aim, 'potion must be armed first')
        if not release then emit('endTurn','up',6) end
        emit('endTurn','click',6)
        assert(h.run.combat.turn==turn, 'old action advanced turn through newer aim')
        assert(u.potionAim==aim and h.run.potions[1]=='fire_potion')
        t('enemy2',8); d(); assert(h.run.potions[1]==nil)
    end)
end
test('new end-turn gesture after aiming is still a valid action', function()
    local h,u,t,d,emit,tap = setup()
    tap(7); local turn=h.run.combat.turn
    t('endTurn',8); d()
    assert(h.run.combat.turn==turn+1 and not u.potionAim)
    assert(h.run.potions[1]=='fire_potion')
end)
test('genuinely click-only enemy retains its independent fallback', function()
    local h,u,t,d,emit,tap = setup()
    tap(7); local hp=h.run.combat.enemies[2].hp
    emit('enemy2','click',8); d()
    assert(h.run.potions[1]==nil and h.run.combat.enemies[2].hp==hp-20)
end)
test('enemy Down Click without Up keeps its supported ownership', function()
    local h,u,t,d,emit,tap = setup()
    tap(7); local hp=h.run.combat.enemies[2].hp
    emit('enemy2','down',8); emit('enemy2','click',8); d()
    assert(h.run.potions[1]==nil and h.run.combat.enemies[2].hp==hp-20)
end)
finish()
