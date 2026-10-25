package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Actions=require('abyss_card_actions')
local C,H,R,D=require('abyss_combat'),require('abyss_relic_hooks'),require('abyss_sts_random'),require('abyss_data')
local function battle()
 local s=assert(C.new(D,{seed=42,deck={'strike'},enemies={'cultist'}}));H.bindBattle(s,{'warped_tongs'})
 s.shuffleRng=R.fromSeed('42');s.hand={};s.discard={};return s
end
local s=battle()
s.draw={{cardId='searing_blow',uid=1,upgraded=true,upgrades=4},{cardId='defend',uid=2,upgraded=true},
 {cardId='burn',uid=3},{cardId='strike',uid=4}}
local expected=R.cloneState(s.shuffleRng);local candidates={4,1};R.shuffle(expected,candidates)
Actions.enqueue(s,{op='draw',value=4});H.enqueuePostDraw(s);Actions.enqueue(s,{op='energy',value=1})
assert(s.cardActions[1].effect.op=='draw' and s.cardActions[2].effect.op=='relicUpgradeRandomHand' and s.cardActions[3].effect.op=='energy')
local trace={};local draw,upgrade=C.draw,C.upgrade
C.draw=function(state,n)trace[#trace+1]='draw';return draw(state,n)end
C.upgrade=function(state,card)trace[#trace+1]='upgrade:'..card.uid;return upgrade(state,card)end
local beforeEnergy=s.energy;local ok,why=pcall(Actions.drain,C,s);C.draw,C.upgrade=draw,upgrade;assert(ok,why)
assert(trace[1]=='draw' and trace[2]=='upgrade:'..candidates[1] and #trace==2,table.concat(trace,','))
assert(s.energy==beforeEnergy+1 and #s.hand==4 and s.shuffleRng.counter==1)
assert(R.randomLongHex(s.shuffleRng)==R.randomLongHex(expected))
local singleton=battle();singleton.hand={{cardId='searing_blow',uid=9,upgraded=true,upgrades=3}}
local original=singleton.hand[1];H.enqueuePostDraw(singleton);Actions.drain(C,singleton)
assert(singleton.hand[1]==original and original.upgrades==4 and singleton.shuffleRng.counter==1)
for _,hand in ipairs({{},{{cardId='burn',uid=10}},{{cardId='defend',uid=11,upgraded=true}}})do
 local empty=battle();empty.hand=hand;local before=R.snapshot(empty.shuffleRng)
 H.enqueuePostDraw(empty);Actions.drain(C,empty)
 assert(empty.shuffleRng.counter==before.counter)
end
local turned=battle();turned.draw={{cardId='searing_blow',uid=12,upgraded=true,upgrades=2}}
turned.rules.player.drawPerTurn=1 -- isolate relic shuffle from empty-deck shuffle
assert(C.startPlayerTurn(turned))
assert(#turned.hand==1 and turned.hand[1].upgrades==3 and turned.shuffleRng.counter==1,'actual post-draw turn hook missing')
assert(D.cards.starter_deck.cards[1]=='strike','permanent starter data changed')
print('LUA_WARPED_TONGS_PASS BOTTOM post-draw; shuffleRng; singleton and repeated Searing Blow; empty zero consumption')
