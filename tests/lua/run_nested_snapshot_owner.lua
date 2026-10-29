-- Controlled transaction fixtures, not a natural run or platform acceptance.
-- Commands, paused continuations, reward preparation and revival remain real.
local Run,C,D,S,A=require('abyss_run'),require('abyss_combat'),require('abyss_data'),require('abyss_snapshot'),require('abyss_actor')
local Discard,Actions,Hooks=require('abyss_discard'),require('abyss_card_actions'),require('abyss_relic_hooks')
local slice=... or 'discard'
assert(slice=='discard'or slice=='turn'or slice=='finish','invalid nested-owner fixture slice')
local n,failed=0,0
local function eq(a,b,label)assert(rawequal(a,b),(label or 'value')..': '..tostring(a)..' ~= '..tostring(b))end
local function test(name,fn,group)
 if (group or 'discard')~=slice then return end
 if ABYSS_MUTATION_CASE and ABYSS_MUTATION_CASE~=name then return end
 local ok,why=pcall(fn);n=n+1;if not ok then failed=failed+1 end
 print((ok and 'PASS 'or 'FAIL ')..name..(ok and ''or ': '..tostring(why)))
end
local function unchanged(root)
 local saved,pending={}, {root}
 while #pending>0 do
  local object=table.remove(pending)
  if not saved[object]then
   local fields={};saved[object]=fields
   for key,value in next,object do
    fields[key]=value
    if type(key)=='table'then pending[#pending+1]=key end
    if type(value)=='table'then pending[#pending+1]=value end
   end
  end
 end
 return function()
  for object,fields in next,saved do
   for key,value in next,fields do eq(rawget(object,key),value,'original graph edge')end
   for key,value in next,object do eq(value,rawget(fields,key),'new graph edge')end
  end
 end
end
local function observe(fn)
 local capture=S.capture;local calls,owners=0,{}
 S.capture=function(...)
  calls=calls+1;local result=table.pack(capture(...))
  if result[2]then owners[#owners+1]=result[2]end
  return table.unpack(result,1,result.n)
 end
 local result=table.pack(pcall(fn));S.capture=capture
 if not result[1]then error(result[2],0)end
 return calls,owners
end
local function expired(owners,state)for _,owner in ipairs(owners)do eq(S.ownedRestore(owner,state),nil,'parent owner expires')end end
local function held(s,id)for _,card in ipairs(s.hand)do if card.cardId==id then return card end end;error('missing '..id)end
local function fixture(choice)
 local r=Run.new(D,'42',choice and {character='silent',experimental=true}or nil)
 local ids=choice and {'survivor','strike_green','defend_green'}or {'strike','defend'}
 r.deck={};for i,id in ipairs(ids)do r.deck[i]={uid=i,cardId=id,upgraded=false}end;r.nextDeckUid=#ids+1
 assert(Run.startCombat(r,'cultist_solo'));local s=r.combat
 if choice then assert(Run.play(r,held(s,'survivor').uid));assert(s.pendingDiscard)end
 return r,s
end
local function aliases(r,s)
 local key={enabled=false};key.self=key
 r.nestedOwnerAliases={battle=s,player=s.player,hand=s.hand,draw=s.draw,events=s.events,
  data=r.data,catalog=s.catalog,random=s.shuffleRng or s.cardRandomRng}
 r[key]={key=key,player=s.player};return key
end
local function mutate(r,s,key)
 r.gold=17;r.data.cards.cards[1].name='NESTED OWNER RUN MUTATION'
 s.catalog.cards.strike.name='NESTED OWNER CATALOG MUTATION'
 s.events[1].frame.player.hp=123;s.events[1].extra={changed=true}
 key.enabled=true;key.extra={};r[key].player={};r.added={battle=s}
 for _,root in ipairs({r,s})do for _,value in pairs(root)do
  if type(value)=='table'and value.counter~=nil and value.primitive then value.counter=value.counter+1 end
 end end
end
local function choose(r,s,owner)
 return C.chooseDiscard(s,{held(s,'strike_green').uid},s.pendingDiscard.token,nil,owner)
end

test('Run discard captures one exact parent and resumes the real continuation',function()
 local r,s=fixture(true);local pending=s.pendingDiscard;local target=held(s,'strike_green')
 local calls,owners=observe(function()assert(Run.chooseDiscard(r,{target.uid},pending.token,r.combatGeneration))end)
 eq(calls,1,'one full Run preimage');eq(#owners,1);expired(owners,s)
 eq(s.pendingDiscard,nil);eq(s.pendingPlay,nil);eq(s.actionQueue,nil)
 local discarded=false;for _,card in ipairs(s.discard)do if card==target then discarded=true end end;assert(discarded)
 assert(Run.play(r,held(s,'defend_green').uid))
end)
test('real nonqueued discard retains standalone rollback and reuses only its exact owner',function()
 local r,s=fixture();assert(Discard.begin(s,1));eq(s.actionQueue,nil)
 local pending=s.pendingDiscard;local uid=held(s,'strike').uid;local restore,owner=S.capture(r,s)
 local calls=observe(function()assert(C.chooseDiscard(s,{uid},pending.token,nil,owner))end)
 eq(calls,0);eq(S.ownedRestore(owner,s),nil);eq(s.pendingDiscard,nil);restore()
 calls=observe(function()assert(C.chooseDiscard(s,{uid},pending.token))end);eq(calls,1)
end)
test('bare discard captures while an exact owner consumes once and reused owner falls back',function()
 local r,s=fixture(true);local check=unchanged(r);local restore,owner=S.capture(r,s)
 local calls=observe(function()assert(choose(r,s,owner))end);eq(calls,0,'exact owner avoids only nested capture')
 eq(S.ownedRestore(owner,s),nil);eq(S.release(owner),false);restore();check()
 calls=observe(function()assert(choose(r,s,owner))end);eq(calls,1,'used owner cannot omit standalone savepoint')
 restore();check();calls=observe(function()assert(choose(r,s))end);eq(calls,1,'bare discard savepoint')
end)
test('forged released and cross-battle discard owners retain independent rollback',function()
 local r,s=fixture(true);local restore=S.capture(r)
 local other,battle=fixture();local _,foreign=S.capture(other,battle)
 local _,released=S.capture(r,s);assert(S.release(released))
 for _,owner in ipairs({function()error('forged owner executed')end,released,foreign})do
  local calls=observe(function()assert(choose(r,s,owner))end);eq(calls,1,'invalid owner must capture')
  restore()
 end
 eq(S.ownedRestore(foreign,s),nil);eq(S.release(foreign),true,'wrong battle did not consume foreign owner')
end)
test('Run end turn captures once and exact bare owners consume once with safe invalid fallback',function()
 local r,s=fixture();local turn=s.turn
 local calls,owners=observe(function()assert(Run.endTurn(r))end)
 eq(calls,1,'one full Run end-turn preimage');eq(#owners,1);expired(owners,s)
 eq(s.turn,turn+1);eq(s.phase,'player');eq(r.phase,'combat')
 local restore,owner=S.capture(r,s)
 calls=observe(function()assert(C.endTurn(s,owner))end);eq(calls,0);eq(S.ownedRestore(owner,s),nil)
 restore();calls=observe(function()assert(C.endTurn(s,owner))end);eq(calls,1,'reused owner falls back');restore()
 local _,released=S.capture(r,s);assert(S.release(released))
 local other,battle=fixture();local _,foreign=S.capture(other,battle)
 for _,invalid in ipairs({function()error('forged owner executed')end,released,foreign})do
  calls=observe(function()assert(C.endTurn(s,invalid))end);eq(calls,1,'invalid end-turn owner captures');restore()
 end
 eq(S.release(foreign),true)
 calls=observe(function()assert(C.endTurn(s))end);eq(calls,1,'bare end turn savepoint')
end,'turn')
test('stale generation token and pending end-turn refusals expire every parent without mutation',function()
 local r,s=fixture(true);local check=unchanged(r);local pending=s.pendingDiscard
 local calls=observe(function()eq(Run.chooseDiscard(r,{held(s,'strike_green').uid},pending.token,r.combatGeneration+1),false)end)
 eq(calls,0);check()
 local owners;calls,owners=observe(function()eq(Run.chooseDiscard(r,{held(s,'strike_green').uid},pending.token+1,r.combatGeneration),false)end)
 eq(calls,1);expired(owners,s);check()
 calls,owners=observe(function()eq(Run.endTurn(r),false)end);eq(calls,1);expired(owners,s);check()
 local clean,battle=fixture();battle.pendingPotionChoice={token=5};local verify=unchanged(clean)
 calls,owners=observe(function()eq(Run.endTurn(clean),false)end);eq(calls,1);eq(#owners,1);expired(owners,battle);verify()
end,'turn')
for _,kind in ipairs({'discard','turn'})do
 test(kind..' child throw restores the complete parent graph before propagating the original value',function()
  local r,s=fixture(kind=='discard');local key=aliases(r,s);local check=unchanged(r);local marker={kind=kind}
  local api,name,hook=kind=='discard'and Discard or C,kind=='discard'and 'choose'or 'startPlayerTurn'
  hook=api[name];local commandName=kind=='discard'and 'chooseDiscard'or 'endTurn';local command=C[commandName]
  local childRestored=false
  api[name]=function(...)local result=table.pack(hook(...));mutate(r,s,key);error(marker,0);return table.unpack(result,1,result.n)end
  C[commandName]=function(...)
   local called,result=pcall(command,...)
   if not called then check();childRestored=true;error(result,0)end
   return result
  end
  local calls,owners=observe(function()
   local called,result
   if kind=='discard'then called,result=pcall(Run.chooseDiscard,r,{held(s,'strike_green').uid},s.pendingDiscard.token,r.combatGeneration)
   else called,result=pcall(Run.endTurn,r)end
   api[name],C[commandName]=hook,command
   eq(called,false);eq(result,marker);assert(childRestored,'child must restore full Run, not just battle');check()
  end)
  eq(calls,1);expired(owners,s)
  if kind=='discard'then assert(Run.chooseDiscard(r,{held(s,'strike_green').uid},s.pendingDiscard.token,r.combatGeneration))else assert(Run.endTurn(r))end
 end,'turn')
end
local function terminalFixture(kind)
 local r=Run.new(D,'42',{character='watcher',experimental=true})
 if kind=='turn'then
  r.deck={{uid=1,cardId='omega',upgraded=true},{uid=2,cardId='defend_purple',upgraded=false}};r.nextDeckUid=3
  assert(Run.startCombat(r,'cultist_solo'));assert(Run.play(r,held(r.combat,'omega').uid))
  return r,r.combat,function()return Run.endTurn(r)end
 end
 assert(Run.startCombat(r,'cultist_solo'));r.hp,r.maxHp=1,7
 local s=C.new(r.data,{seed=42,enemies={'corrupt_heart'},deck={},hp=1,maxHp=7,enableStances=true,
  beforeOpeningDraw=function(state)Hooks.bindBattle(state,r.relics,r.relicCounters);return true end})
 r.combat=s;s.combatGeneration=r.combatGeneration
 local played=Actions.fresh(C,s,'acrobatics');local selected=Actions.fresh(C,s,'strike')
 s.hand={played,selected};s.draw={Actions.fresh(C,s,'defend'),Actions.fresh(C,s,'defend')};s.discard={};s.energy=20
 assert(Run.play(r,played.uid));local pending=assert(s.pendingDiscard)
 return r,s,function()return Run.chooseDiscard(r,{s.hand[1].uid},pending.token,r.combatGeneration)end
end
for _,kind in ipairs({'discard','turn'})do
 test(kind..' late real finish refusal and throw restore aliases RNG data and frames then retry',function()
  local r,s,command=terminalFixture(kind);local key=aliases(r,s);local check=unchanged(r);local original=Run.finishCombat
  for _,mode in ipairs({'false','throw'})do
   local marker={kind=kind,mode=mode};local reached=false;local finishCaptures=0
   Run.finishCombat=function(...)
    -- Settlement has its own pre-existing Run savepoint. Observe it directly;
    -- only the command's duplicate Combat savepoint belongs to this change.
    local capture=S.capture
    S.capture=function(root,target,...)
     eq(root,r,'real finish captures the whole Run');eq(target,nil,'finish does not borrow command owner')
     finishCaptures=finishCaptures+1;return capture(root,target,...)
    end
    local results=table.pack(pcall(original,...));S.capture=capture
    if not results[1]then error(results[2],0)end;assert(results[2]);reached=true
    eq(r.phase,kind=='discard'and 'defeat'or 'reward')
    mutate(r,s,key);if mode=='throw'then error(marker,0)end;return false,'late_nested_refusal'
   end
   local calls,owners=observe(function()
    local called,ok,why=pcall(command);Run.finishCombat=original;assert(reached,'real finish must execute')
    if mode=='throw'then eq(called,false);eq(ok,marker)else eq(called,true);eq(ok,false);eq(why,'late_nested_refusal')end
    check()
   end)
   eq(finishCaptures,1,'existing independent settlement savepoint retained')
   eq(calls,2,'one command parent plus exactly one real finish savepoint');eq(#owners,1);expired(owners,s)
  end
  assert(command());eq(r.phase,kind=='discard'and 'defeat'or 'reward');eq(s.pendingDiscard,nil)
 end,'finish')
end
test('real first-form revival remains nonterminal across a parent-owned Run end turn',function()
 local r=Run.new(D,'42',{experimental=true});assert(Run.startCombat(r,'cultist_solo'))
 local s=C.new(r.data,{seed=42,cardRandomSeed='42',enemies={'awakened_one'},deck={},hp=500,maxHp=500})
 r.combat=s;r.hp,r.maxHp=500,500;s.combatGeneration=r.combatGeneration
 local enemy=s.enemies[1];C.damage(s,s.player,enemy,1000,true);assert(enemy.halfDead);eq(C.outcome(s),nil)
 local hp,turn=s.player.hp,s.turn
 local calls,owners=observe(function()assert(Run.endTurn(r))end);eq(calls,1);expired(owners,s)
 eq(r.phase,'combat');eq(r.victories,0);eq(s.turn,turn+1);eq(s.player.hp,hp)
 eq(enemy.hp,300);eq(enemy.halfDead,false);eq(enemy.intents[enemy.intentIndex].id,'dark_echo')
 assert(Run.endTurn(r));eq(s.player.hp,hp-40)
end,'finish')
print('RUN_NESTED_SNAPSHOT_OWNER '..slice..' '..n..' groups; '..failed..' failed');assert(n>0 and failed==0)
