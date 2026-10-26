package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local A=require('abyss_actor')
local C=require('abyss_combat')
local data=require('abyss_data')
local total,failed=0,0
local function eq(a,b,label) assert(a==b,(label or 'value')..': expected '..tostring(b)..', got '..tostring(a)) end
local function test(name,fn)
  total=total+1;local ok,why=pcall(fn)
  if not ok then failed=failed+1 end
  print((ok and 'PASS ' or 'FAIL ')..total..' '..name..(ok and '' or ' | '..tostring(why)))
end
local function battle()
  local s=C.new(data,{deck={},hp=10,enemies={'cultist'},seed=99})
  s.events={};s.enemies[1].hp=20
  return s,s.enemies[1]
end
-- Break caught: missing player-death guard starts a new queued damage action.
test('a dead player cannot start an already queued reflection',function()
  local s,e=battle();s.player.hp=0
  A.resolveDamageReactions(s,{{source=s.player,target=e,amount=4}},C.retaliate)
  eq(e.hp,20,'target health');eq(#s.events,0,'no post-death event')
end)
-- Break caught: checking only at entry misses death caused by an earlier TOP action.
test('death during reverse-TOP drain stops the remaining action',function()
  local s,e=battle();s.player.hp=3
  A.resolveDamageReactions(s,{
    {source=s.player,target=e,amount=4},
    {source=e,target=s.player,amount=3},
  },C.retaliate)
  eq(s.player.hp,0,'first TOP action killed player')
  eq(e.hp,20,'remaining queued action suppressed')
  eq(#s.events,1,'only lethal player damage event')
end)
-- Break caught: confusing dead source or victory with player death cancels valid THORNS.
test('a dead last enemy can still own damage while the player lives',function()
  local s,e=battle();e.hp=0
  A.resolveDamageReactions(s,{{source=e,target=s.player,amount=3}},C.retaliate)
  eq(s.player.hp,7,'retained dead-owner reaction')
  eq(#s.events,1,'retained damage event')
end)
-- These are narrow compatibility checks of the existing injected-retaliation
-- API, not full-Combat calls with a missing state. There is no rule substitution.
-- Break caught: a new unconditional state/player dereference rejects that API.
test('nil state preserves injected reverse-TOP damage delivery',function()
  local target={hp=10};local amounts={}
  A.resolveDamageReactions(nil,{
    {source='one',target=target,amount=3},
    {source='two',target=target,amount=1},
  },function(state,source,victim,amount)
    eq(state,nil);eq(victim,target)
    amounts[#amounts+1]=amount;victim.hp=victim.hp-amount
  end)
  eq(target.hp,6);eq(amounts[1],1);eq(amounts[2],3)
end)
test('state without player preserves injected damage delivery',function()
  local state={marker=true};local target={hp=10}
  A.resolveDamageReactions(state,{{source='source',target=target,amount=4}},
    function(received,source,victim,amount)
      eq(received,state);eq(source,'source');eq(victim,target)
      victim.hp=victim.hp-amount
    end)
  eq(target.hp,6)
end)
test('empty reactions remain a no-op with nil or missing-player state',function()
  eq(A.resolveDamageReactions(nil,{}),nil)
  eq(A.resolveDamageReactions({},{}),nil)
end)
print('RESULT '..total..' guard boundaries, '..failed..' failed')
assert(failed==0,'death guard boundary failure')
