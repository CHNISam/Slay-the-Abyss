local H=dofile('tests/lua/support/battle_gesture_fixture.lua')
local Combat=H.F.Combat
local count=0
local function same(a,b)
    if type(a)~='table' or type(b)~='table' then return a==b end
    for k,v in pairs(a) do if not same(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
end
local function test(name,fn) fn();count=count+1;print('ok normal pile entry '..count..' - '..name) end

test('normal generated pile icons open the matching modal and closing restores combat input',function()
    for _,kind in ipairs({'draw','discard','exhaust'}) do
        local host,ui,panel,event,tap,drain,close,root=H.setup()
        local before=Combat.copy(host.run)
        local entry=panel:GetChild(kind..'Icon'):GetChild('hit')
        assert(entry.visible and entry.raycastTarget)
        assert(entry.click({touchId=7}))
        host:update(0)
        assert(host.deckUI.visible and host.deckUI.pileKind==kind and not ui.active)
        assert(root:GetChild('deckPanel'):GetChild('grid').itemCount==#host.run.combat[kind])
        ui:playSlot(1);ui:playSelected(1);ui:endTurn();ui:usePotion(1)
        assert(same(before,host.run),'viewing allowed a combat transaction or consumed RNG')
        assert(not entry.click({touchId=8}),'closed-over icon callback replaced an open modal')
        assert(root:GetChild('deckPanel'):GetChild('close'):GetChild('hit').click({touchId=7}))
        assert(not host.deckUI.visible and ui.active)
        assert(same(before,host.run),'closing changed rules')
    end
end)

test('pile clicks reject playback drag exit overlays and reward phase without consuming resources',function()
    local host,ui,panel,event,tap,drain,close,root=H.setup()
    local entry=panel:GetChild('drawIcon'):GetChild('hit')
    local before=Combat.copy(host.run)
    event('card1','down',7);event('card1','drag',7,10,0)
    assert(not entry.click({touchId=8}) and not host.deckUI.visible)
    event('dragLayer','up',7,10,-300)
    ui.gesture,ui.carry,ui.selected=nil,nil,nil;ui:render()
    ui.busy=true;assert(not entry.click({touchId=8}));ui.busy=false
    host.exitOpen=true;host:refresh();assert(not entry.click({touchId=8}));host.exitOpen=false;host:refresh()
    assert(same(before,host.run))
    host.run.phase='reward';host.run.rewards={gold=0,goldClaimed=true,cards={'defend'},cardResolved=false,manualContinue=true}
    host:refresh();assert(not entry.visible and not entry.click({touchId=8}) and not host.deckUI.visible)
end)

test('the real upgraded True Grit exhaust choice cannot be replaced by a pile modal',function()
    local host,ui,panel,event,tap,drain=H.setup({'true_grit','defend','strike'})
    local slot
    for i,card in ipairs(host.run.combat.hand) do if card.cardId=='true_grit' then card.upgraded=true;slot=i end end
    assert(slot);ui:render();ui:playSlot(slot);ui:playSelected();drain()
    assert(host.choiceUI and host.choiceUI.visible or host.deckUI.visible,'card did not reach its real choice entrance')
    local before=Combat.copy(host.run)
    assert(not panel:GetChild('discardIcon'):GetChild('hit').click({touchId=8}))
    assert(same(before,host.run) and not host.deckUI.pileKind,'pile entry replaced the required exhaust choice')
end)

test('replacing a battle closes its old pile snapshot while permanent deck access stays available',function()
    local host,ui,panel,event,tap,drain,close,root=H.setup()
    assert(panel:GetChild('discardIcon'):GetChild('hit').click({touchId=7}))
    local old=host.run.combat
    host.run.combat=Combat.new(H.F.Data,{deck={'defend'},enemies={'cultist'}})
    host:refresh()
    assert(not host.deckUI.visible and ui.active and host.run.combat~=old)
    assert(host:openDeck() and host.deckUI.pileKind==nil)
    assert(root:GetChild('deckPanel'):GetChild('close'):GetChild('hit').click())
end)
print('LUA_NORMAL_PILE_ENTRY_PASS '..count)
