local H=dofile('tests/lua/support/battle_action_fixture.lua')
local S=dofile('tests/lua/support/ui_readability_snapshot.lua')
local Run,Map,Nodes=require('abyss_run'),require('abyss_map'),require('abyss_nodes')
local function capture(name,h,root)
    local r=h.run and h.run.rewards
    S.capture(name,root,H.F.Layout,{phase=h.run and h.run.phase or 'menu',
        cardResolved=r and r.cardResolved == true or false,potionResolved=r and r.potion and r.potion.resolved == true or false})
end
local function reward(stolen,full)
    local h,u,p,e,t,d,deck,root=H.setup()
    h.run=Run.new(H.F.Data,42);h.battleUI.run=h.run
    assert(Run.startCombat(h.run,'cultist_solo'))
    -- Isolate the completed encounter; all reward generation and subsequent
    -- transitions use the real Run and UI commands, not fabricated text.
    for _,enemy in ipairs(h.run.combat.enemies) do enemy.hp=0 end
    if stolen then h.run.combat.stolenGoldReward=30 end
    assert(Run.finishCombat(h.run));assert(h.run.rewards.potion)
    if full then
        for _,id in ipairs({'block_potion','energy_potion','fire_potion'}) do assert(Run.obtainPotion(h.run,id)) end
    end
    h:refresh()
    return h,u,p,t,root
end
local function choose(p,t)
    -- Opening the list item is a real UI action on the new flow. This keeps
    -- this fixture executable against the escaped version for red evidence.
    if p:GetChild('cardReward') then t('cardReward',11) end
end
local h,u,p,t,root=reward(false,false)
capture('reward-list',h,root)
choose(p,t);capture('card-pick',h,root)
for _=1,30 do h:update(.05) end
capture('card-pick-settled',h,root)
u:setHover(1);for _=1,30 do h:update(.05) end
capture('card-pick-hover',h,root)
t('card1',12);assert(h.run.rewards.cardResolved)
capture('card-added',h,root)
t('claimPotion',13);assert(h.run.rewards.potion.resolved)
capture('potion-claimed',h,root)
h:refresh();capture('reward-redraw',h,root)

h,u,p,t,root=reward(false,false)
choose(p,t);t('skip',14);assert(h.run.phase=='reward')
capture('card-skipped',h,root)

h,u,p,t,root=reward(false,true)
capture('potion-full',h,root)
choose(p,t);t('card1',15);assert(h.run.rewards.cardResolved)
capture('potion-full-card-added',h,root)
-- Failed command must remain atomic and its explanation must be legible.
assert(not u:claimPotionReward());assert(not h.run.rewards.potion.resolved)
capture('potion-full-rejected',h,root)

h,u,p,t,root=reward(true,false)
capture('stolen-gold-list',h,root)
t('stolenGold',16);assert(h.run.rewards.stolenGold.claimed)
capture('stolen-gold-claimed',h,root)

-- Same-cause spot checks: actual page ownership and header/feedback geometry.
h,root=H.F.fixture();capture('menu',h,root)
assert(h:start());capture('map',h,root)
h.mapUI.entryError='当前路线不可达，请选择亮起的节点。';h.mapUI:render()
capture('map-feedback',h,root)
h.mapUI.entryError=nil;h.mapUI:render();capture('map-feedback-cleared',h,root)
assert(Run.startCombat(h.run,'cultist_solo'));h:refresh()
capture('battle',h,root)
root:GetChild('battlePanel'):GetChild('notice').text='能量不足，请选择其他卡牌。'
h.battleUI:render();capture('battle-feedback',h,root)
root:GetChild('battlePanel'):GetChild('notice').text='';h.battleUI:render()
capture('battle-feedback-cleared',h,root)
-- Walk the real generated map to enter the first camp; this isolates node UI
-- rendering without replaying unrelated combat mechanics.
local r,m=Run.new(H.F.Data,42),Map.generate(H.F.Data,42)
while true do
    local available=Map.available(m);local camp
    for _,node in ipairs(available) do if node.type=='camp' then camp=node;break end end
    if camp then assert(Nodes.enter(r,m,camp.id));break end
    assert(#available>0);assert(Map.choose(m,available[1].id))
end
h.run,h.map=r,m;h:refresh();capture('camp',h,root)
h.nodeUI.notice='当前无法选择，请检查生命与卡组。';h.nodeUI:render()
capture('camp-feedback',h,root)
h.nodeUI.notice='';h.nodeUI:render();capture('camp-feedback-cleared',h,root)
print('UI_READABILITY_CAPTURE_PASS')
