package.path='tests/lua/?.lua;src/lua/?.lua;build/lua/?.lua;'..package.path
local C,A,Actor=require('abyss_combat'),require('abyss_card_actions'),require('abyss_actor')
local D=require('abyss_data')
local count=0
local function eq(a,b,label)assert(a==b,'[EXPERIMENTAL_END] '..label..': '..tostring(a)..' ~= '..tostring(b))end
local function graph(v,seen)
 local kind=type(v)
 if kind=='function'then return 'function'end
 if kind=='string'then return string.format('%q',v)end
 if kind=='number'then return 'number:'..string.format('%.17g',v)end
 if kind~='table'then return kind..':'..tostring(v)end
 seen=seen or {n=0};if seen[v]then return 'ref:'..seen[v]end
 seen.n=seen.n+1;seen[v]=seen.n
 local keys={};for k in pairs(v)do keys[#keys+1]=k end
 table.sort(keys,function(a,b)return type(a)..tostring(a)<type(b)..tostring(b)end)
 local rows={};for _,k in ipairs(keys)do rows[#rows+1]=graph(k,seen)..'='..graph(v[k],seen)end
 return '{'..table.concat(rows,';')..'}'
end
local function record(s,result)
 if ABYSS_EXPERIMENTAL_END_TRACE then print('EXPERIMENTAL_END_TRACE '..graph({state=s,result=result}))end
end
local function invoke(s,fn,...)
 local result=table.pack(pcall(fn or C.endTurn,s,...));record(s,result)
 return table.unpack(result,1,result.n)
end
local function test(name,fn)
 if ABYSS_EXPERIMENTAL_END_CASE and ABYSS_EXPERIMENTAL_END_CASE~=name then return end
 fn();count=count+1;print('ok experimental end '..count..' '..name)
end
local function battle(data)
 local s=C.new(data or D,{seed=42,deck={},enemies={'cultist'},cardRandomSeed='42'})
 s.experimentalMechanics=true;s.events={}
 for _,e in ipairs(s.enemies)do e.ai=nil;e.intentIndex=1;e.intents={{id='wait',effects={{op='block',value=0}}}}end
 s.auditAliases={hand=s.hand,draw=s.draw,discard=s.discard,exhaust=s.exhaust,player=s.player,enemies=s.enemies}
 return s
end
local function fresh(s,id)local c=A.fresh(C,s,id);A.toHand(s,c);return c end
local function event(s,kind)
 for i,e in ipairs(s.events)do if e.kind==kind then return e,i end end
end

test('cost-reset-piles',function()
 local s=battle();s.hand={};s.draw={};s.discard={};s.exhaust={}
 local held={}
 for _,name in ipairs({'hand','draw','discard','exhaust'})do
  local card=A.fresh(C,s,'defend');card.costForTurn=0;card.turnCost=0;s[name][1]=card;held[name]=card
 end
 local called,ok=invoke(s);eq(called,true,'cost reset called');eq(ok,true,'cost reset accepted')
 local frame=assert(event(s,'enemy_turn'),'[EXPERIMENTAL_END] enemy boundary').frame
 for _,name in ipairs({'hand','draw','discard'})do
  eq(held[name].costForTurn,nil,name..' temporary cost reset');eq(held[name].turnCost,nil,name..' turn cost reset')
 end
 eq(held.exhaust.costForTurn,0,'exhaust costForTurn remains');eq(held.exhaust.turnCost,0,'exhaust turnCost remains')
 eq(frame.exhaust[1].uid,held.exhaust.uid,'exhaust original identity snapshot')
 for _,card in ipairs(frame.discard)do eq(card.costForTurn,nil,'discard frame cost reset');eq(card.turnCost,nil,'discard frame turn reset')end
end)
test('second-regret-death',function()
 local s=battle();local first,second,dazed=fresh(s,'regret'),fresh(s,'regret'),fresh(s,'dazed')
 Actor.applyNoDraw(s,s.player);s.player.hp=4
 local called,ok=invoke(s);eq(called,true,'second Regret called');eq(ok,true,'second Regret accepted')
 eq(s.phase,'defeat','second Regret terminal');eq(s.discard[1],first,'first Regret original discarded')
 eq(s.cardInUse,second,'dying second Regret retained');eq(s.hand[1],dazed,'later Ethereal remains in hand')
 eq(#s.exhaust,0,'death skips Ethereal');eq(s.player.noDraw,true,'death skips NoDraw removal')
 eq(event(s,'enemy_turn'),nil,'death skips enemy event')
 local amounts={};for _,e in ipairs(s.events)do if e.kind=='hp_loss'then amounts[#amounts+1]=e.detail.amount end end
 eq(amounts[1],3,'first Regret original handSize');eq(amounts[2],1,'second Regret actual remaining HP')
end)
test('vault-skips-entire-enemy-phase',function()
 local data=require('abyss_silent_tactics_cards').withCardDefinitions(require('abyss_character_profiles').prepare(D,'watcher'))
 local R=require('abyss_sts_random');local streams={}
 for _,id in ipairs({'aiRng','monsterHpRng','shuffleRng','cardRandomRng'})do streams[id]=R.fromSeed('42')end
 local s=C.new(data,{seed=42,deck={'vault'},enemies={'cultist'},enableStances=true,cardRandomSeed='42',roomSeed='42',roomStreams=streams})
 s.experimentalMechanics=true;s.events={};local enemy=s.enemies[1]
 enemy.block=23;enemy.statuses.poison=4;enemy.statuses.weak=2;enemy.statuses.choked=3
 local vault=s.hand[1];local before,aiBefore
 local ending=C.endTurn
 C.endTurn=function(state,...)
  before=graph(state.enemies);aiBefore=graph(state.aiRng);return ending(state,...)
 end
 local called,ok=invoke(s,C.play,vault.uid,1);C.endTurn=ending
 eq(called,true,'Vault play called '..tostring(ok));eq(ok,true,'Vault play accepted')
 assert(before,'[EXPERIMENTAL_END] real Vault reached endTurn')
 assert(s.aiRng,'[EXPERIMENTAL_END] real enemy AI stream required')
 eq(graph(s.enemies),before,'Vault preserves complete enemies after card hooks')
 eq(graph(s.aiRng),aiBefore,'Vault preserves enemy AI RNG')
 eq(event(s,'enemy_turn'),nil,'Vault has no enemy_turn event');eq(event(s,'intent'),nil,'Vault has no enemy intent')
 eq(s.skipMonsterTurn,nil,'Vault skip consumed');eq(s.turn,2,'Vault one extra turn');eq(s.phase,'player','Vault player phase')
end)
test('late-resume-guard',function()
 local s=battle();local burn=fresh(s,'burn');burn.costForTurn=0
 local rare=require('abyss_rare_relics');local original=rare.onPlayerEndTurn;local calls=0
 rare.onPlayerEndTurn=function(state)calls=calls+1;state.silentRetainResume=true end
 local hp=s.player.hp;local called,ok=invoke(s);rare.onPlayerEndTurn=original
 eq(called,true,'late resume called');eq(ok,true,'late resume accepted');eq(calls,1,'one relic boundary')
 eq(s.player.hp,hp,'second resume guard skips Burn');eq(burn.costForTurn,0,'second resume guard skips costs')
 eq(s.silentRetainResume,nil,'resume consumed after guarded player end')
end)
test('rejection-priority',function()
 local s=battle();s.phase='enemy';s.pendingChoice={};s.cardActions={};s.pendingPlay={};s.pendingDiscard={}
 local before=graph(s);local called,ok,why=invoke(s)
 eq(called,true,'rejection called');eq(ok,false,'rejection result');eq(why,'card_choice_pending','card rejection precedes all')
 eq(graph(s),before,'card rejection has no state effect')
 s.pendingChoice=nil;s.cardActions=nil;before=graph(s);called,ok,why=invoke(s)
 eq(why,'selection_pending','selection precedes discard/phase');eq(graph(s),before,'selection rejection has no state effect')
 s.pendingPlay=nil;before=graph(s);called,ok,why=invoke(s)
 eq(why,'discard_choice_pending','discard precedes phase');eq(graph(s),before,'discard rejection has no state effect')
 s.pendingDiscard=nil;before=graph(s);called,ok,why=invoke(s)
 eq(why,'not_player_turn','phase reason');eq(graph(s),before,'phase rejection has no state effect')
end)

-- Reuse the existing cross-protocol fixture without copying its behavior or
-- increasing the default raw fixture work. Only differential replay requests
-- these established experimental lifecycle scenarios.
if ABYSS_EXPERIMENTAL_END_EXISTING then
 ABYSS_NATIVE_END_TRACE=ABYSS_EXPERIMENTAL_END_TRACE
 for _,name in ipairs({'cleanup-experimental','retain-experimental','lethal-regret-experimental',
  'no-draw-experimental','enemy-snapshot-experimental','throw-experimental'})do
  if not ABYSS_EXPERIMENTAL_END_CASE or ABYSS_EXPERIMENTAL_END_CASE==name then
   ABYSS_NATIVE_END_CASE=name;dofile('tests/lua/native_turn_end.lua')
  end
 end
 ABYSS_NATIVE_END_CASE=nil
end
print('EXPERIMENTAL_TURN_END_PASS '..count)
