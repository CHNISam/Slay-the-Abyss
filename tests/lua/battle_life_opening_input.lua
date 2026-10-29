local H = dofile('tests/lua/support/battle_gesture_fixture.lua')
local Theme = require('abyss_theme')
local function same(a,b)
    if a==b then return end
    assert(type(a)==type(b),'input changed state type')
    if type(a)~='table'then assert(a==b,'input changed rules');return end
    for k,v in pairs(a)do same(v,b[k])end
    for k in pairs(b)do assert(a[k]~=nil,'input removed state')end
end

-- This entry is deliberately outside the old-fixture settlement allowlist.
-- Real fixed screen coordinates must not follow the moving card automatically.
local host,ui,panel,event = H.setup({'strike'},{'cultist'})
local battle,card = host.run.combat,panel:GetChild('card1')
local uid,x,y = battle.hand[1].uid,card.x,card.y
assert(card.localScaleX<1,'new hand must still be entering during this live test')
local before = H.F.Combat.copy(battle)
event('card1','down',71,x,y);host:update(0.05)
event('card1','up',71,x,y);event('card1','click',71,x,y)
assert(ui.selected==uid and not ui.busy,'fixed-position first tap during entry was lost')
same(battle,before)
print('PASS live opening input fixed screen tap preserves entering UID and rules')

host,ui,panel,event = H.setup({'defend'},{'cultist'})
battle,card = host.run.combat,panel:GetChild('card1')
uid,x,y = battle.hand[1].uid,card.x,card.y
assert(card.localScaleX<1)
event('card1','down',72,x,y)
event('card1','drag',72,0,80)
event('dragLayer','up',72,0,80)
assert(#battle.hand==0 and battle.discard[1].uid==uid and battle.energy==2 and battle.player.block==5,
    'drag during first entry must command the captured UID exactly once')
event('dragLayer','up',72,0,80)
assert(battle.energy==2 and #battle.discard==1,'late release replayed first entry drag')
print('PASS live opening input entering drag commands one captured UID')

host,ui,panel,event = H.setup({'strike'},{'cultist'})
battle,card = host.run.combat,panel:GetChild('card1')
assert(card.localScaleX<1)
for _=1,80 do host:update(1/60)end
assert(card.localScaleX==1 and card.x~=Theme.layout.drawPile.position[1],'current view settles from real draw pile')
uid,x,y = battle.hand[1].uid,card.x,card.y
event('card1','down',73,x,y);event('card1','up',73,x,y);event('card1','click',73,x,y)
assert(ui.selected==uid)
local hp=battle.enemies[1].hp
event('enemy1','down',74);event('enemy1','up',74);event('enemy1','click',74)
assert(battle.enemies[1].hp==hp-6 and #battle.hand==0 and battle.discard[1].uid==uid)
print('PASS live opening input settled current view targets one committed card')
print('LUA_BATTLE_LIFE_OPENING_INPUT_PASS 3')
