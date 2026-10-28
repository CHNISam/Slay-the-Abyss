-- Full-graph rollback ownership, not a selective immutable-data exemption.
local Run,C,D,S,A=require('abyss_run'),require('abyss_combat'),require('abyss_data'),require('abyss_snapshot'),require('abyss_actor')
local n,failed=0,0
local function eq(a,b)assert(rawequal(a,b),tostring(a)..' ~= '..tostring(b))end
local function test(name,fn)local ok,why=pcall(fn);n=n+1;if not ok then failed=failed+1 end
 print((ok and 'PASS 'or 'FAIL ')..name..(ok and ''or ': '..tostring(why)))end
local function unchanged(root)
 local saved={}
 local function visit(t)
  if type(t)~='table'or saved[t]then return end
  local values={};saved[t]=values
  for k,v in next,t do values[k]=v;visit(k);visit(v)end
 end
 visit(root)
 return function()
  for original,values in next,saved do
   for k,v in next,values do eq(rawget(original,k),v)end
   for k,v in next,original do eq(v,rawget(values,k))end
  end
 end
end
local function fixture(card,extra)
 local r=Run.new(D,'42');r.deck={{uid=1,cardId=card or 'strike',upgraded=false}};r.nextDeckUid=2
 for _,id in ipairs(extra or {})do r.deck[#r.deck+1]={uid=r.nextDeckUid,cardId=id,upgraded=false};r.nextDeckUid=r.nextDeckUid+1 end
 assert(Run.startCombat(r,'cultist_solo'));local s=r.combat;local held
 for _,c in ipairs(s.hand)do if c.cardId==(card or 'strike')then held=c end end
 return r,s,assert(held)
end
local function observe(fn)
 local old=S.capture;local calls,owners=0,{}
 S.capture=function(...)
  calls=calls+1;local result=table.pack(old(...));if result[2]then owners[#owners+1]=result[2]end
  return table.unpack(result,1,result.n)
 end
 local result=table.pack(pcall(fn));S.capture=old
 if not result[1]then error(result[2],0)end
 return calls,owners
end
local function expired(owners,state)for _,owner in ipairs(owners)do eq(S.ownedRestore(owner,state),nil)end end
local function mutate(r,s,oldEvent)
 r.gold=17;r.data.cards.cards[1].name='MUTATED RUN DATA';s.catalog.cards.strike.name='MUTATED CATALOG'
 oldEvent.frame.player.hp=123;oldEvent.injection={nested=true}
end

test('opaque owner is exact-target single-use, rejects forged equality and expires',function()
 local equal=function()return true end
 local a,b=setmetatable({},{__eq=equal}),setmetatable({},{__eq=equal});assert(a==b)
 local key={};local root={target=a,key=key};root.self=root;root[key]={alias=a};a.parent=root
 local check=unchanged(root);local restore,owner=S.capture(root,a)
 eq(restore,owner);eq(S.ownedRestore({},a),nil);eq(S.ownedRestore(function()end,a),nil)
 eq(S.ownedRestore(owner,b),nil);eq(S.ownedRestore(owner,a),restore);eq(S.ownedRestore(owner,a),nil)
 root.new={};root[key].alias=b;a.changed=true;restore();restore();check();eq(S.release(owner),false)
 local _,fresh=S.capture(root,a);eq(S.release(fresh),true);eq(S.release(fresh),false);eq(S.ownedRestore(fresh,a),nil)
 local ok=pcall(S.capture,root,{});eq(ok,false)
end)
test('ordinary native Run play captures once, bare Combat play still owns its snapshot',function()
 local r,s,c=fixture();local count,owners=observe(function()assert(Run.play(r,c.uid,1))end)
 eq(count,1);eq(#owners,1);expired(owners,s)
 local _,bare,card=fixture();local bareCount=observe(function()assert(C.play(bare,card.uid,1))end);eq(bareCount,1)
end)
test('queued Run play reuses only its exact outer full graph',function()
 local r,s,c=fixture('defend');s.experimentalMechanics=true
 local d=s.catalog.cards.defend;d.experimental=true;d.runNativeABI=nil
 local count,owners=observe(function()assert(Run.play(r,c.uid))end)
 eq(count,1);eq(#owners,1);expired(owners,s);eq(s.player.block,5)
end)
test('forged stale and wrong-battle tokens fall back to ordinary Combat snapshots',function()
 for _,kind in ipairs({'forged','stale','other'})do
  local r,s,c=fixture();local token
  if kind=='forged'then token=function()error('forged restore must never execute')end
  elseif kind=='stale'then local restore;restore,token=S.capture(r,s);assert(S.release(token))
  else local other,battle=fixture();local restore;restore,token=S.capture(other,battle)end
  local count=observe(function()assert(C.play(s,c.uid,1,nil,token))end);eq(count,1);S.release(token)
 end
end)
test('paused choice expires parent capability and continuation retains a fresh rollback',function()
 local r,s,c=fixture('burning_pact',{'strike','defend'});local target
 for _,card in ipairs(s.hand)do if card.cardId=='strike'then target=card end end;assert(target)
 local _,owners=observe(function()assert(Run.play(r,c.uid))end);assert(s.pendingHandChoice);expired(owners,s)
 local pending=s.pendingHandChoice;local count=observe(function()
  assert(Run.chooseHand(r,{target.uid},pending.token,r.combatGeneration))
 end)
 assert(count>=1,'continuation must retain its own snapshot');eq(s.pendingHandChoice,nil);eq(s.exhaust[1],target)
end)
test('nested native failure restores Run data catalog old frames aliases and nonstring identity',function()
 local r,s,c=fixture();local check=unchanged(r);local entry=s.events[1];assert(entry and entry.frame)
 local damage,play=A.damage,C.play;local marker={};local childRestored=false
 A.damage=function(...)local value=damage(...);mutate(r,s,entry);error(marker,0);return value end
 C.play=function(...)
  local called,result=pcall(play,...)
  if not called then check();childRestored=true;error(result,0)end
  return result
 end
 local called,why=pcall(Run.play,r,c.uid,1);A.damage,C.play=damage,play
 eq(called,false);eq(why,marker);assert(childRestored);check()
 assert(Run.play(r,c.uid,1))
end)
test('late reward refusal restores every metadata and historical-frame edge and retries',function()
 local r,s,c=fixture();local enemy=s.enemies[1];C.damage(s,s.player,enemy,enemy.hp+enemy.block-6,true)
 local check=unchanged(r);local entry=s.events[1];local finish=Run.finishCombat;local reached=false
 Run.finishCombat=function(...)
  local ok,why=finish(...);assert(ok,why);reached=true;mutate(r,s,entry);return false,'late_metadata_refusal'
 end
 local called,ok,why=pcall(Run.play,r,c.uid,1);Run.finishCombat=finish
 eq(called,true);eq(ok,false);eq(why,'late_metadata_refusal');assert(reached);check()
 assert(Run.play(r,c.uid,1));eq(r.phase,'reward')
end)
test('preflight refusal releases an unconsumed owner and preserves all original graph edges',function()
 local r,s,c=fixture();local check=unchanged(r)
 local count,owners=observe(function()local ok,why=Run.play(r,c.uid,99);eq(ok,false);eq(why,'invalid_target')end)
 eq(count,1);eq(#owners,1);expired(owners,s);check()
end)
test('committed command replay creates no owner and cannot reuse the previous token',function()
 local r,s,c=fixture();r.originalCommands={}
 local _,owners=observe(function()assert(Run.play(r,c.uid,1,'owner-once'))end);expired(owners,s)
 local check=unchanged(r);local count=observe(function()
  local ok,why=Run.play(r,c.uid,1,'owner-once');eq(ok,true);eq(why,'already_committed')
 end)
 eq(count,0);expired(owners,s);check()
end)
print('RUN_PLAY_SNAPSHOT_OWNER '..n..' groups; '..failed..' failed');assert(failed==0)
