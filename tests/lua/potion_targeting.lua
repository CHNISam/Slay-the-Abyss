local H = dofile('tests/lua/support/potion_gesture_fixture.lua')
local Combat, Run = H.F.Combat, H.Run
local test, finish = H.suite('LUA_POTION_TARGETING')
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
test('P01/P02 bottle first is read-only until second enemy confirmation',function()
    local h,u,p,e,t,d,deck,r,emit,tap=setup()
    local before=snapshot(h);tap(1)
    assert(equal(before,snapshot(h)),'selecting fire potion must not execute the transaction')
    assert(u.potionAim and not u.busy)
    assert(p:GetChild('notice').text:find('点击敌人',1,true))
    assert(p:GetChild('playArea'):GetChild('label').text:find('取消药水',1,true),'field caption must describe cancelling the active potion')
    t('enemy2',2);d();emit('enemy2','click',2)
    assert(h.run.combat.enemies[1].hp==before.battle.enemies[1].hp)
    assert(h.run.combat.enemies[2].hp==before.battle.enemies[2].hp-20)
    assert(h.run.potions[1]==nil and not u.potionAim)
end)
test('P03 repeated bottle and field cancel with no transaction',function()
    for _,outside in ipairs({false,true}) do
        local h,u,p,e,t,d,deck,r,emit,tap=setup();local before=snapshot(h)
        tap(1);if outside then t('playArea',2) else tap(2) end
        assert(not u.potionAim and equal(before,snapshot(h)))
    end
end)
test('P04 fire fixed damage ignores ordinary attack multipliers',function()
    local h,u,p,e,t,d,deck,r,emit,tap=setup()
    local b=h.run.combat;b.enemies[2].block=7
    Combat.addStatus(b.player,'strength',2);Combat.addStatus(b.player,'weak',2)
    Combat.addStatus(b.enemies[2],'vulnerable',2)
    local hp=b.enemies[2].hp;tap(1);t('enemy2',2);d()
    assert(b.enemies[2].block==0 and b.enemies[2].hp==hp-13)
end)
test('P05 actor replacement or death during confirmation never inherits a gesture',function()
    for _,replace in ipairs({true,false}) do
        local h,u,p,e,t,d,deck,r,emit,tap=setup();tap(1)
        emit('enemy2','down',2)
        if replace then h.run.combat.enemies[2]=Combat.copy(h.run.combat.enemies[2])
        else h.run.combat.enemies[2].hp=0 end
        u:render();emit('enemy2','up',2);emit('enemy2','click',2)
        assert(h.run.potions[1]=='fire_potion' and not u.potionAim)
        assert(p:GetChild('notice').text:find('取消',1,true))
    end
end)
test('P06/P07/P08 lifecycle boundaries expire aiming and old enemy tokens',function()
    for _,change in ipairs({'turn','battle','deck','status','resize','inactive','inventory','phase','potionPanel'}) do
        local h,u,p,e,t,d,deck,r,emit,tap=setup();tap(1);emit('enemy2','down',2)
        if change=='turn' then h.run.combat.turn=h.run.combat.turn+1
        elseif change=='battle' then h.run.combat=Combat.copy(h.run.combat)
        elseif change=='deck' then deck()
        elseif change=='status' then u:showStatus(0)
        elseif change=='resize' then h:resize(1600,900)
        elseif change=='inventory' then assert(Run.discardPotion(h.run,1));assert(Run.obtainPotion(h.run,'fire_potion'))
        elseif change=='phase' then h.run.phase='defeat'
        elseif change=='potionPanel' then assert(h:openPotions());assert(h:closePotions())
        else u:setActive(false);u:setActive(true) end
        u:render();emit('enemy2','up',2);emit('enemy2','click',2)
        assert(h.run.potions[1]=='fire_potion' and not u.potionAim,change)
    end
end)
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
test('S01/S02/S12 explicit help opens before use without changing rules state or target',function()
    for _,id in ipairs({'fire_potion','poison_potion','strength_potion','energy_potion'}) do
        local h,u,p,e,t,d,deck,r,emit,tap=setup({id});local before=snapshot(h);local target=u.target
        local help=p:GetChild('potionHelp'):GetChild('potionHelp1');assert(help,'visible potion explanation entry missing')
        for _,event in ipairs({'down','up','click'}) do help.listeners[event]({touchId=3}) end
        local info=p:GetChild('statusInfo');assert(info.visible)
        assert(info:GetChild('summary').text:find('尚未使用',1,true))
        if id=='poison_potion' then
            assert(info:GetChild('text1').text:find('不立即',1,true))
            assert(info:GetChild('text2').text:find('6',1,true) and info:GetChild('text2').text:find('回合开始',1,true))
            assert(info:GetChild('note2').text:find('格挡',1,true) and info:GetChild('note2').text:find('5',1,true))
        end
        u:render();assert(equal(before,snapshot(h)) and target==u.target and not u.potionAim)
    end
end)
test('S13 long press and release never use or arm a potion',function()
    for _,id in ipairs({'energy_potion','fire_potion'}) do
        local h,u,p,e,t,d,deck,r,emit,tap=setup({id});local before=snapshot(h)
        emit('potion1','down',9);h:update(0.4);emit('potion1','up',9);emit('potion1','click',9)
        assert(p:GetChild('statusInfo').visible and not u.potionAim and equal(before,snapshot(h)))
    end
end)
test('P12 all seven potions declare target policy without changing acquisition pools',function()
    local count={self=0,enemy_one=0}
    for _,item in ipairs(H.F.Data.potions.potions) do
        assert(count[item.targetPolicy]~=nil,'missing explicit targetPolicy: '..item.id)
        count[item.targetPolicy]=count[item.targetPolicy]+1
    end
    assert(count.self==5 and count.enemy_one==2)
end)
finish()
