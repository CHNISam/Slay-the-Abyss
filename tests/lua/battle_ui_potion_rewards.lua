local H=dofile('tests/lua/support/battle_action_fixture.lua')
local C,Run=require('abyss_combat'),require('abyss_run')
local test,finish=H.suite('LUA_BATTLE_UI_POTION_REWARDS')
local function reward()
    local host,ui,panel,emit,tap,drain=H.setup()
    host.run=Run.new(H.F.Data,42);host.battleUI.run=host.run
    assert(Run.startCombat(host.run,'cultist_solo'))
    -- Completed-battle fixture isolates real generated-tree reward input.
    for _,enemy in ipairs(host.run.combat.enemies) do enemy.hp=0 end
    assert(Run.finishCombat(host.run));assert(host.run.rewards.potion)
    host:refresh()
    return host,ui,panel,emit,tap,drain
end
test('reward names bottle and claim stores it once through the real controller',function()
    local h,u,p,emit,tap=reward()
    assert(p:GetChild('potionReward').visible)
    assert(p:GetChild('rewardList').visible and not p:GetChild('energy').visible)
    local name=h.run.rewards.potion.id
    assert(p:GetChild('claimPotion'):GetChild('normal'):GetChild('label').text:find('×1',1,true))
    tap('claimPotion',7)
    assert(h.run.potions[1]==name and h.run.rewards.potion.resolved)
    assert(not p:GetChild('claimPotion').visible)
    tap('claimPotion',7);assert(Run.potionCount(h.run)==1)
end)
test('full belt allows card selection and Proceed while retaining the pending bottle',function()
    local h,u,p,emit,tap=reward()
    for _,id in ipairs({'block_potion','energy_potion','fire_potion'}) do assert(Run.obtainPotion(h.run,id)) end
    h:refresh();assert(p:GetChild('claimPotion').interactable)
    assert(p:GetChild('rewardList').visible and p:GetChild('skipPotion')==nil)
    local reward,gold,nextUid=h.run.rewards,h.run.gold,h.run.nextDeckUid
    tap('cardReward',0);tap('card1',1)
    assert(h.run.phase=='reward' and #h.run.deck==11)
    assert(h.run.rewards==reward and h.run.gold==gold and h.run.nextDeckUid==nextUid+1)
    assert(p:GetChild('rewardList').visible and p:GetChild('potionReward').visible)
    assert(p:GetChild('potionReward').text:find('药水槽已满',1,true))
    tap('claimPotion',2);assert(not h.run.rewards.potion.resolved)
    tap('continue',3);assert(h.run.phase=='map' and #h.run.deck==11)
    assert(Run.potionCount(h.run)==3)
end)
test('released potion action cannot act after a different reward owner replaces it',function()
    local h,u,p,emit,tap=reward()
    emit('claimPotion','down',7);emit('claimPotion','up',7)
    local old=h.run
    h.run=Run.new(H.F.Data,42);h.battleUI.run=h.run;h:refresh()
    emit('claimPotion','click',7)
    assert(Run.potionCount(h.run)==0 and Run.potionCount(old)==0)
end)
finish()
