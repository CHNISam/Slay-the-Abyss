package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local A=require('abyss_actor')
-- Existing injected-retaliate API permits a context whose player is not a
-- constructed combat actor. Adding a death guard must not reject missing HP.
local context={player={}}
local target={hp=10}
local calls=0
A.resolveDamageReactions(context,{{source='source',target=target,amount=4}},
  function(state,source,victim,amount)
    assert(state==context and source=='source' and victim==target and amount==4)
    calls=calls+1;victim.hp=victim.hp-amount
  end)
assert(calls==1 and target.hp==6,'missing-HP context must retain its one existing callback')
print('PASS missing-player-hp callback count=1 targetHP=6')
