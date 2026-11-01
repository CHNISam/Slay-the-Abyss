package.path='src/lua/?.lua;build/lua/?.lua;tests/lua/helpers/?.lua;'..package.path
local H=require('run_catalog');local Run,C=H.Run,H.C
do
 local r,s=H.new({'searing_blow'},'watcher');local c=H.held(s,'searing_blow')
 assert(C.upgrade(s,c));assert(C.upgrade(s,c));local hp=s.enemies[1].hp;H.play(r,'searing_blow',1)
 assert(s.enemies[1].hp==hp-21 and c.upgrades==2)
end
do
 local r,s=H.new({'double_tap','strike_blue'},'silent');H.play(r,'double_tap');local hp=s.enemies[1].hp
 H.play(r,'strike_blue',1);assert(s.enemies[1].hp==hp-12 and(s.player.statuses.double_tap or 0)==0,
  'actual double tap damage='..(hp-s.enemies[1].hp)..' remaining='..tostring(s.player.statuses.double_tap))
 assert(#s.cardsPlayedThisTurn==3,'native double tap must replay actual foreign attack lifecycle')
end
do
 local r,s=H.new({'feed'},'defect');s.enemies[1].hp=10;local max=r.maxHp;H.play(r,'feed',1)
 assert(r.maxHp==max+3 and s.player.maxHp==max+3 and r.phase=='reward',
  'Feed permanent='..r.maxHp..' battle='..s.player.maxHp..' prior='..max..' phase='..r.phase)
end
do
 local r,s=H.new({'juggernaut','defend_purple'},'silent');H.play(r,'juggernaut');local hp=s.enemies[1].hp
 H.play(r,'defend_purple');assert(s.enemies[1].hp==hp-5 and s.player.block==5)
end
-- Sword Boomerang is covered with acquired Rage and its three samples by the
-- acquisition fixture, rather than replacing this true native random attack.
print('RUN_CARD_CATALOG_NATIVE_COMBAT_PASS real SearingBlow/DoubleTap/Feed/Juggernaut cross-color combat and permanent resources')
