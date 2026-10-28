-- Cross-layer LOCAL stress fixture: production definitions, cards, APIs and real
-- room streams, but the Parasite+Mystic party/powers/HP/intents are staged input,
-- not a source encounter, natural campaign, PC oracle or native-client evidence.
package.path='src/lua/?.lua;build/lua/?.lua;tests/lua/?.lua;'..package.path
local C,A,Q,E,D=require('abyss_combat'),require('abyss_actor'),require('abyss_card_actions'),require('abyss_events'),require('abyss_data')
local P,V,Profiles,Run,SR,AI=require('abyss_plated_armor'),require('abyss_original_v4'),require('abyss_original_v4_profiles'),require('abyss_run'),require('abyss_sts_random'),require('abyss_enemy_ai')
local count,failed=0,0
local function eq(a,b,why)assert(a==b,(why or 'value')..': expected '..tostring(b)..', got '..tostring(a))end
local function test(name,fn)local ok,why=pcall(fn);count=count+1;if not ok then failed=failed+1 end;print((ok and 'PASS 'or'FAIL ')..name..(ok and''or': '..tostring(why)))end
local function force(e,id)for i,v in ipairs(e.intents)do if v.id==id then e.intentIndex=i;return v end end;error('missing production intent '..id)end
local function battle(mode,solo)
 local v4=mode~='native' and mode~='advanced';local data=v4 and Profiles.prepare(D,mode)or D
 local streams=Run.roomStreams({runSeed='42'},18)
 local s=C.new(data,{enemies=solo and {'shelled_parasite'}or{'shelled_parasite','mystic'},deck={},seed=42,hp=80,maxHp=80,enableStances=mode=='advanced',roomSeed=streams.seed,roomStreams=streams})
 -- Mode is an asserted engine contract, not a fixture label or imported card pool.
 eq(s.experimentalMechanics==true,mode=='advanced','explicit engine mode')
 eq(s.originalV4~=nil,v4,'V4 owner presence');if v4 then eq(s.originalV4.role,mode,'actual V4 role')end
 eq(s.player.stance,mode=='advanced'and 'Neutral'or nil,'only advanced opts into stances')
 eq(s.actionQueue,nil);eq(s.cardActions,nil)
 local e,m=s.enemies[1],s.enemies[2];local payload=force(e,'life_suck').effects[1];eq(payload.op,'enemyVampireDamage');eq(payload.value,10)
 e.hp=e.maxHp-20;e.block=0;if m then force(m,'heal');m.hp=1 end
 A.applyPower(s,s.player,'plated_armor',0,s.player);A.applyPower(s,s.player,'thorns',5,s.player)
 if v4 then s.originalV4.soften=6;s.originalV4.counter=8 end
 s.events={};return s,e,m,v4
end
local function hooks(specs,fn)
 local saved={};for i,h in ipairs(specs)do saved[i]=h[1][h[2]];h[1][h[2]]=h[3](saved[i])end
 local ok,why=pcall(fn);for i,h in ipairs(specs)do h[1][h[2]]=saved[i]end;assert(ok,why)
end
local function unchanged(root)
 local saved={};local function visit(t)if type(t)~='table'or saved[t]then return end;local values={};saved[t]=values;for k,v in pairs(t)do values[k]=v;visit(k);visit(v)end end;visit(root)
 return function()for t,values in pairs(saved)do for k,v in pairs(values)do eq(t[k],v,'original key '..tostring(k))end;for k,v in pairs(t)do eq(v,values[k],'extra key '..tostring(k))end end end
end
for _,mode in ipairs({'native','advanced','HT','AR','FR','RD'})do
 test(mode..' real card disposal then Vampire heal/Thorns/counter/Roll/zero-Plated then Mystic snapshot',function()
  local s,e,m,v4=battle(mode);local c={cardId='twin_strike',uid=s.nextUid,upgraded=false};s.nextUid=s.nextUid+1;s.hand[#s.hand+1]=c
  local reductions,playerHits,cardOwner=0,0,nil
  local function assertCardOwner(state)
   local owner
   if mode=='advanced'then
    assert(type(state.actionQueue)=='table','advanced card must be owned by AQ')
    eq(state.drainingCardActions,nil);eq(state.cardActions,nil);owner=state.actionQueue
   else
    eq(state.actionQueue,nil);eq(state.drainingCardActions,true,'native/V4 card drain active')
    assert(type(state.cardActions)=='table','native/V4 card must be owned by CardActions');owner=state.cardActions
   end
   if cardOwner then eq(owner,cardOwner,'same real card queue owner')else cardOwner=owner end
  end
  hooks({{C,'damage',function(old)return function(state,source,target,n,...)
   if state==s and source==s.player and target==e then playerHits=playerHits+1;assertCardOwner(state)end
   return old(state,source,target,n,...)
  end end},{P,'apply',function(old)return function(combat,state,effect,...)
   if state==s and effect.op=='platedReduce'and effect.targetId==e.id then
    reductions=reductions+1;assertCardOwner(state);eq(s.cardInUse,nil);local found=false;for _,card in ipairs(s.discard)do found=found or card==c end;assert(found,'real card must dispose before Reduce')
   end;return old(combat,state,effect,...)
  end end}},function()assert(C.play(s,c.uid,1))end)
  eq(playerHits,2);eq(reductions,2);assert(cardOwner);eq(e.statuses.plated_armor,12)
  local before=e.hp;local trace={};local rolls,enemyOwner=0,nil
  local function assertEnemyOwner(state)
   eq(state.actionQueue,nil,'enemy helper never activates AQ');eq(state.drainingCardActions,true,'enemy native drain active')
   assert(type(state.cardActions)=='table','enemy must use the existing CardActions')
   if enemyOwner then eq(state.cardActions,enemyOwner,'same real enemy queue owner')else enemyOwner=state.cardActions end
  end
  hooks({{C,'damage',function(old)return function(state,source,target,n,...)
   if state==s and source==e and target==s.player then assertEnemyOwner(state)end
   return old(state,source,target,n,...)
  end end},{E,'emit',function(old)return function(state,kind,detail)
   local result=old(state,kind,detail)
   if state==s and type(detail)=='table'then
    if kind=='heal'and detail.target==e.id then trace[#trace+1]=detail.source==e.id and 'heal' or 'party'
    elseif kind=='status_damage'and detail.target==e.id then trace[#trace+1]=detail.amount==5 and 'thorns' or 'counter'end
   end;return result
  end end},{AI,'afterAction',function(old)return function(state,owner,...)
   if state==s and owner==e then assertEnemyOwner(state);trace[#trace+1]='roll';rolls=rolls+1 end;return old(state,owner,...)
  end end},{P,'apply',function(old)return function(combat,state,effect,...)
   if state==s and effect.op=='platedReduce'and effect.targetId==s.player.id then assertEnemyOwner(state);trace[#trace+1]='reduce'end;return old(combat,state,effect,...)
  end end}},function()assert(C.endTurn(s))end)
  eq(table.concat(trace,','),v4 and 'heal,thorns,counter,roll,reduce,party'or'heal,thorns,roll,reduce,party')
  eq(rolls,1);eq(s.player.hp,v4 and 76 or 70);eq(e.hp,before+(v4 and 4 or 10)-5-(v4 and 8 or 0)+16);eq(m.hp,17)
  eq(s.player.statuses.plated_armor,nil);eq(e.block,12);eq(s.cardActions,nil);eq(s.actionQueue,nil);eq(s.pendingPlay,nil);eq(s.phase,'player')
 end)
end
for _,move in ipairs({'heal','buff'})do
 test('combined '..move..' retains captured same-ID actor reference after first recipient callback',function()
  local s,e,m=battle('AR');force(m,move);local replacement=C.copy(m);replacement.id=m.id;local seen=false
  hooks({{E,'emit',function(old)return function(state,kind,detail)
   local result=old(state,kind,detail)
   if state==s and not seen and type(detail)=='table'and detail.source==m.id and(kind=='heal'or kind=='status'and detail.status=='strength')then
    seen=true;state.enemies[2]=replacement
   end;return result
  end end}},function()assert(C.endTurn(s))end)
  assert(seen);eq(s.enemies[2],replacement);eq(replacement.hp,1);eq(replacement.statuses.strength,nil)
  eq(m.hp,move=='heal'and 17 or 1);eq(m.statuses.strength,move=='buff'and 2 or nil);eq(s.player.statuses.plated_armor,nil)
 end)
end
for _,solo in ipairs({false,true})do
 test('combined counter death '..(solo and 'clears final tails' or 'retains Roll/Reduce; Mystic does not resurrect dead recipient'),function()
  local s,e,m=battle('AR',solo);e.hp=1;s.player.statuses.thorns=2;e.v4Directive={mature=true};local before=s.aiRng.counter
  assert(C.endTurn(s));eq(e.hp,0);eq(s.originalV4.bond,4);eq(e.v4Directive,nil);eq(s.phase,solo and 'victory'or'player')
  eq(s.aiRng.counter,before+(solo and 0 or 2));eq(s.player.statuses.plated_armor,solo and 0 or nil)
  if m then eq(m.hp,17);eq(e.act2Last,'life_suck')end;eq(s.cardActions,nil);eq(s.actionQueue,nil);eq(s.originalV4.enemyAction,nil)
 end)
end
for _,stage in ipairs({'heal','afterDeath','roll','plated','party'})do
 test('combined atomic identity/RNG rollback after '..stage,function()
  local s,e,m=battle('AR');e.hp=1;s.player.statuses.thorns=2;e.v4Directive={mature=true};local check=unchanged(s);local injected=false
  local function fail()injected=true;error('combined injected '..stage)end
  hooks({{E,'emit',function(old)return function(state,kind,detail)
   local result=old(state,kind,detail)
   if state==s and type(detail)=='table'and kind=='heal'and(stage=='heal'and detail.source==e.id or stage=='party'and detail.source==m.id)then fail()end;return result
  end end},{V,'enemyDied',function(old)return function(state,target,...)
   local result=old(state,target,...);if stage=='afterDeath'and state==s and target==e and e.hp==0 then eq(state.originalV4.bond,4);eq(e.v4Directive,nil);fail()end;return result
  end end},{SR,'randomInt',function(old)return function(rng,...)
   local result=old(rng,...);if stage=='roll'and rng==s.aiRng then eq(e.hp,0);eq(s.originalV4.bond,4);fail()end;return result
  end end},{P,'apply',function(old)return function(combat,state,effect,...)
   local result=old(combat,state,effect,...);if stage=='plated'and state==s and effect.op=='platedRemove'and effect.targetId==s.player.id then eq(s.player.statuses.plated_armor,nil);fail()end;return result
  end end}},function()
   local ok,why=pcall(C.endTurn,s);assert(injected,'fault not reached');assert(not ok and tostring(why):find('combined injected '..stage,1,true),tostring(why));check()
  end)
 end)
end
print('M3_COMBINED_QUEUE '..count..' passed='..(count-failed)..' failed='..failed);assert(failed==0)
