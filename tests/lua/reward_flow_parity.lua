package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local H=dofile('tests/lua/support/battle_action_fixture.lua')
local Run,Combat,Data,Map,Nodes=require('abyss_run'),require('abyss_combat'),require('abyss_data'),require('abyss_map'),require('abyss_nodes')
local test,finish=H.suite('LUA_REWARD_FLOW_PARITY')
local function won(run)
    run=run or Run.new(Data,42)
    assert(Run.startCombat(run,'cultist_solo'))
    for _,enemy in ipairs(run.combat.enemies) do enemy.hp=0 end
    assert(Run.finishCombat(run))
    return run
end
local function uiReward(stolen)
    local h,u,p,e,t,d=H.setup()
    h.run=Run.new(Data,42);u.run=h.run
    assert(Run.startCombat(h.run,'cultist_solo'))
    if stolen then h.run.combat.stolenGoldReward=stolen end
    for _,enemy in ipairs(h.run.combat.enemies) do enemy.hp=0 end
    assert(Run.finishCombat(h.run));h:refresh()
    return h,u,p,e,t,d
end
test('victory offers gold; only the independent gold row grants it once',function()
    local r=won();local before=r.gold;local gold=r.rewards.gold
    assert(before==Data.rules.player.startingGold)
    assert(Run.claimCardReward(r,1));assert(r.gold==before and r.phase=='reward')
    assert(Run.claimGoldReward(r));assert(r.gold==before+gold)
    assert(not Run.claimGoldReward(r));assert(r.gold==before+gold)
    local overflow=won();overflow.gold=2147483647
    assert(not Run.claimGoldReward(overflow));assert(not overflow.rewards.goldClaimed and overflow.gold==2147483647)
end)
test('Proceed preserves every remaining item for return and never auto-claims',function()
    local r=won();local rewards,battle=r.rewards,r.combat
    assert(Run.leaveCombatRewards(r));assert(r.phase=='map' and r.gold==99 and #r.deck==10 and Run.potionCount(r)==0)
    assert(r.pendingCombatRewards.rewards==rewards and r.pendingCombatRewards.combat==battle)
    assert(Run.reopenCombatRewards(r));assert(r.phase=='reward' and r.rewards==rewards and r.combat==battle)
    assert(Run.claimGoldReward(r));local gold=r.gold
    assert(Run.leaveCombatRewards(r));assert(Run.reopenCombatRewards(r));assert(not Run.claimGoldReward(r) and r.gold==gold)
end)
test('full belt is atomic and Sozu consumes the clicked offer without obtaining a bottle',function()
    local r=won();for _,id in ipairs({'fire_potion','energy_potion','block_potion'})do assert(Run.obtainPotion(r,id))end
    local offer,inventory=r.rewards.potion,r.potions
    local ok,why=Run.claimPotionReward(r);assert(not ok and why=='potion_slots_full')
    assert(r.potions==inventory and not offer.resolved)
    assert(Run.discardPotion(r,2));assert(Run.claimPotionReward(r));assert(r.potions[2]==offer.id)
    r=won();r.relics[#r.relics+1]='sozu';offer=r.rewards.potion
    ok,why=Run.claimPotionReward(r);assert(ok and why=='potion_blocked_by_sozu')
    assert(offer.resolved and offer.result=='blocked' and Run.potionCount(r)==0)
    assert(not Run.claimPotionReward(r))
end)
test('failed room entry preserves pending rewards; successful combat and node entry expire them',function()
    local r=won();assert(Run.leaveCombatRewards(r));local pending=r.pendingCombatRewards
    assert(not Run.startCombat(r,'not_an_encounter'));assert(r.pendingCombatRewards==pending)
    assert(Run.startCombat(r,'cultist_solo'));assert(r.pendingCombatRewards==nil)
    r=Run.new(Data,42);local map=Map.generate(Data,42)
    local first=assert(Nodes.available(r,map)[1]);assert(Nodes.enter(r,map,first.id))
    for _,enemy in ipairs(r.combat.enemies)do enemy.hp=0 end
    assert(Run.finishCombat(r));assert(Run.leaveCombatRewards(r));assert(Nodes.completeCombat(r,map))
    pending=r.pendingCombatRewards
    assert(not Nodes.enter(r,map,'bad-room'));assert(r.pendingCombatRewards==pending)
    local nextNode=assert(Nodes.available(r,map)[1]);assert(Nodes.enter(r,map,nextNode.id))
    assert(r.pendingCombatRewards==nil and not Run.reopenCombatRewards(r))
end)
test('generated tree renders list then picker; PC selection returns to list without other claims',function()
    local h,u,p,e,t=uiReward(30)
    assert(p:GetChild('rewardList').visible and not p:GetChild('rewardStage').visible)
    assert(not p:GetChild('card1').visible and not p:GetChild('skip').visible and p:GetChild('skipPotion')==nil)
    assert(p:GetChild('goldReward').visible and p:GetChild('claimPotion').visible and p:GetChild('cardReward').visible)
    t('card1',1);assert(#h.run.deck==10,'hidden card input claimed a reward')
    t('cardReward',2);assert(p:GetChild('rewardStage').visible and not p:GetChild('rewardList').visible)
    assert(not p:GetChild('continue').visible and not p:GetChild('goldReward').visible and not p:GetChild('claimPotion').visible)
    t('card1',3);assert(#h.run.deck==11 and h.run.phase=='reward')
    assert(p:GetChild('rewardList').visible and not p:GetChild('rewardStage').visible and not p:GetChild('notice').visible)
    assert(not p:GetChild('cardReward').visible and p:GetChild('goldReward').visible and p:GetChild('claimPotion').visible)
    assert(h.run.gold==99 and Run.potionCount(h.run)==0 and not h.run.rewards.stolenGold.claimed)
end)
test('Skip only closes the picker and allows the same unclaimed cards to reopen',function()
    local h,u,p,e,t=uiReward();local choices=h.run.rewards.cards
    t('cardReward',1);t('skip',2)
    assert(h.run.rewards.cards==choices and not h.run.rewards.cardResolved and #h.run.deck==10)
    assert(p:GetChild('rewardList').visible and p:GetChild('cardReward').visible)
    t('cardReward',3);assert(p:GetChild('card1').visible);t('card2',4)
    assert(#h.run.deck==11 and h.run.deck[11].cardId==choices[2])
end)
test('held and released inputs from earlier picker pages cannot claim after reopening',function()
    for _,released in ipairs({false,true})do
        local h,u,p,e,t=uiReward();t('cardReward',1);e('card1','down',7)
        if released then e('card1','up',7)end
        t('skip',8);t('cardReward',9)
        e('card1','up',7);e('card1','click',7)
        assert(#h.run.deck==10 and not h.run.rewards.cardResolved)
        t('card1',10);assert(#h.run.deck==11)
    end
end)
test('generated full-belt rejection remains visible and list continue permits map return',function()
    local h,u,p,e,t=uiReward()
    for _,id in ipairs({'fire_potion','energy_potion','block_potion'})do assert(Run.obtainPotion(h.run,id))end
    h:refresh();assert(p:GetChild('claimPotion').interactable)
    t('claimPotion',1);assert(not h.run.rewards.potion.resolved)
    assert(p:GetChild('potionReward').text:find('丢弃旧药水',1,true) and not p:GetChild('notice').visible)
    t('continue',2);assert(h.run.phase=='map' and h.run.pendingCombatRewards)
    local root=h.root;local back=root:GetChild('combatRewards'):GetChild('hit')
    assert(root:GetChild('combatRewards').visible)
    back.listeners.down({touchId=3});back.listeners.up({touchId=3});assert(back.click({touchId=3}))
    assert(h.run.phase=='reward' and p:GetChild('rewardList').visible and not h.run.rewards.potion.resolved)
end)
test('map return held and released inputs expire across overlays and replacement runs',function()
    for _,released in ipairs({false,true})do
        local h,u,p,e,t=uiReward();t('continue',1)
        local button=h.root:GetChild('combatRewards'):GetChild('hit')
        button.listeners.down({touchId=7});if released then button.listeners.up({touchId=7})end
        assert(h:openDeck());assert(h:closeDeck())
        button.listeners.up({touchId=7});button.click({touchId=7})
        assert(h.run.phase=='map' and h.run.pendingCombatRewards)
        button.listeners.down({touchId=8});button.listeners.up({touchId=8});button.click({touchId=8})
        assert(h.run.phase=='reward')
        t('continue',2);button.listeners.down({touchId=9});button.listeners.up({touchId=9})
        local old=h.run;old.phase='defeat';h:refresh();assert(h:start());button.click({touchId=9})
        assert(h.run~=old and h.run.phase=='map' and h.run.pendingCombatRewards==nil)
    end
end)
test('a failed staged next-combat setup retains original pending rewards and map identity',function()
    local r=Run.new(Data,42);local map=Map.generate(Data,42)
    local first=assert(Nodes.available(r,map)[1]);assert(Nodes.enter(r,map,first.id))
    for _,enemy in ipairs(r.combat.enemies)do enemy.hp=0 end
    assert(Run.finishCombat(r));assert(Run.leaveCombatRewards(r));assert(Nodes.completeCombat(r,map))
    local pending,current,floor=r.pendingCombatRewards,map.currentNodeId,map.floor
    local nextNode=assert(Nodes.available(r,map)[1])
    -- Controlled room-setup rejection; route legality and Map.choose stay real.
    local startCombat=Run.startCombat
    if nextNode.type~='combat' and nextNode.type~='elite' and nextNode.type~='boss' then
        local node
        for _,candidate in ipairs(map.nodes)do if candidate.id==nextNode.id then node=candidate end end
        node.type,nextNode.type='combat','combat';node.encounterId='cultist_solo'
    end
    Run.startCombat=function()return false,'injected_room_setup_failure'end
    local ok,why=Nodes.enter(r,map,nextNode.id)
    Run.startCombat=startCombat
    assert(not ok and why=='injected_room_setup_failure')
    assert(r.phase=='map' and r.pendingCombatRewards==pending and map.currentNodeId==current and map.floor==floor)
    assert(Run.reopenCombatRewards(r) and r.rewards==pending.rewards)
end)
finish()
