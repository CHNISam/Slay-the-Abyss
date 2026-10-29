local H = dofile('tests/lua/support/battle_gesture_fixture.lua')
local test, finish = dofile('tests/lua/support/battle_action_fixture.lua').suite('LUA_DRAG_CLICK_COMPATIBILITY')

local function drag(e, touch, release, x, y)
    e('card1','down',touch)
    e('card1','drag',touch,x or 0,y or 0)
    e('dragLayer',release or 'up',touch,x or 0,y or 0)
end
local function late(e, touch, x, y)
    e('card1','up',touch,x,y)
    e('card1','endDrag',touch,x,y)
    e('card1','click',touch,x,y)
    e('card1','click',touch,x,y)
end

for _, release in ipairs({'up','endDrag'}) do
    test('real Defend '..release..' does not lock later Click-only end turn',function()
        local h,u,p,e,_,drain = H.setup()
        drag(e,7,release)
        drain()
        local b=h.run.combat
        assert(b.energy==2 and b.player.block==5 and #b.hand==1 and not u.gesture)
        late(e,7)
        assert(not u.selected and b.energy==2 and b.player.block==5)
        p:GetChild('endTurn').click()
        assert(b.turn==2,'finished card drag permanently suppressed independent Click-only action')
        drain()
        late(e,7)
        assert(b.turn==2 and not u.selected,'delayed drag events acted in the next turn')
    end)
end

test('metadata-free drag consumes one ambiguous Click without a permanent lock',function()
    local h,u,p,e,_,drain = H.setup()
    drag(e,nil)
    drain()
    p:GetChild('endTurn').click()
    assert(h.run.combat.turn==1,'ambiguous trailing Click must be consumed safely')
    p:GetChild('endTurn').click()
    assert(h.run.combat.turn==2,'anonymous mouse drag permanently locked Click-only end turn')
    late(e,nil)
    assert(not u.selected and h.run.combat.turn==2)
end)

for _, release in ipairs({'up','endDrag'}) do
    test('repeated same-touch '..release..' Clicks cannot end the turn on a Click-only host',function()
        local h,u,p,e,tap,drain = H.setup()
        drag(e,7,release);drain()
        e('endTurn','click',7)
        e('endTurn','click',7)
        assert(h.run.combat.turn==1,'second trailing same-touch Click escaped the completed drag barrier')
        p:GetChild('endTurn').click();drain()
        assert(h.run.combat.turn==2,'independent metadata-free Click-only action stayed locked')
        e('endTurn','click',7);e('endTurn','click',7)
        assert(h.run.combat.turn==2,'independent action revived an old drag touch')
        tap('endTurn',7)
        assert(h.run.combat.turn==3,'fresh same-touch Down could not reclaim its own input')
    end)
end

test('two independent drags retain bounded latest-origin protection and fresh named Click-only actions',function()
    local h,u,p,e,tap,drain = H.setup({'defend','defend','defend'})
    drag(e,7);drain()
    drag(e,8);drain()
    local b=h.run.combat
    assert(b.energy==1 and b.player.block==10 and #b.hand==1)
    e('endTurn','click',8);e('endTurn','click',8)
    assert(b.turn==1,'latest named drag origin escaped without a new Down')
    e('endTurn','click',9);drain()
    assert(b.turn==2,'distinct fresh named Click-only action stayed locked after two drags')
    e('endTurn','click',8);e('endTurn','click',8)
    assert(b.turn==2,'fresh named action revived the latest completed drag origin')
    tap('endTurn',8)
    assert(b.turn==3,'new same-touch physical sequence did not reclaim the latest origin')
end)

test('real drag kill cannot leak its Click into reward cards or lock reward entry',function()
    local h,u,p,e,_,drain = H.setup({'bludgeon'},{'acid_slime_s'})
    local enemy=p:GetChild('enemy1')
    drag(e,7,'up',enemy.x,enemy.y)
    drain()
    assert(h.run.phase=='reward' and u.rewardScreen=='list')
    local deck=#h.run.deck
    late(e,7,enemy.x,enemy.y)
    assert(u.rewardScreen=='list' and #h.run.deck==deck)
    e('cardReward','click',7);e('cardReward','click',7)
    assert(u.rewardScreen=='list','repeated old drag Click opened the reward picker')
    e('cardReward','click',9)
    assert(u.rewardScreen=='cards','finished drag permanently suppressed Click-only reward entry')
    late(e,7,enemy.x,enemy.y)
    assert(u.rewardScreen=='cards' and #h.run.deck==deck and not h.run.rewards.cardResolved,
        'old combat card Click claimed a replacement reward slot')
    e('skip','click',7);e('skip','click',7)
    assert(u.rewardScreen=='cards','independent reward entry revived the old drag touch')
    e('skip','click',10)
    assert(u.rewardScreen=='list' and #h.run.deck==deck,'fresh Click-only skip did not remain usable')
    p:GetChild('cardReward').click();p:GetChild('skip').click()
    assert(u.rewardScreen=='list' and #h.run.deck==deck,'metadata-free reward actions did not remain usable')
end)

test('foreign pointer and Click-only actions cannot steal a live drag',function()
    local h,u,p,e,_,drain = H.setup()
    e('card1','down',7);e('card1','drag',7,0,0)
    local owner=u.gesture
    e('dragLayer','up',8,0,0);e('card1','endDrag',8,0,0)
    p:GetChild('endTurn').click()
    assert(u.gesture==owner and h.run.combat.turn==1 and h.run.combat.energy==3)
    e('dragLayer','up',7,0,0);drain()
    p:GetChild('endTurn').click()
    assert(h.run.combat.turn==2,'completed owned drag left unrelated action suppressed')
end)

test('delayed old drag events cannot consume a fresh card selection',function()
    local h,u,p,e,tap,drain = H.setup({'defend','defend','defend'})
    drag(e,7);drain()
    tap('card2',8)
    local b=h.run.combat
    local selected=u.selected
    assert(selected and selected==b.hand[2].uid)
    late(e,7)
    assert(u.selected==selected and b.energy==2 and b.player.block==5)
    tap('playArea',8)
    assert(b.energy==1 and b.player.block==10 and #b.hand==1)
end)
test('hand-return cancellation consumes the old drag without locking independent actions',function()
    local h,u,p,e,tap = H.setup()
    e('card1','down',7);e('card1','drag',7,0,0)
    e('dragLayer','drag',7,0,require('abyss_theme').layout.hand.y)
    late(e,7)
    local b=h.run.combat
    assert(not u.gesture and not u.selected and not u.carry and b.energy==3 and #b.hand==2)
    e('endTurn','click',7);e('endTurn','click',7)
    assert(b.turn==1,'repeated cancelled-drag Click ended the turn')
    local hp=b.enemies[1].hp
    p:GetChild('enemy1'):GetChild('hit').click()
    assert(u.info and u.info.index==1 and not u.selected and not u.carry,
        'independent metadata-free enemy Click must retain approved details inspection')
    assert(b.energy==3 and #b.hand==2 and b.enemies[1].hp==hp and b.turn==1,
        'independent inspection must not play the cancelled card or mutate combat')
    e('card1','down',8)
    assert(not u.info and not u.gesture and not u.selected,'first fresh Down must dismiss details, not grab beneath it')
    e('card1','up',8);e('card1','click',8)
    assert(not u.selected and b.energy==3 and #b.hand==2 and b.enemies[1].hp==hp,
        'the detail-dismissal sequence must be swallowed without playing a card')
    tap('card1',8)
    assert(u.selected==b.hand[1].uid and not u.info and b.energy==3 and #b.hand==2,
        'fresh retry after detail dismissal must restore ordinary card input')
    p:GetChild('endTurn').click()
    assert(b.turn==2,'cancelled owned drag locked unrelated Click-only action')
end)

test('busy or inactive controls cannot consume a finished drag marker',function()
    local h,u,p,e,_,drain = H.setup()
    drag(e,7)
    local marker=u.suppressClick
    assert(u.busy and type(marker)=='table')
    p:GetChild('endTurn').click()
    assert(u.suppressClick==marker and h.run.combat.turn==1)
    drain()
    assert(h:openDeck() and not u.active)
    p:GetChild('endTurn').click()
    assert(u.suppressClick==marker and h.run.combat.turn==1)
    assert(h:closeDeck())
    p:GetChild('endTurn').click()
    assert(h.run.combat.turn==2)
end)

test('completed-drag consumption cannot clear a boolean resize cancellation barrier',function()
    local h,u,p,e,tap = H.setup()
    e('card1','down',7);e('card1','drag',7,0,0)
    h:resize(1600,900)
    assert(u.suppressClick==true and not u.gesture)
    p:GetChild('endTurn').click();p:GetChild('endTurn').click()
    assert(u.suppressClick==true and h.run.combat.turn==1 and h.run.combat.energy==3)
    tap('endTurn',8)
    assert(h.run.combat.turn==2)
end)

for _, state in ipairs({'busy','inactive'}) do
    test(state..' same-touch Down cannot retire the latest completed drag origin',function()
        local h,u,p,e,_,drain = H.setup()
        assert(H.Run.obtainPotion(h.run,'energy_potion'));h:refresh()
        drag(e,7)
        if state=='inactive' then drain();assert(h:openDeck() and not u.active) end
        e('card1','down',7)
        if state=='inactive' then assert(h:closeDeck()) else drain() end
        e('potion1','click',7);e('potion1','click',7)
        assert(h.run.potions[1]=='energy_potion' and h.run.combat.energy==2 and not u.potionMenu,
            state..' Down revived the drag origin on a different Click-only control')
        p:GetChild('potion1').click()
        local popup=p:GetChild('potionHelp'):GetChild('potionPopup')
        assert(u.potionMenu and u.potionMenu.slot==1 and popup.visible,
            'independent Click-only bottle stayed locked instead of opening its approved menu')
        assert(h.run.potions[1]=='energy_potion' and h.run.combat.energy==2,
            'bottle Click bypassed the approved explicit Use step')
        local use,discard=popup:GetChild('use'),popup:GetChild('discard')
        assert(use.visible and use.interactable and use.activeInHierarchy,'Use must be genuinely visible and enabled')
        use.click({touchId=7});use.click({touchId=7})
        discard.click({touchId=7});discard.click({touchId=7})
        assert(u.potionMenu and popup.visible and h.run.potions[1]=='energy_potion' and h.run.combat.energy==2,
            'latest named drag escaped through a new Click-only Use or Discard control')
        local fresh=state=='busy' and 7 or nil
        if fresh then
            use.listeners.down({touchId=fresh});use.listeners.up({touchId=fresh});use.click({touchId=fresh})
        else use.click() end
        assert(h.run.potions[1]==nil and h.run.combat.energy==4 and not u.potionMenu,
            'visible explicit Use did not consume exactly the selected bottle')
        use.click({touchId=fresh})
        assert(h.run.combat.energy==4,'repeated old Use applied the potion twice')
        if not fresh then
            drain();e('endTurn','click',7);e('endTurn','click',7)
            assert(h.run.combat.turn==1,'independent popup Use revived the latest completed drag origin')
            assert(H.Run.obtainPotion(h.run,'energy_potion'));h:refresh()
            p:GetChild('potion1').click()
            assert(u.potionMenu and popup.visible and discard.visible and discard.interactable and discard.activeInHierarchy)
            discard.click({touchId=7});discard.click({touchId=7})
            assert(h.run.potions[1]=='energy_potion' and u.potionMenu,'old Discard revived after independent Use')
            discard.listeners.down({touchId=7});discard.listeners.up({touchId=7});discard.click({touchId=7})
            assert(h.run.potions[1]==nil and h.run.combat.energy==4 and not u.potionMenu,
                'fresh same-touch Down did not reclaim explicit Discard without applying the potion')
        end
    end)
end

test('frozen Raiden V4 real E drag retains mechanics and later Click-only end turn',function()
    local h,root=H.F.fixture(nil,nil,nil,{CursorDown='down',CursorDrag='drag',CursorUp='up',CursorEndDrag='endDrag'})
    assert(H.F.start(h,'raiden'))
    assert(H.F.Nodes.enter(h.run,h.map,H.F.Nodes.available(h.run,h.map)[1].id))
    h:resize(1280,720);h:refresh()
    local u,p,b=h.battleUI,root:GetChild('battlePanel'),h.run.combat
    local slot
    for i,card in ipairs(b.hand) do if card.uid==7 then slot=i end end
    assert(slot and b.originalV4,'frozen seed-1 Raiden E must be in the natural opening')
    local function emit(name,kind,touch,x,y)
        if name=='card1' then name='card'..slot end
        local box=p:GetChild(name)
        local hit=box.listeners and box or box:GetChild('hit')
        return assert(hit.listeners[kind])({touchId=touch,GetUIPos=function()return 640+(x or 0),360+(y or 0)end})
    end
    local enemy,energy,hand=p:GetChild('enemy1'),b.energy,#b.hand
    drag(emit,7,'up',enemy.x,enemy.y)
    for _=1,400 do if not u.busy then break end;h:update(0.05) end
    assert(not u.busy and h.run.phase=='combat' and b.energy==energy-1 and #b.hand==hand-1)
    assert(b.originalV4.eye.uses==3 and b.originalV4.resolve==1,'frozen Raiden E mechanics changed')
    late(emit,7,enemy.x,enemy.y)
    assert(b.energy==energy-1 and not u.selected)
    p:GetChild('endTurn').click()
    assert(b.turn==2,'Raiden real drag locked mixed-host end turn')
end)
finish()
