local H = dofile('tests/lua/support/battle_gesture_fixture.lua')
local host,ui,panel,event,tap = H.setup()
local battle=host.run.combat
event('card1','down',7)
-- No Up/EndDrag: a release outside the dispatch surface or an interrupted
-- native pointer must not prevent the next complete click of that pointer.
tap('card2',7)
assert(ui.selected==battle.hand[2].uid,'interrupted press permanently blocks fresh card click')
assert(battle.energy==3 and #battle.hand==2,'recovery must not play a card')
event('card1','up',7);event('card1','click',7)
assert(ui.selected==battle.hand[2].uid,'late old release changed new selection')
tap('playArea',7)
assert(battle.energy==2 and #battle.hand==1 and battle.player.block==5)
print('CARD_INTERRUPTED_RECOVERY_PASS')

for _,id in ipairs({7,false}) do
    local _,u,p,e,t = H.setup()
    local pointer=id or nil -- native mouse events can omit touchId
    e('card1','down',pointer)
    local owned=u.gesture
    e('card2','down',99)
    assert(u.gesture==owned,'foreign pointer stole live press')
    t('card2',pointer)
    assert(u.selected==u.run.combat.hand[2].uid and not u.gesture)
end

do
    local _,u,p,e,t=H.setup()
    local b=u.run.combat
    e('card1','down',7);e('card1','drag',7,0,0)
    assert(p:GetChild('dragLayer').visible)
    e('dragLayer','down',99)
    assert(u.gesture,'foreign touch cancelled capture')
    e('dragLayer','down',7)
    assert(not u.gesture and not p:GetChild('dragLayer').visible,'interrupted drag layer kept blocking')
    e('dragLayer','up',7);e('card1','click',7)
    assert(not u.selected and b.energy==3 and #b.hand==2,'capture cancellation clicked through')
    t('card2',7)
    assert(u.selected==b.hand[2].uid,'cards remain blocked after capture cancellation')
end

do
    local A=dofile('tests/lua/support/battle_action_fixture.lua')
    local h,u,p,e,t=A.reward()
    e('card1','down',7) -- reward picker has no combat drag
    e('card2','down',7);e('card2','up',7);e('card2','click',7)
    assert(h.run.rewards.cardResolved,'fresh reward click failed')
end
print('CARD_INTERRUPTED_BOUNDARIES_PASS')
