package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local A=require('abyss_actor')
local state={player={}};local called=0
local ok,why=pcall(A.resolveDamageReactions,state,{{source='source',target='target',amount=1}},
  function(s,source,target,amount)
    assert(s==state and source=='source' and target=='target' and amount==1)
    called=called+1
  end)
print('OBSERVATION minimal player without hp: ok='..tostring(ok)..' callbacks='..called..' error='..tostring(why))
assert(ok and called==1,'baseline-compatible callback behavior changed for player without hp; contract relevance must be assessed separately')
