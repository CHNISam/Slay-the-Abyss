package.path='src/lua/?.lua;build/lua/?.lua;tests/lua/helpers/?.lua;'..package.path
local H=require('run_catalog');local Run,C=H.Run,H.C
do
 local r,s=H.new({'armaments','defend_blue'},'watcher');H.play(r,'armaments')
 assert(H.held(s,'defend_blue').upgraded and s.player.block==5)
end
do
 local r,s=H.new({'havoc','strike_blue'},'silent');H.arrange(s,{hand={'havoc'},draw={'strike_blue'}})
 local hp=s.enemies[1].hp;local rng=s.cardRandomRng.counter;H.play(r,'havoc')
 assert(s.enemies[1].hp==hp-6 and s.exhaust[1].cardId=='strike_blue'and s.cardRandomRng.counter==rng+1)
end
do
 local r,s=H.new({'dual_wield','strike_blue','defend_green'},'watcher')
 local original=H.held(s,'strike_blue');H.play(r,'dual_wield')
 local count=0;local copy;for _,c in ipairs(s.hand)do if c.cardId=='strike_blue'then count=count+1;if c~=original then copy=c end end end
 assert(count==2 and copy.uid~=original.uid and copy.uuid~=original.uuid and not copy.deckUid)
end
do
 local r,s=H.new({'infernal_blade'},'defect');local counter=s.cardRandomRng.counter;H.play(r,'infernal_blade')
 assert(#s.hand==1 and C.cardDefinition(s,s.hand[1]).type=='attack'and s.hand[1].costForTurn==0)
 assert(not s.hand[1].deckUid and s.cardRandomRng.counter>counter)
end
print('RUN_CARD_CATALOG_NATIVE_CHOICES_PASS real Armaments/Havoc/DualWield/InfernalBlade in other classes with physical UID/UUID and source RNG')
