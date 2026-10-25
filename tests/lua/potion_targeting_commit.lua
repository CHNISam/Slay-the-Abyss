local H = dofile('tests/lua/support/potion_gesture_fixture.lua')
local Combat, Run = H.F.Combat, H.Run
local test, finish = H.suite('LUA_POTION_TARGETING_COMMIT')
local function setup(ids, enemies)
    local h,u,p,e,t,d,deck,r,emit,tap=H.setup({'bash','defend'},enemies or {'cultist','jaw_worm'})
    h.run.potions={}
    for slot,id in pairs(ids or {'fire_potion'}) do h.run.potions[slot]=id end
    h:refresh()
    return h,u,p,e,t,d,deck,r,emit,tap
end
local function snapshot(h)
    local battle={}
    for k,v in pairs(h.run.combat) do if k~='catalog' and k~='rules' then battle[k]=v end end
    local run={}
    for k,v in pairs(h.run) do if k~='data' and k~='combat' and k~='elapsedSeconds' then run[k]=v end end
    return Combat.copy({battle=battle,run=run})
end
local function equal(a,b)
    if type(a)~='table' then return a==b end
    if type(b)~='table' then return false end
    for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
end
test('P08 enemy EndDrag cancels rather than submits',function()
    local h,u,p,e,t,d,deck,r,emit,tap=setup();tap(1)
    emit('enemy2','down',2);emit('enemy2','endDrag',2);emit('enemy2','click',2)
    assert(h.run.potions[1]=='fire_potion' and not u.potionAim)
end)

test('P09/P11 sparse slot3 selects enemy3 with no default even for one enemy',function()
    for _,enemies in ipairs({{'cultist'},{'cultist','jaw_worm','cultist'},{'cultist','jaw_worm','cultist','jaw_worm','cultist'}}) do
        local h,u,p,e,t,d,deck,r,emit,tap=setup({[3]='fire_potion'},enemies)
        local b=h.run.combat;local index=math.min(3,#enemies);local hp=b.enemies[index].hp
        tap(1,3);assert(h.run.potions[3]=='fire_potion')
        t('enemy'..index,2);d()
        assert(b.enemies[index].hp==hp-20 and Run.potionCount(h.run)==0)
    end
end)

test('P10 self potions still commit without enemy selection',function()
    for _,id in ipairs({'block_potion','energy_potion','strength_potion','dexterity_potion','regen_potion'}) do
        local h,u,p,e,t,d,deck,r,emit,tap=setup({id});local hp=h.run.combat.enemies[1].hp
        tap(1);d();assert(not u.potionAim and Run.potionCount(h.run)==0 and h.run.combat.enemies[1].hp==hp,id)
    end
end)

test('P13 Artifact blocks poison application but successful use consumes bottle',function()
    local h,u,p,e,t,d,deck,r,emit,tap=setup({'poison_potion'})
    local b=h.run.combat;Combat.addStatus(b.enemies[2],'artifact',1)
    tap(1);assert(h.run.potions[1]=='poison_potion');t('enemy2',2);d()
    assert((b.enemies[2].statuses.poison or 0)==0 and (b.enemies[2].statuses.artifact or 0)==0 and Run.potionCount(h.run)==0)
end)
finish()
