local H = dofile('tests/lua/support/battle_gesture_fixture.lua')
local Theme = require('abyss_theme')
local passed, failed = 0, 0
local function test(name, fn)
    local ok, why = pcall(fn)
    if ok then passed=passed+1; print('PASS '..name)
    else failed=failed+1; print('FAIL '..name..': '..tostring(why)) end
end

test('aiming preserves the grabbed hand column instead of snapping onto the middle card', function()
    local host,ui,panel,event=H.setup({'strike','strike','strike','strike','strike'})
    local card=panel:GetChild('card1')
    local x,y=card.x,card.y
    local uid=host.run.combat.hand[1].uid
    event('card1','enter',7)
    event('card1','down',7,x,y)
    event('card1','drag',7,-285,0)
    assert(ui.gesture.uid==uid and ui.selected==uid)
    assert(card.x==x,'aiming snapped grabbed card into another hand column')
    assert(ui.hover==nil,'grab left a competing hand hover active')
    for i=2,5 do
        event('card'..i,'enter',7)
        event('card'..i,'drag',7,panel:GetChild('card'..i).x,y)
        assert(ui.gesture.uid==uid and ui.selected==uid,'neighbour stole held card')
    end
    assert(host.run.combat.energy==3 and #host.run.combat.hand==5)
end)

test('held attack returns to the ordinary hand row and cancels before release', function()
    local host,ui,panel,event,tap=H.setup({'strike','strike','strike'})
    local battle=host.run.combat
    local x,y=panel:GetChild('card1').x,panel:GetChild('card1').y
    event('card1','enter',7)
    event('card1','down',7,x,y)
    event('card1','drag',7,-285,0)
    event('dragLayer','drag',7,panel:GetChild('card2').x,Theme.layout.hand.y)
    assert(ui.gesture==nil and ui.selected==nil and ui.carry==nil,'hand return did not cancel')
    assert(ui.hover==nil and not panel:GetChild('dragLayer').visible)
    event('dragLayer','up',7,0,Theme.layout.hand.y)
    event('card1','endDrag',7);event('card1','click',7);event('card2','click',7)
    assert(ui.selected==nil and battle.energy==3 and #battle.hand==3)
    tap('card2',8)
    assert(ui.selected==battle.hand[2].uid,'next deliberate tap was blocked after cancel')
    tap('card2',8)
    assert(ui.selected==nil,'same card could not be deselected after cancel')
end)

test('released targeting cancels on return to the hand without going below the screen', function()
    local cx,cy=355,360
    local host,ui,panel,event=H.setup({'strike','strike'},nil,{position=function() return cx,cy end})
    event('card1','down',7);event('card1','drag',7,-285,0)
    event('dragLayer','up',7,-285,0)
    assert(ui.carry and ui.selected)
    cx,cy=640,360+Theme.layout.hand.y
    host:update(1/60)
    assert(ui.carry==nil and ui.selected==nil,'released targeting remained stuck over the hand')
    assert(not panel:GetChild('dragLayer').visible and host.run.combat.energy==3)
end)

test('no-target card pulled back from play area cannot become a short carried selection', function()
    local host,ui,_,event=H.setup({'defend','defend'})
    event('card1','down',7);event('card1','drag',7,0,0)
    event('dragLayer','drag',7,0,Theme.layout.hand.y)
    event('dragLayer','up',7,0,Theme.layout.hand.y)
    assert(ui.gesture==nil and ui.carry==nil and ui.selected==nil,'quick hand return reselected the card')
    assert(host.run.combat.energy==3 and host.run.combat.player.block==0 and #host.run.combat.hand==2)
end)

test('touch targeting also cancels at the visible hand row', function()
    local host,ui,panel,event=H.setup({'strike','strike'},nil,{touchScreen=function() return true end})
    event('card1','down',7);event('card1','drag',7,-285,0)
    assert(ui.gesture and ui.gesture.aiming)
    event('dragLayer','drag',7,panel:GetChild('card2').x,Theme.layout.hand.y)
    event('card1','endDrag',7);event('card2','click',7)
    assert(ui.gesture==nil and ui.carry==nil and ui.selected==nil)
    assert(host.run.combat.energy==3 and #host.run.combat.hand==2)
end)

print('LUA_CARD_DRAG_CANCEL '..passed..' passed; '..failed..' failed')
assert(failed==0,'card drag cancellation regressions: '..failed)
