local monsterControl=dofile('tests/lua/support/monster_control_fixture.lua')
local H = dofile('tests/lua/support/battle_gesture_fixture.lua')
local Combat, Run = H.F.Combat, H.Run
local Actor = require('abyss_actor')
local Presentation = require('abyss_presentation')
local count=0
local function test(name,fn) fn();count=count+1;print('PASS '..name) end
test('S03/S04 poison 6 loses 6..1 HP across six owner turns, bypassing retained block and attack modifiers',function()
    local s=Combat.new(H.F.Data,{deck={'defend'},enemies={'cultist'}})
    local e=s.enemies[1];e.hp,e.maxHp,e.block=100,100,10
    for id,n in pairs({poison=6,barricade=1,weak=2,vulnerable=2}) do Combat.addStatus(e,id,n) end
    for n=6,1,-1 do local hp=e.hp;Actor.startTurn(s,e);assert(e.hp==hp-n and e.block==10 and e.statuses.poison==n-1) end
    assert(e.hp==79)
end)
test('S05 poison stacks before the next owner turn without immediate HP loss',function()
    local h,u,p=H.setup({'defend'},{'cultist','jaw_worm'})
    local s=h.run.combat;local hp=s.enemies[2].hp
    Combat.addStatus(s.enemies[2],'poison',4);assert(Run.obtainPotion(h.run,'poison_potion'))
    assert(Run.usePotion(h.run,1,2));assert(s.enemies[2].hp==hp and s.enemies[2].statuses.poison==10)
end)
test('S06 weak2 and vulnerable2 change duration rather than percentage stacking',function()
    local s=Combat.new(H.F.Data,{deck={'defend'},enemies={'cultist'}})
    Combat.addStatus(s.player,'weak',2);local hp=s.enemies[1].hp
    Combat.damage(s,s.player,s.enemies[1],8);assert(s.enemies[1].hp==hp-6)
    s.player.statuses.weak=0;Combat.addStatus(s.enemies[1],'vulnerable',2);hp=s.enemies[1].hp
    Combat.damage(s,s.player,s.enemies[1],8);assert(s.enemies[1].hp==hp-12)
end)
test('S09/S10 frail applies to card block, dexterity precedes percentage, fixed bottle stays12',function()
    for _,dex in ipairs({0,2}) do
        local h,u,p=H.setup({'defend'},{'cultist'})
        local s=h.run.combat;Combat.addStatus(s.player,'frail',1)
        if dex>0 then Combat.addStatus(s.player,'dexterity',dex) end
        Combat.block(s,s.player,5);assert(s.player.block==(dex==0 and 3 or 5))
        s.player.block=0;assert(Run.obtainPotion(h.run,'block_potion'));assert(Run.usePotion(h.run,1));assert(s.player.block==12)
    end
end)
test('P12 thrown group policy does not request a single enemy or enter production data',function()
    local source=Combat.copy(H.F.Data)
    for _,item in ipairs(source.potions.potions) do
        if item.id=='fire_potion' then item.targetPolicy='enemy_all';item.isThrown=true end
    end
    local run=Run.new(source,1);assert(Run.startCombat(run,'cultist_solo'));assert(Run.obtainPotion(run,'fire_potion'))
    assert(not Run.potionView(run)[1].needTarget,'throwing must not imply selecting one enemy')
    local original,modified
    for _,item in ipairs(H.F.Data.potions.potions) do if item.id=='fire_potion' then original=item end end
    for _,item in ipairs(source.potions.potions) do if item.id=='fire_potion' then modified=item end end
    assert(original and original.targetPolicy=='enemy_one')
    assert(modified and modified.targetPolicy=='enemy_all')
end)
test('S07 duration intent says turns before it is applied',function()
    local h,u,p=H.setup({'bash'},{'cultist'})
    local s=h.run.combat;s.enemies[1].ai=nil;s.enemies[1].intentIndex=1
    -- Synthetic effect wording keeps a legal selected source move identity.
    s.enemies[1].intents={{id='cultist_2',kind='debuff',effects={{op='applyStatus',status='weak',value=2}}}}
    u:render();monsterControl(p,'enemy1'):GetChild('intentHit').click()
    assert(p:GetChild('statusInfo'):GetChild('text1').text:find('2 回合虚弱',1,true),'duration must not be described as intensity')
    assert((s.player.statuses.weak or 0)==0)
end)
test('S08 current poison detail updates amount and next tick without a stale value',function()
    local h,u,p=H.setup({'defend'},{'cultist'})
    local s=h.run.combat;Combat.addStatus(s.enemies[1],'poison',6);u:showStatus(1)
    local info=p:GetChild('statusInfo');assert(info:GetChild('text2').text:find('6 点生命',1,true))
    Actor.startTurn(s,s.enemies[1]);u:render()
    assert(info:GetChild('text2').text:find('5 点生命',1,true) and info:GetChild('note2').text:find('4 层',1,true))
end)
test('S07 card keywords retain battle-long versus temporary duration before play',function()
    local h,u,p=H.setup({'inflame','flex'},{'cultist'})
    for slot,instance in ipairs(h.run.combat.hand) do
        u:openHelp(u:cardHelpSpec(slot),nil,false)
        local tag=p:GetChild('statusInfo'):GetChild('tag1').text
        assert(tag==(instance.cardId=='flex' and '本回合' or '本场战斗'),'keyword duration missing: '..instance.cardId)
    end
end)
test('S07 basic and upgraded printed cards name duration in turns, never intensity layers',function()
    for _,id in ipairs({'bash','clothesline','thunderclap','uppercut','shockwave'}) do
        for _,key in ipairs({'text','upgradeText'}) do
            local text=assert(Presentation[id][key])
            assert(text:find('回合',1,true) and not text:find('层易伤',1,true) and not text:find('层虚弱',1,true),id..'/'..key..' must explain duration')
        end
    end
end)
test('S05 Artifact gives visible blocked-status feedback rather than implying poison landed',function()
    local h,u,p=H.setup({'defend'},{'cultist','jaw_worm'})
    assert(Run.obtainPotion(h.run,'poison_potion'));Combat.addStatus(h.run.combat.enemies[2],'artifact',1);h:refresh()
    p:GetChild('potion1').click();dofile('tests/lua/support/confirm_potion_popup.lua')(u,p,99)
    monsterControl(p,'enemy2'):GetChild('hit').click()
    local found=false
    for _=1,20 do
        if monsterControl(p,'enemy2'):GetChild('floating').text:find('人工制品抵挡',1,true) then found=true end
        h:update(0.05)
    end
    assert(found,'blocked application needs explicit causal feedback')
end)
print('LUA_POTION_STATUS_RULES_PASS '..count)
