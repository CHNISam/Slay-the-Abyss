package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,D,A,T,H=require('abyss_combat'),require('abyss_data'),require('abyss_actor'),
 require('abyss_card_triggers'),require('abyss_corrupt_heart')
local count=0
local function eq(a,b,label)assert(a==b,(label or 'value')..': '..tostring(a)..' ~= '..tostring(b))end
local function test(name,fn)fn();count=count+1;print('PASS Heart Envenom '..count..' '..name)end
local function fresh(advanced)
 local data=T.withCards(D,'silent')
 local s=C.new(data,{enemies={'corrupt_heart'},deck={'strike','strike','strike'},
  seed=42,cardRandomSeed='42',enableStances=advanced})
 local e=s.enemies[1];assert(T.apply(s,'envenom',1));A.applyPower(s,e,'artifact',1,e)
 return s,e
end
for _,advanced in ipairs({false,true})do
 test((advanced and 'advanced'or 'native')..' zero then positive budgets construct only eligible Poison actions',function()
  local s,e=fresh(advanced);local old=T.onAttack;local constructed=0
  T.onAttack=function(...)
   local action=old(...);if action then constructed=constructed+1 end;return action
  end
  local ok,why=pcall(function()
   e.statuses.invincible=0;assert(C.play(s,s.hand[1].uid,1))
   eq(e.hp,750);eq(e.statuses.artifact,1,'zero cap must not spend Artifact')
   eq(e.statuses.poison,nil);eq(e.statuses.invincible,0);eq(constructed,0,'zero cap must not construct Poison')
   e.statuses.invincible=1;assert(C.play(s,s.hand[1].uid,1))
   eq(e.hp,749);eq(e.statuses.artifact,0);eq(e.statuses.poison,nil)
   eq(e.statuses.invincible,0);eq(constructed,1)
   e.statuses.invincible=1;assert(C.play(s,s.hand[1].uid,1))
   eq(e.hp,748);eq(e.statuses.poison,1);eq(e.statuses.invincible,0);eq(constructed,2)
   eq(#s.discard,3)
  end)
  T.onAttack=old;assert(ok,why)
 end)
end
test('preview is pure and committed damage spends the shared budget exactly once',function()
 local s,e=fresh(false)
 eq(H.incomingAmount(e,6),6);eq(H.incomingAmount(e,6),6);eq(e.statuses.invincible,300)
 eq(C.damage(s,s.player,e,6,false),6);eq(e.statuses.invincible,294);eq(e.statuses.artifact,0)
 local other={ai={kind='other'},statuses={invincible=0}}
 eq(H.incomingAmount(other,6),6);eq(H.capDamage(other,6),6);eq(other.statuses.invincible,0)
 eq(H.incomingAmount({ai={kind='corrupt_heart'},statuses={}},6),6)
end)
test('fully blocked attack leaves both Invincible and Artifact untouched',function()
 local s,e=fresh(false);e.statuses.invincible=1;e.block=6
 assert(C.play(s,s.hand[1].uid,1));eq(e.hp,750);eq(e.block,0)
 eq(e.statuses.invincible,1);eq(e.statuses.artifact,1);eq(e.statuses.poison,nil)
end)
print('HEART_ENVENOM_PASS '..count..' controlled offline groups; not natural/live evidence')
