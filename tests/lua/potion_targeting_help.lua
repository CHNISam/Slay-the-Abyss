local H = dofile('tests/lua/support/potion_gesture_fixture.lua')
local Combat, Run = H.F.Combat, H.Run
local test, finish = H.suite('LUA_POTION_TARGETING_HELP')
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
test('S01/S02/S12 explicit help opens before use without changing rules state or target',function()
    for _,id in ipairs({'fire_potion','poison_potion','strength_potion','energy_potion'}) do
        local h,u,p,e,t,d,deck,r,emit,tap=setup({id});local before=snapshot(h);local target=u.target
        local bottle=p:GetChild('potion1');assert(bottle and bottle.visible,'visible potion explanation entry missing')
        emit('potion1','down',3);h:update(0.4);emit('potion1','up',3);emit('potion1','click',3)
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

test('P12 all registered potions retain explicit independent target policies',function()
    local expected={fire_potion='enemy_one',block_potion='self',strength_potion='self',
        dexterity_potion='self',energy_potion='self',poison_potion='enemy_one',regen_potion='self',
        swift_potion='self',weak_potion='enemy_one',fear_potion='enemy_one',
        ancient_potion='self',liquid_bronze='self',duplication_potion='self',distilled_chaos='self',
        smoke_bomb='self',snecko_oil='self',elixir='self',gamblers_brew='self',liquid_memories='self',
        blood_potion='self',fruit_juice='self',blessing_of_the_forge='self',explosive_potion='enemy_all',
        heart_of_iron='self',essence_of_steel='self',cultist_potion='self',flex_potion='self',speed_potion='self',
        entropic_brew='self',attack_potion='self',skill_potion='self',power_potion='self',colorless_potion='self',fairy_in_a_bottle='self'}
    local seen,count={},{self=0,enemy_one=0,enemy_all=0}
    for _,item in ipairs(H.F.Data.potions.potions) do
        assert(not seen[item.id],'duplicate potion definition: '..item.id);seen[item.id]=true
        assert(expected[item.id] and item.targetPolicy==expected[item.id],
            'wrong explicit targetPolicy: '..item.id)
        assert(item.acquisitionPending==nil,'implemented potion must not be filtered from its source pool: '..item.id)
        count[item.targetPolicy]=count[item.targetPolicy]+1
    end
    for id in pairs(expected) do assert(seen[id],'missing potion definition: '..id) end
    assert(count.self==29 and count.enemy_one==4 and count.enemy_all==1)
end)
finish()
