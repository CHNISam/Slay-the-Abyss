-- Research pack POTION cancellation contract, exercised through production host listeners.
local H = dofile('tests/lua/support/potion_gesture_fixture.lua')
local Run, Combat = H.Run, H.F.Combat
local test, finish = H.suite('LUA_POTION_TARGET_REJECTION')
local function setup()
    local h,u,p,e,t,d,deck,r,emit,tap = H.setup({'bash','defend'}, {'cultist','jaw_worm'})
    assert(Run.discardPotion(h.run,1))
    assert(Run.obtainPotion(h.run,'fire_potion'))
    h:refresh()
    return h,u,t,d,emit,tap,p
end
local function snapshot(run)
    -- Include rewards, inventory, event log, deck and every RNG, not just HP/bottle count.
    local state = {}
    for k,v in pairs(run) do if k ~= 'data' and k ~= 'elapsedSeconds' then state[k] = v end end
    return Combat.copy(state)
end
local function equal(a,b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= 'table' then return a == b end
    for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end
for _,change in ipairs({'dead','replaced','reordered','refilled','turn','phase'}) do
    test('old enemy confirmation is atomic without a render after '..change, function()
        local h,u,t,d,emit,tap = setup()
        tap(1); assert(u.potionAim)
        emit('enemy2','down',2); emit('enemy2','up',2)
        local b = h.run.combat
        if change == 'dead' then b.enemies[2].hp = 0
        elseif change == 'replaced' then b.enemies[2] = Combat.copy(b.enemies[2])
        elseif change == 'reordered' then b.enemies[1],b.enemies[2] = b.enemies[2],b.enemies[1]
        elseif change == 'refilled' then
            assert(Run.discardPotion(h.run,1)); assert(Run.obtainPotion(h.run,'fire_potion'))
        elseif change == 'turn' then b.turn = b.turn+1
        else h.run.phase = 'map' end
        local before = snapshot(h.run)
        -- No refresh/render/update is allowed between the state change and stale Click.
        emit('enemy2','click',2)
        assert(equal(before,snapshot(h.run)), 'stale confirmation mutated run after '..change)
        assert(not u.busy, 'rejected input started presentation')
    end)
end
test('cancel then fresh aim cannot inherit the old released enemy confirmation', function()
    local h,u,t,d,emit,tap,p = setup()
    tap(1); emit('enemy2','down',2); emit('enemy2','up',2)
    tap(3); assert(not u.potionAim and u.potionMenu,'cancel must leave the real menu owner')
    H.confirm(u,p,4); assert(u.potionAim)
    local before = snapshot(h.run)
    emit('enemy2','click',2)
    assert(equal(before,snapshot(h.run)), 'old target confirmation crossed a cancel/rearm boundary')
    -- Rejection must not break a subsequent fresh gesture on the intended non-first enemy.
    t('enemy2',5); d()
    assert(h.run.potions[1] == nil)
    assert(h.run.combat.enemies[1].hp == before.combat.enemies[1].hp)
    assert(h.run.combat.enemies[2].hp < before.combat.enemies[2].hp)
end)
finish()
