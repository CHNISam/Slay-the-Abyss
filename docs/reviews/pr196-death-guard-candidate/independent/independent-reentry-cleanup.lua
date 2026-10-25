package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local A=require('abyss_actor')
local C=require('abyss_combat')
local R=require('abyss_run')
local Q=require('abyss_card_actions')
local data=require('abyss_data')
local n,failed=0,0
local function eq(a,b,label) assert(a==b,(label or 'value')..': expected '..tostring(b)..', got '..tostring(a)) end
local function check(name,fn)
  n=n+1; local ok,why=pcall(fn); if not ok then failed=failed+1 end
  print((ok and 'PASS ' or 'FAIL ')..n..' '..name..(ok and '' or ' | '..tostring(why)))
end
local function hit(label) return {source=label,target={},amount=1} end
local function battle(enemies)
  local s=C.new(data,{deck={},hp=30,enemies=enemies or {'cultist'},seed=99})
  s.events={};return s
end
check('nested live callbacks keep inner TOP before outer tail and preserve input arrays',function()
  local s={player={hp=10}};local outer={hit('tail'),hit('outer')};local inner={hit('inner1'),hit('inner2')}
  local order={};local callback
  callback=function(received,source,target,amount)
    eq(received,s);eq(amount,1);order[#order+1]=source
    if source=='outer' then A.resolveDamageReactions(s,inner,callback) end
  end
  A.resolveDamageReactions(s,outer,callback)
  eq(table.concat(order,','),'outer,inner2,inner1,tail');eq(#outer,2);eq(#inner,2)
  eq(s.drainingCardActions,nil);eq(s.resolvingEffects,nil)
end)
check('nested lethal callback stops both inner and outer remaining items',function()
  local s={player={hp=1}};local order={};local callback
  callback=function(received,source)
    order[#order+1]=source
    if source=='outer' then A.resolveDamageReactions(s,{hit('inner-tail'),hit('kill')},callback)
    elseif source=='kill' then s.player.hp=0 end
  end
  A.resolveDamageReactions(s,{hit('outer-tail'),hit('outer')},callback)
  eq(table.concat(order,','),'outer,kill')
end)
check('death is checked before reading the next queue entry',function()
  local reads=0;local queue=setmetatable({}, {__len=function() return 2 end,
    __index=function() reads=reads+1;error('entry read after death') end})
  A.resolveDamageReactions({player={hp=0}},queue,function() error('callback after death') end)
  eq(reads,0)
end)
check('real retaliation reentry resolves Spore Cloud before the outer tail',function()
  local s=battle({'fungi_beast','cultist'});local dead,alive=s.enemies[1],s.enemies[2]
  dead.hp=1;dead.block=0;alive.hp=20;alive.block=0
  local spore=dead.statuses.spore_cloud;assert(spore and spore>0)
  A.resolveDamageReactions(s,{{source=s.player,target=alive,amount=2},
    {source=s.player,target=dead,amount=1}},C.retaliate)
  eq(dead.hp,0);eq(alive.hp,18);eq(s.player.statuses.vulnerable,spore)
  eq(s.events[1].kind,'status_damage');eq(s.events[1].detail.target,dead.id)
  eq(s.events[2].kind,'status');eq(s.events[2].detail.status,'vulnerable')
  eq(s.events[3].kind,'status_damage');eq(s.events[3].detail.target,alive.id)
end)
check('victory state alone does not suppress dead-source retained damage',function()
  local s=battle();local enemy=s.enemies[1];enemy.hp=0;s.phase='victory'
  A.resolveDamageReactions(s,{{source=enemy,target=s.player,amount=3}},C.retaliate)
  eq(s.player.hp,27);eq(#s.events,1)
end)
check('repeated stopped batch stays inert and does not latch another state',function()
  local s={player={hp=0}};local queue={hit('one')};local calls=0
  local function callback() calls=calls+1 end
  A.resolveDamageReactions(s,queue,callback);A.resolveDamageReactions(s,queue,callback)
  eq(calls,0);eq(#queue,1)
  A.resolveDamageReactions({player={hp=1}},queue,callback);eq(calls,1)
end)
check('callback errors propagate without poisoning a later invocation',function()
  local s={player={hp=1}};local marker={};local calls=0
  local ok,why=pcall(A.resolveDamageReactions,s,{hit('one')},function() error(marker) end)
  eq(ok,false);eq(why,marker)
  A.resolveDamageReactions(s,{hit('two')},function() calls=calls+1 end);eq(calls,1)
end)
local function card(s,id)
  local c={uid=s.nextUid,cardId=id,upgraded=false};s.nextUid=s.nextUid+1;s.hand[#s.hand+1]=c;return c
end
local function guardian()
  local r=R.new(data,'99');r.floor=16;r.deck={};r.relics={};assert(R.startRoomCombat(r,'boss'))
  local s=r.combat;s.energy=20;assert(R.play(r,card(s,'bludgeon').uid,1));assert(R.endTurn(r))
  eq(s.enemies[1].statuses.sharp_hide,3)
  s.hand={};s.draw={};s.discard={};s.exhaust={};s.events={};s.energy=20
  return r,s
end
local function noResidualQueues(s)
  for _,key in ipairs({'drainingCardActions','resolvingEffects','resolvingCard','cardActions','queuedCards','curlUpQueue'}) do
    eq(s[key],nil,key)
  end
  local before=#s.events;Q.drain(C,s);eq(#s.events,before,'no replay on subsequent drain')
end
check('lethal incoming attack leaves no execution locks or replayable card queues',function()
  local r,s=guardian();assert(R.endTurn(r));eq(C.intent(s,1).id,'guardian_7')
  s.player.hp=7;C.addStatus(s.player,'frail',1);s.energy=3
  assert(R.play(r,card(s,'flame_barrier').uid,1));assert(R.endTurn(r))
  eq(r.phase,'defeat');eq(r.rewards,nil);noResidualQueues(s)
  local before=#s.events;eq(R.endTurn(r),false);eq(#s.events,before)
end)
check('final-kill Sharp Hide defeat clears tails but retains physical card in limbo',function()
  local r,s=guardian();local enemy=s.enemies[1];enemy.hp=6;enemy.block=0;s.player.hp=3;s.player.block=0
  C.addStatus(s.player,'double_tap',1);local strike=card(s,'strike')
  assert(R.play(r,strike.uid,1));eq(enemy.hp,0);eq(s.player.hp,0);eq(r.phase,'defeat');eq(r.rewards,nil)
  eq(s.cardInUse,strike);eq(#s.discard,0);eq(#s.exhaust,0);noResidualQueues(s)
end)
print('RESULT '..n..' independent reentry/cleanup cases, '..failed..' failed')
assert(failed==0,'independent death guard review failed')
