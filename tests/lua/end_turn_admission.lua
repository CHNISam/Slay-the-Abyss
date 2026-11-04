package.path='tests/lua/?.lua;src/lua/?.lua;build/lua/?.lua;'..package.path
local C,A,D,S=require('abyss_combat'),require('abyss_card_actions'),require('abyss_data'),require('abyss_snapshot')
local count=0
local function eq(a,b,label)assert(a==b,'[END_ADMISSION] '..label..': '..tostring(a)..' ~= '..tostring(b))end
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
local function invoke(s,owner)
 local r=table.pack(pcall(C.endTurn,s,owner))
 if ADMISSION_TRACE then print('END_ADMISSION_TRACE '..graph({state=s,result=r}))end
 return r
end
local function observe(s,owner)
 local capture=S.capture;local calls=0
 S.capture=function(...)calls=calls+1;return capture(...)end
 local r=invoke(s,owner);S.capture=capture
 return r,calls
end
local function test(name,fn)
 if ADMISSION_CASE and ADMISSION_CASE~=name then return end
 fn();count=count+1;print('ok admission '..count..' '..name)
end
local function battle(experimental)
 local s=C.new(D,{seed=42,deck={},enemies={'cultist'},cardRandomSeed='42'})
 s.experimentalMechanics=experimental==true;s.events={}
 local e=s.enemies[1];e.ai=nil;e.intents={{id='wait',effects={{op='block',value=0}}}};e.intentIndex=1
 s.auditAliases={player=s.player,hand=s.hand,draw=s.draw,discard=s.discard,enemies=s.enemies,events=s.events}
 s.auditAliases.self=s.auditAliases
 return s
end
local function clearAdvanced(s)
 for _,id in ipairs({'evolve','claw','blur','wallop'})do s.catalog.cards[id]=nil end
end
local function accepted(r,n,label)eq(r[1],true,label..' pcall');eq(r[2],true,label..' accepted');eq(r.n,n,label..' return arity')end
local function rejected(r,why,label)eq(r[1],true,label..' pcall');eq(r[2],false,label..' refused');eq(r[3],why,label..' reason');eq(r.n,3,label..' return arity')end
local function event(s,kind)
 for i,e in ipairs(s.events)do if e.kind==kind then return e,i end end
end

test('potion-first',function()
 local s=battle();s.pendingPotionChoice={};s.pendingChoice={};s.phase='enemy';s.relics={'nilrys_codex'}
 local _,owner=S.capture(s,s);local before=graph(s)
 local relics=require('abyss_relic_end_turn');local needed=relics.needed;local reads=0
 relics.needed=function(...)reads=reads+1;return needed(...)end
 local r,captures=observe(s,owner);relics.needed=needed
 rejected(r,'potion_choice_pending','potion first');eq(reads,0,'potion stops relic inspection');eq(captures,0,'potion no snapshot')
 eq(graph(s),before,'potion refusal graph unchanged');eq(S.release(owner),true,'potion does not consume owner')
end)
test('direct-native',function()
 local s=battle(false);clearAdvanced(s)
 local r,captures=observe(s);accepted(r,2,'direct native');eq(captures,0,'direct native no snapshot');eq(s.turn,2,'direct native advances')
end)
test('direct-experimental-and-reads',function()
 local s=battle(true);clearAdvanced(s);local reads={}
 local keys={evolve=true,claw=true,blur=true,wallop=true}
 setmetatable(s.catalog.cards,{__index=function(_,key)if keys[key]then reads[#reads+1]=key end end})
 local r,captures=observe(s);accepted(r,2,'direct experimental');eq(captures,0,'direct experimental no snapshot')
 eq(table.concat(reads,','),'evolve,claw,blur,wallop,evolve,claw,blur,wallop','both advanced predicates preserve ordered short circuit reads')
end)
test('second-predicate-fallback',function()
 local s=battle(true);clearAdvanced(s);local reads=0
 setmetatable(s.catalog.cards,{__index=function(_,key)
  if key=='evolve'then reads=reads+1;if reads==2 then return {id='evolve'}end end
 end})
 local r,captures=observe(s);accepted(r,3,'fallback transaction');eq(captures,1,'second true predicate takes fallback snapshot')
 eq(reads,2,'second predicate is actually reread');eq(s.turn,2,'fallback completes experimental end')
end)
test('catalog-short-circuit',function()
 local s=battle(false);clearAdvanced(s);local reads=0
 setmetatable(s.catalog.cards,{__index=function(_,key)
  if key=='evolve'then reads=reads+1;return {id='evolve'}end
  assert(key~='claw'and key~='blur'and key~='wallop','[END_ADMISSION] skipped catalog fields must not be read')
 end})
 local r,captures=observe(s);accepted(r,3,'catalog transaction');eq(captures,1,'first true predicate snapshot')
 eq(reads,1,'first catalog hit skips later probes')
end)
test('relic-false',function()
 local s=battle();s.relics={'nilrys_codex'};s.phase='enemy';s.pendingChoice={}
 local before=graph(s);local r,captures=observe(s)
 rejected(r,'not_player_turn','relic false');eq(captures,0,'relic false before snapshot');eq(graph(s),before,'relic false unchanged')
end)
test('relic-pause',function()
 local H=dofile('tests/helpers/act2_event_relics.lua');local _,s=H.battle({"Nilry's Codex"},{'defend'})
 local turn=s.turn;local r=invoke(s);accepted(r,2,'relic pause')
 eq(s.turn,turn,'relic pause no next turn');assert(s.pendingChoice and s.pendingChoice.op=='codex','[END_ADMISSION] actual Codex choice')
 assert(s.actionQueue and s.actionQueue.paused,'[END_ADMISSION] actual Codex paused queue')
 local before=graph(s);r=invoke(s);rejected(r,'card_choice_pending','paused relic repeat');eq(graph(s),before,'paused repeat unchanged')
end)
test('relic-terminal',function()
 local H=dofile('tests/helpers/act2_event_relics.lua');local _,s=H.battle({'StoneCalendar',"Nilry's Codex"},{'defend'})
 s.turn=7;s.relicCounters.stone_calendar=7;s.enemies[1].hp=52
 local rng=graph(s.cardRandomRng);local r=invoke(s);accepted(r,2,'relic terminal')
 eq(s.phase,'victory','Calendar terminal before Codex');eq(s.turn,7,'terminal keeps turn');eq(s.pendingChoice,nil,'terminal suppresses later Codex')
 eq(graph(s.cardRandomRng),rng,'terminal suppresses Codex RNG')
end)
test('retained-public-resume',function()
 local s=battle(true);local card=A.fresh(C,s,'defend');A.toHand(s,card);card.silentRetainTurn=s.turn
 local queue=require('abyss_action_queue');queue.start(s,{})
 s.actionQueue.paused=true;s.actionQueue.current={kind='effect',effect={op='ownerEndRetain'}};s.silentRetainResume=true
 s.pendingChoice={token=1};local before=graph(s)
 local r=invoke(s);rejected(r,'card_choice_pending','retain pending');eq(graph(s),before,'retain pending graph unchanged')
 s.pendingChoice=nil;r=invoke(s);accepted(r,3,'retain public continue')
 eq(s.turn,2,'retain continuation advances once');eq(s.actionQueue,nil,'retain queue completes');eq(s.silentRetainResume,nil,'retain resume consumed')
 eq(s.hand[1],card,'retained selected source instance survives');eq(card.retain,nil,'temporary retain marker cleared')
end)
test('original-overrides-experimental',function()
 local s=require('support.original_v4_fixture').state('FR',40);s.experimentalMechanics=true;s.events={}
 local enemy=s.enemies[1];enemy.ai=nil;enemy.intentIndex=1;enemy.intents={{id='wait',effects={{op='block',value=0}}}}
 local burn=A.fresh(C,s,'burn');A.toHand(s,burn)
 local r,captures=observe(s);accepted(r,3,'V4 transactional native');eq(captures,1,'V4 always transactional')
 local _,ei=event(s,'enemy_turn');local damage
 for i,e in ipairs(s.events)do if e.kind=='damage'and e.detail.target==s.player.id then damage=i;break end end
 assert(ei and damage and ei<damage,'[END_ADMISSION] V4 keeps native cleanup after enemies despite experimental flag')
end)
test('snapshot-before-resolver-read',function()
 local s=battle(false);local card=A.fresh(C,s,'defend');A.toHand(s,card);card.turnCost=2
 local capture=S.capture;local calls=0
 S.capture=function(...)
  calls=calls+1;local restore,owner=capture(...);s.experimentalMechanics=true;return restore,owner
 end
 local r=invoke(s);S.capture=capture
 accepted(r,3,'snapshot then resolver');eq(calls,1,'snapshot callback reached once')
 eq(card.turnCost,nil,'resolver reads changed experimental flag after capture, selecting experimental cost reset')
end)
test('owner-and-atomic-alias-restore',function()
 for _,experimental in ipairs({false,true})do
  local s=battle(experimental);local card=A.fresh(C,s,'defend');A.toHand(s,card);card.costForTurn=0
  local _,owner=S.capture(s,s);local before=graph(s);local sentinel={message='admission late fault'}
  local Events=require('abyss_events');local emit=Events.emit;local fired=false
  Events.emit=function(state,kind,...)
   local result=emit(state,kind,...)
   if kind=='enemy_turn'then
    state.catalog.cards.defend.name='MUTATED';state.auditAliases.injection={}
    require('abyss_sts_random').randomInt(state.cardRandomRng,1);state.seed=(state.seed+1)%65536
    fired=true;error(sentinel,0)
   end
   return result
  end
  local r,captures=observe(s,owner);Events.emit=emit
  eq(fired,true,'late fault reached');eq(r[1],false,'late fault propagates');eq(r[2],sentinel,'table exception identity preserved');eq(r.n,2,'exception arity')
  eq(captures,0,'exact parent owner reused');eq(graph(s),before,'complete catalog/piles/events/cost/RNG/alias graph restored')
  eq(S.ownedRestore(owner,s),nil,'parent owner consumed once');eq(S.release(owner),false,'consumed owner cannot release')
 end
 local s=battle(false);local other=battle(false);local _,wrong=S.capture(other,other)
 local r,captures=observe(s,wrong);accepted(r,3,'wrong owner fallback');eq(captures,1,'wrong target gets fresh snapshot')
 eq(S.release(wrong),true,'wrong-target owner remains unconsumed')
end)
if ADMISSION_TRACE then print('END_ADMISSION_FIXTURE_COMPLETE')end
print('END_TURN_ADMISSION_PASS '..count)
