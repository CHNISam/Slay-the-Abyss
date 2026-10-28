package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local found,H=pcall(require,'abyss_corrupt_heart')
assert(found,'CORRUPT_HEART_COMPONENT_MISSING: no fixed-source Heart owner')
local R,Copy=require('abyss_sts_random'),require('abyss_copy').copy
local vectors=dofile('tests/fixtures/heart-vectors.lua')
local count,failed=0,0
local function eq(a,b,label)assert(a==b,(label or 'value')..': '..tostring(a)..' ~= '..tostring(b))end
local function same(a,b)
 eq(type(a),type(b));if type(a)~='table'then eq(a,b);return end
 for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil,k)end
end
local function test(name,fn)
 count=count+1;local ok,why=pcall(fn);if not ok then failed=failed+1 end
 print((ok and 'PASS 'or 'FAIL ')..name..(ok and ''or ': '..tostring(why)))
end
local function fixture(seed)
 local state={aiRng=R.fromSeed(seed or '42')}
 local enemy=Copy(H.enemy);enemy.id,enemy.definitionId='corrupt_heart_1','corrupt_heart'
 enemy.maxHp,enemy.block,enemy.statuses=enemy.hp,0,{}
 return state,enemy
end
local function random(state,n)return R.randomInt(state.aiRng,n-1)+1 end
local function intent(enemy)return assert(enemy.intents[enemy.intentIndex])end
local function preBattle(state,enemy)
 local effects=H.preBattle(state,enemy)
 -- Source plan projection only: shared ApplyPower, damage/queue/UI integration
 -- is intentionally absent here and remains the integration owner's work.
 for _,e in ipairs(effects)do enemy.statuses[e.status]=(enemy.statuses[e.status]or 0)+e.value end
 return effects
end
test('A0 definition and detached registration preserve every source-only boundary',function()
 local catalog={cards={},enemies={},statuses={}};H.register(catalog,Copy)
 eq(H.enemy.hp,750);eq(H.enemy.ai.noHpRoll,nil);eq(H.enemy.ai.preHpRoll,nil)
 eq(H.enemy.sourceId,'CorruptHeart');eq(H.enemy.tier,'boss')
 assert(catalog.enemies.corrupt_heart~=H.enemy and H.owns(catalog.enemies.corrupt_heart))
 eq(catalog.statuses.invincible.priority,99);eq(catalog.statuses.beat_of_death.priority,5)
 eq(catalog.cards.void.cost,-2);eq(catalog.cards.void.ethereal,true)
 eq(catalog.cards.void.sourceId,'Void');eq(H.owns({ai={kind='act3_boss'}}),false)
 eq(pcall(H.register,catalog,Copy),false,'duplicate register must not overwrite existing definitions')
end)
test('preBattle plans Invincible300 before Beat1 without spending any source stream',function()
 local state,e=fixture();local before=R.snapshot(state.aiRng)
 same(preBattle(state,e),{{op='gainStatus',status='invincible',value=300},{op='gainStatus',status='beat_of_death',value=1}})
 eq(e.heartInvincibleMax,300);same(R.snapshot(state.aiRng),before)
end)
test('independent 24-turn vectors preserve every primary Boolean and buff construction',function()
 for _,v in ipairs(vectors)do
  local state,e=fixture(v.seed);preBattle(state,e);H.initialize(state,e,random)
  same(R.snapshot(state.aiRng),v.initialAi)
  for _,row in ipairs(v.steps)do
   eq(intent(e).id,row.intent);local actions=H.actions(state,e,intent(e));same(actions,row.actions)
   for _,action in ipairs(actions)do if action.op=='gainStatus'then
    e.statuses[action.status]=(e.statuses[action.status]or 0)+action.value
   end end
   H.advance(state,e,random);same(R.snapshot(state.aiRng),row.aiAfterRoll)
   eq(e.heartMoveCount,row.moveCount);eq(e.heartBuffCount,row.buffCount)
  end
  eq(intent(e).id,v.nextIntent);same(R.snapshot(state.aiRng),v.finalAi)
 end
end)
test('opening ignores all primary values and second attack is the opposite first attack',function()
 for _,n in ipairs({1,30,50,100})do
  local state,e=fixture();local calls=0
  H.initialize(state,e,function(_,maximum)calls=calls+1;eq(maximum,100);return n end)
  eq(calls,1);eq(intent(e).id,'debilitate');eq(e.heartMoveCount,0)
  H.advance(state,e,random);local first=intent(e).id;H.advance(state,e,random)
  assert(first~=intent(e).id and (first=='blood_shots'or first=='echo_attack'))
  H.advance(state,e,random);eq(intent(e).id,'buff')
 end
end)
test('Debilitate preserves three debuffs then five distinct source card insertion commands',function()
 local state,e=fixture();H.initialize(state,e,random)
 local actions=H.actions(state,e,intent(e));eq(#actions,8)
 for i,id in ipairs({'vulnerable','weak','frail'})do same(actions[i],{op='applyStatus',status=id,value=2})end
 for i,id in ipairs({'dazed','slimed','wound','burn','void'})do same(actions[i+3],{op='heartStatusDraw',card=id,value=1})end
 actions[1].value=99;eq(intent(e).effects[1].value,2,'plans do not mutate shared intent graphs')
end)
test('Buff captures negative strength compensation and all eight source escalation stages',function()
 for _,strength in ipairs({-999,-5,0,7})do
  local state,e=fixture();e.heartBuffCount=0;e.statuses.strength=strength
  local plans=H.actions(state,e,{id='buff'});eq(plans[1].value,math.max(0,-strength)+2)
  e.statuses.strength=123;eq(plans[1].value,math.max(0,-strength)+2,'capture belongs to takeTurn')
 end
 local state,e=fixture();e.heartBuffCount=0
 local expected={{'artifact',2},{'beat_of_death',1},{'painful_stabs',-1},{'strength',10},
  {'strength',50},{'strength',50},{'strength',50},{'strength',50}}
 for i,v in ipairs(expected)do
  local effects=H.actions(state,e,{id='buff'});eq(#effects,2);eq(effects[1].value,2)
  same(effects[2],{op='gainStatus',status=v[1],value=v[2]});eq(e.heartBuffCount,i)
 end
end)
test('Invincible callback caps committed damage budgets including zero membership until owner reset',function()
 local state,e=fixture();preBattle(state,e)
 eq(H.capDamage(e,299),299);eq(e.statuses.invincible,1)
 eq(H.capDamage(e,9),1);eq(e.statuses.invincible,0)
 eq(H.capDamage(e,400),0);eq(e.statuses.invincible,0)
 eq(H.capDamage(e,0),0);eq(e.statuses.invincible,0)
 H.startTurn(e);eq(e.statuses.invincible,300)
 eq(H.capDamage(e,301),300);eq(e.statuses.invincible,0)
 local other={ai={kind='other'},statuses={}};eq(H.capDamage(other,20),20)
end)
test('Beat callback captures THORNS request after each physical use without executing damage early',function()
 local state,e=fixture();preBattle(state,e);local events={}
 local function enqueue(owner,effect)eq(owner,state);events[#events+1]=effect end
 H.afterUse(state,e,{},enqueue)
 same(events[1],{op='heartBeat',sourceId=e.id,value=1})
 e.statuses.beat_of_death=2;eq(events[1].value,1,'DamageInfo constructor amount is frozen')
 H.afterUse(state,e,{dontTriggerOnUseCard=true},enqueue);eq(#events,1)
 e.hp=0;H.afterUse(state,e,{},enqueue);eq(#events,2);eq(events[2].value,2)
 eq(H.retained(events[2]),true);eq(H.retained({op='heartStatusDraw'}),false)
 eq(state.player,nil,'callback does not pretend the missing shared damage host ran')
end)
print('HEART_COMPONENT_PASS '..count..' groups; '..failed..' failed; callback/source-plan evidence only, shared battle and Act4 not wired')
assert(failed==0)
