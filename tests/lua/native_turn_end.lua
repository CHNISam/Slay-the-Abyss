-- Independent complete-source differential fixture; raw suite emits summaries only.
package.path='tests/lua/?.lua;src/lua/?.lua;build/lua/?.lua;'..package.path
local C,A,Actor=require('abyss_combat'),require('abyss_card_actions'),require('abyss_actor')
local Data=require('abyss_data')
local count=0
local function eq(a,b,label)assert(a==b,'[NATIVE_END] '..label..': '..tostring(a)..' ~= '..tostring(b))end
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
 if ABYSS_NATIVE_END_TRACE then print('NATIVE_END_TRACE '..graph({state=s,result=result}))end
end
local function invoke(s,fn,...)
 local result=table.pack(pcall(fn or C.endTurn,s,...));record(s,result)
 return table.unpack(result,1,result.n)
end
local function test(name,fn)
 if ABYSS_NATIVE_END_CASE and ABYSS_NATIVE_END_CASE~=name then return end
 fn();count=count+1;print('ok native end '..count..' '..name)
end
local function battle(mode,deck,data)
 local s
 if mode=='v4' then s=require('support.original_v4_fixture').state('FR',40)
 else s=C.new(data or Data,{seed=42,deck=deck or {},enemies={'cultist'},cardRandomSeed='42'})end
 s.experimentalMechanics=mode=='experimental';s.events={}
 for _,e in ipairs(s.enemies)do e.ai=nil;e.intentIndex=1;e.intents={{id='wait',effects={{op='block',value=0}}}}end
 s.auditAliases={player=s.player,hand=s.hand,enemy=s.enemies[1],events=s.events,rng=s.aiRng};s.auditAliases.self=s.auditAliases
 return s
end
local function fresh(s,id)local c=A.fresh(C,s,id);A.toHand(s,c);return c end
local function event(s,kind,uid)
 for i,e in ipairs(s.events)do if e.kind==kind and (not uid or e.detail.uid==uid)then return e,i end end
end
for _,mode in ipairs({'native','experimental','v4'})do
 test('cleanup-'..mode,function()
  local s=battle(mode);local burn=fresh(s,'burn');local hand=s.hand;local hp=s.player.hp
  local called,ok=invoke(s);eq(called,true,'cleanup called');eq(ok,true,'cleanup accepted')
  local enemy,ei=event(s,'enemy_turn');assert(enemy,'[NATIVE_END] enemy frame required')
  local damageIndex;for i,e in ipairs(s.events)do if e.kind=='damage'and e.detail.target==s.player.id then damageIndex=i;break end end
  assert(damageIndex,'[NATIVE_END] real Burn damage required')
  local held=false;for _,c in ipairs(enemy.frame.hand)do if c.uid==burn.uid then held=true end end
  eq(held,mode=='v4','V4 defers hand cleanup until after enemy moves')
  assert(mode=='v4'and damageIndex>ei or mode~='v4'and damageIndex<ei,'[NATIVE_END] Burn cleanup side of enemy boundary')
  eq(s.player.hp,hp-2,'one Burn loss');eq(s.auditAliases.hand,hand,'original hand alias retained')
 end)
end
local advancedData=require('abyss_silent_final_cards').withCardDefinitions(require('abyss_warrior_strength_cards').withCards(require('abyss_character_profiles').prepare(Data,'watcher')))
for _,mode in ipairs({'native','experimental'})do
 test('retain-'..mode,function()
  local s=battle(mode,nil,advancedData)
  for _,id in ipairs({'combust','establishment','well_laid_plans'})do local c=fresh(s,id);s.energy=20;assert(C.play(s,c.uid))end
  local defend,protect,sands,dazed=fresh(s,'defend_purple'),fresh(s,'protect'),fresh(s,'sands_of_time'),fresh(s,'dazed')
  local hp,enemy=s.player.hp,s.enemies[1].hp
  local called,ok=invoke(s);eq(called,true,'retain called');eq(ok,true,'retain pauses')
  local queue,pending=s.actionQueue,s.pendingChoice
  assert(queue and queue.paused and pending and pending.kind=='retain','[NATIVE_END] real retain pause')
  eq(s.player.hp,hp-1,'Combust once before pause');eq(s.enemies[1].hp,enemy-5,'Combust damage before pause')
  local c,rejected=invoke(s);eq(c,true,'repeat end normal refusal');eq(rejected,false,'repeat end refused')
  eq(s.actionQueue,queue,'paused queue owner unchanged')
  c,ok=invoke(s,C.chooseCard,pending.token,defend.uid);eq(c,true,'retain selection called');eq(ok,true,'retain selection accepted')
  c,ok=invoke(s,C.chooseCard,s.pendingChoice.token,0);eq(c,true,'retain completion called');eq(ok,true,'retain completion accepted')
  eq(s.player.hp,hp-1,'resume never repeats Combust');eq(s.enemies[1].hp,enemy-5,'resume never repeats damage')
  eq(s.exhaust[1].uid,dazed.uid,'Ethereal exhaust after retain');eq(C.cardDefinition(s,defend).cost,0,'Establishment selected cost')
  eq(C.cardDefinition(s,protect).cost,1,'self retain cost');eq(C.cardDefinition(s,sands).cost,2,'retained Sands reduction')
  eq(s.actionQueue,nil,'queue drained');eq(s.pendingChoice,nil,'choice cleared');eq(s.turn,2,'one turn advanced')
 end)
 test('lethal-regret-'..mode,function()
  local s=battle(mode,nil,advancedData);local regret=fresh(s,'regret');local dazed=fresh(s,'dazed')
  Actor.applyNoDraw(s,s.player);s.player.hp=1
  local called,ok=invoke(s);eq(called,true,'lethal called');eq(ok,true,'lethal accepted');eq(s.phase,'defeat','Regret defeats')
  eq(s.player.noDraw,true,'death precedes NoDraw removal');eq(s.cardInUse,regret,'dying card identity remains')
  eq(s.hand[1],dazed,'later card remains held');eq(#s.exhaust,0,'death prevents Ethereal');eq(event(s,'enemy_turn'),nil,'death prevents enemy phase')
 end)
 test('no-draw-'..mode,function()
  local s=battle(mode,nil,advancedData);C.applyEffects(s,{{op='gainExhaustPower',status='dark_embrace',value=1}},s.player)
  Actor.applyNoDraw(s,s.player);local dazed=fresh(s,'dazed');s.draw={A.fresh(C,s,'defend_purple')}
  local called,ok=invoke(s);eq(called,true,'NoDraw called');eq(ok,true,'NoDraw accepted')
  local _,ni=event(s,'no_draw_removed');local _,xi=event(s,'exhaust',dazed.uid);local enemy,ei=event(s,'enemy_turn')
  assert(ni and xi and ei and ni<xi and xi<ei,'[NATIVE_END] NoDraw before Ethereal before enemy')
  eq(#enemy.frame.hand,1,'Dark Embrace actually draws before enemy')
 end)
 test('enemy-snapshot-'..mode,function()
  local R=require('abyss_sts_random');local streams={};for _,k in ipairs({'aiRng','monsterHpRng','cardRandomRng','shuffleRng'})do streams[k]=R.fromSeed('1')end
  local s=C.new(Data,{deck={},roomSeed='1',roomStreams=streams,maxHp=5000,hp=5000,sourceEncounter='Reptomancer',encounterBoundary={misc={}}})
  s.experimentalMechanics=mode=='experimental';s.events={};s.auditAliases={enemies=s.enemies,leader=s.enemies[2],rng=s.aiRng}
  local called,ok=invoke(s);eq(called,true,'summon called');eq(ok,true,'summon accepted')
  local child;for _,e in ipairs(s.enemies)do if e.id=='snake_dagger_4'then child=e end end
  assert(child,'[NATIVE_END] real summon created')
  for _,e in ipairs(s.events)do assert(not(e.kind=='damage'and e.detail.source==child.id),'[NATIVE_END] new summon cannot act in spawn round')end
 end)
 test('throw-'..mode,function()
  local s=battle(mode,nil,advancedData);local dazed=fresh(s,'dazed');local before=graph(s)
  local Events=require('abyss_events');local emit=Events.emit;local fired=false
  Events.emit=function(state,kind,detail)local result=emit(state,kind,detail);if kind=='exhaust'and detail.uid==dazed.uid then fired=true;error('NATIVE_END_INJECTED',0)end;return result end
  local called,why=invoke(s);Events.emit=emit
  eq(fired,true,'injected fault reached');eq(called,false,'throw propagates');eq(why,'NATIVE_END_INJECTED','exact exception')
  eq(graph(s),before,'atomic full state restore including aliases events and RNG')
 end)
end
print('NATIVE_TURN_END_PASS '..count)
