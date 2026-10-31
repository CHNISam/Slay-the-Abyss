-- Real generated Host flow; model native sibling ordering instead of directly
-- invoking a button hidden behind the full-page map after route preview.
local H=dofile('tests/lua/support/battle_action_fixture.lua')
local Run=require('abyss_run')
local test,finish=H.suite('LUA_REWARD_RETURN_FOREGROUND')
local function siblingOrder(root)
    local order={}
    local stage
    for _,spec in ipairs(require('abyss_ui_layout'))do if spec.name=='stage'then stage=spec end end
    for _,spec in ipairs(assert(stage).children)do
        local control=assert(root:GetChild(spec.name));order[#order+1]=control
        control.SetAsLastSibling=function(self)
            for i,item in ipairs(order)do if item==self then table.remove(order,i);break end end
            order[#order+1]=self
        end
    end
    return function(front,back)
        local a,b
        for i,item in ipairs(order)do if item==front then a=i end;if item==back then b=i end end
        return assert(a)>assert(b)
    end
end
local function tap(box,id)
    local hit=box:GetChild('hit')
    if hit.listeners.down then hit.listeners.down({touchId=id})end
    if hit.listeners.up then hit.listeners.up({touchId=id})end
    return hit.click({touchId=id})
end
local function preview(h,root,id)
    assert(h:openMenu());assert(tap(root:GetChild('runMenu'):GetChild('map'),id))
    assert(h.routeOpen and root:GetChild('mapPanel').visible)
    assert(tap(root:GetChild('mapPanel'):GetChild('previewBack'),id+1))
    assert(tap(root:GetChild('runMenu'):GetChild('resume'),id+2))
end
test('route preview cannot bury pending gold return before the next room',function()
    local h,_,_,_,click=H.setup()
    local root=h.root;local above=siblingOrder(root)
    assert(not root:GetChild('combatRewards').visible,'no-pending entry leaked')
    preview(h,root,10)
    for _,enemy in ipairs(h.run.combat.enemies)do enemy.hp=0 end
    assert(Run.finishCombat(h.run));h:refresh()
    local rewards,battle,flow=h.run.rewards,h.run.combat,h.run.nodeFlow
    local gold,amount=h.run.gold,rewards.gold
    click('continue',20)
    local back,map=root:GetChild('combatRewards'),root:GetChild('mapPanel')
    assert(back.visible and map.visible and h.run.pendingCombatRewards.rewards==rewards)
    assert(h.run.gold==gold,'leaving must not auto-claim gold')
    assert(above(back,map),'pending reward return is occluded by the previously raised map')
    local hit=back:GetChild('hit')
    hit.listeners.down({touchId=21});hit.listeners.up({touchId=21})
    assert(h:openMenu());assert(not back.visible)
    assert(not hit.click({touchId=21}),'a hidden return entry must reject stale input')
    assert(not tap(back,201),'a hidden return entry must reject a fresh direct tap')
    assert(h.run.phase=='map' and h.run.pendingCombatRewards.rewards==rewards and h.run.gold==gold)
    assert(tap(root:GetChild('runMenu'):GetChild('resume'),24))
    assert(back.visible and above(back,map),'closing the menu must restore reward return above the map')
    assert(not hit.click({touchId=21}),'menu dismissal must not revive the old released tap')
    assert(h.run.phase=='map' and h.run.gold==gold)
    assert(tap(back,25));assert(h.run.rewards==rewards and h.run.combat==battle and h.run.nodeFlow==flow)
    click('goldReward',22);assert(h.run.gold==gold+amount and rewards.goldClaimed)
    click('continue',23)
    preview(h,root,30)
    assert(back.visible and above(back,map),'preview while rewards are pending must restore the return entry')
    assert(tap(back,33));assert(not Run.claimGoldReward(h.run) and h.run.gold==gold+amount)
    assert(not rewards.cardResolved,'returning must preserve the unclaimed card offer')
    click('continue',34)
    assert(Run.startCombat(h.run,'cultist_solo'));h:refresh()
    assert(not back.visible and h.run.pendingCombatRewards==nil)
    assert(not tap(back,35) and h.run.phase=='combat','expired return cannot reopen rewards in the next room')
end)
finish()
