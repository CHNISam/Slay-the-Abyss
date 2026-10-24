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
    local name=h.run.rewards.potion.id
    assert(p:GetChild('potionReward').text:find('选牌时自动领取',1,true))
    tap('claimPotion',7)
    assert(h.run.potions[1]==name and h.run.rewards.potion.resolved)
    assert(not p:GetChild('claimPotion').visible)
    tap('claimPotion',7);assert(Run.potionCount(h.run)==1)
end)
test('full belt leaves card and potion pending until player explicitly abandons bottle',function()
    local h,u,p,emit,tap=reward()
    for _,id in ipairs({'block_potion','energy_potion','fire_potion'}) do assert(Run.obtainPotion(h.run,id)) end
    h:refresh();assert(not p:GetChild('claimPotion').interactable)
    tap('card1',1)
    assert(h.run.phase=='reward' and #h.run.deck==10)
    assert(p:GetChild('notice').text:find('药水槽已满',1,true))
    tap('skipPotion',2);assert(h.run.rewards.potion.result=='skipped')
    tap('card1',3);assert(h.run.phase=='map' and #h.run.deck==11)
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
