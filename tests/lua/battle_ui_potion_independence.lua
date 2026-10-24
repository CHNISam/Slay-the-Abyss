local H=dofile('tests/lua/support/battle_action_fixture.lua')
local Run=require('abyss_run')
local test,finish=H.suite('LUA_BATTLE_UI_POTION_INDEPENDENCE')
local function reward()
    local h,u,p,emit,tap=H.setup()
    h.run=Run.new(H.F.Data,42);h.battleUI.run=h.run
    assert(Run.startCombat(h.run,'cultist_solo'))
    for _,enemy in ipairs(h.run.combat.enemies) do enemy.hp=0 end
    assert(Run.finishCombat(h.run));h:refresh()
    return h,u,p,emit,tap
end
test('card selection and skipping cannot take a potion through generated UI',function()
    for _,action in ipairs({'card1','skip'}) do
        local h,u,p,emit,tap=reward()
        tap('cardReward',0)
        tap(action,1)
        assert(Run.potionCount(h.run)==0,'card input secretly acquired potion')
        assert(h.run.phase=='reward' and not h.run.rewards.potion.resolved)
        assert(p:GetChild('continue').visible)
        tap('continue',2);assert(h.run.phase=='map');assert(Run.reopenCombatRewards(h.run));h:refresh()
        tap('claimPotion',3);assert(Run.potionCount(h.run)==1 and h.run.phase=='reward')
        tap('continue',4);assert(h.run.phase=='map')
    end
end)
test('bottle label names its effect quantity and explicit full-belt replacement',function()
    local h,u,p=reward()
    local caption=p:GetChild('claimPotion'):GetChild('normal'):GetChild('label').text
    assert(caption:find('×1',1,true))
    local expected={fire_potion='单敌·固定20',block_potion='自用·格挡12',strength_potion='自用·力量2',dexterity_potion='自用·敏捷2',energy_potion='自用·能量2',regen_potion='自用·再生5'}
    assert(caption:find(assert(expected[h.run.rewards.potion.id]),1,true),caption)
    for _,id in ipairs({'block_potion','energy_potion','fire_potion'}) do assert(Run.obtainPotion(h.run,id)) end
    h:refresh()
    assert(p:GetChild('potionReward').text:find('丢弃旧药水',1,true))
    assert(p:GetChild('claimPotion').interactable)
end)
finish()
