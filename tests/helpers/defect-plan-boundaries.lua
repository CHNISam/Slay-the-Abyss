-- Minimal real-module characterization; optional DEFECT_PLAN_BOUNDARY_GROUP=1..4
-- partitions registration ordinals exactly once. Observer uses (root,label).
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local E=require('abyss_defect_engine_cards')
local Actors,Random,Queries=require('abyss_actor'),require('abyss_sts_random'),require('abyss_relic_queries')
local MAX=2147483647
local group=DEFECT_PLAN_BOUNDARY_GROUP
assert(group==nil or (type(group)=='number' and group%1==0 and group>=1 and group<=4),'invalid Defect boundary group')
local registered,ran=0,0
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
-- Snapshot each original table's edges, retaining identity, aliases and cycles.
local function snapshot(root)
 local out={}
 local function visit(t)
  if type(t)~='table' or out[t]then return end
  local row={meta=getmetatable(t),values={}};out[t]=row
  for k,v in pairs(t)do row.values[k]=v;visit(k);visit(v)end
 end
 visit(root);return out
end
local function unchanged(before)
 for t,row in pairs(before)do
  eq(getmetatable(t),row.meta)
  for k,v in pairs(row.values)do eq(t[k],v)end
  for k,v in pairs(t)do eq(row.values[k],v)end
 end
end
local function observe(root,label)if DEFECT_PLAN_GRAPH_WRITE then DEFECT_PLAN_GRAPH_WRITE(root,label)end end
local function call(s,e,c)
 local root={state=s,effect=e,context=c};local before=snapshot(root)
 local values=table.pack(pcall(E.planEffect,s,e,c))
 unchanged(before)
 local observed=values
 if not values[1] and type(values[2])=='string' and DEFECT_ERROR_LOCATION then
  observed=table.pack(table.unpack(values,1,values.n));observed[2]=DEFECT_ERROR_LOCATION(values[2])
 end
 root.returns=observed;observe(root,'defect-boundary-call')
 eq(values.n,2) -- Exactly one plan/nil or one thrown value, not hidden extra returns.
 return values[1],values[2]
end
local function plan(s,e,c)local ok,p=call(s,e,c);assert(ok,p);return p end
local function fails(s,e,c,expected)
 local ok,err=call(s,e,c);eq(ok,false)
 if type(expected)=='table'then eq(err,expected)elseif expected then assert(tostring(err):find(expected,1,true),tostring(err))end
 return err
end
local function test(name,fn)
 registered=registered+1
 if group and (registered-1)%4+1~=group then return end
 fn();ran=ran+1;print('PASS defect boundaries '..registered..' '..name)
end
local function actor(id)return {id=id,hp=30,block=0,statuses={}}end
local function state()
 local s={player=actor('player'),enemies={actor('a'),actor('b')},energy=3,
  hand={},draw={},discard={},exhaust={},catalog={cards={streamline={cost=2}}},
  orbs={balls={}},relics={},rules={combat={weakPercent=75,vulnerablePercent=150}},
  cardRandomRng=Random.fromSeed('17')}
 return s
end
local function card(uid,id)return {uid=uid,cardId=id}end
local function replaced(owner,key,value,fn)
 local old=owner[key];owner[key]=value
 local out=table.pack(pcall(fn));owner[key]=old
 assert(out[1],out[2]);return table.unpack(out,2,out.n)
end

test('Claw deduplicates uid in traversal order and excludes exhaust',function()
 local s=state();local a,b,c,d=card(1,'claw'),card(2,'claw'),card(3,'claw'),card(4,'claw')
 a.engineClawBonus=4;b.engineClawBonus=8
 s.cardInUse=a;s.hand={a,b,card(2,'claw'),card(9,'strike')};s.draw={b,c};s.discard={c};s.exhaust={d}
 local p=plan(s,{op='growClaws',value=2},{instance=a})
 eq(#p.instanceChanges,3)
 for i,n in ipairs({6,10,2})do eq(p.instanceChanges[i].uid,i);eq(p.instanceChanges[i].changes.engineClawBonus,n)end
 eq(#p.top,0);eq(#p.bottom,0);eq(p.consumeAllEnergy,false)
 local override=card(8,'claw');p=plan(s,{op='growClaws',value=2},{instance=override});eq(p.instanceChanges[1].uid,8)
 fails(s,{op='growClaws',value=1},nil,'unsupported Claw increment')
 fails(s,{op='growClaws',value=2},{instance=card(8,'strike')},'missing played Claw')
 a.engineClawBonus=MAX;fails(s,{op='growClaws',value=2},nil,'invalid Defect engine number')
end)

test('Steam instance lookup covers every pile and duplicates',function()
 for _,where in ipairs({'cardInUse','hand','draw','discard','exhaust'})do
  local s=state();local c=card(7,'steam_barrier');c.engineBlockLoss=6
  if where=='cardInUse'then s.cardInUse=c else s[where]={c}end
  local p=plan(s,{op='loseSteamBlock',value=1},{uid=7})
  eq(p.instanceChanges[1].uid,7);eq(p.instanceChanges[1].changes.engineBlockLoss,7)
 end
 local s=state();s.cardInUse=card(7,'steam_barrier')
 plan(s,{op='loseSteamBlock',value=1});s.hand={s.cardInUse}
 fails(s,{op='loseSteamBlock',value=1},nil,'duplicate battle instance')
 s.cardInUse=nil;s.hand={};fails(s,{op='loseSteamBlock',value=1},{uid=7},'missing engine battle instance')
 s.hand={card(7,'claw')};fails(s,{op='loseSteamBlock',value=1},{uid=7},'wrong Steam instance')
 fails(s,{op='loseSteamBlock',value=2},{uid=7},'unsupported Steam decrement')
 s.hand[1].cardId='steam_barrier';s.hand[1].engineBlockLoss=MAX
 fails(s,{op='loseSteamBlock',value=1},{uid=7},'invalid Defect engine number')
end)

test('Streamline turn and combat costs preserve zero and discounts',function()
 local cases={{nil,nil,1,1},{2,0,1,0},{2,1,0,0},{0,nil,0,0},{4,3,2,2},{0,2,1,1}}
 for _,v in ipairs(cases)do
  local s=state();s.cardInUse=card(1,'streamline');s.cardInUse.combatCost=v[1];s.cardInUse.turnCost=v[2]
  local p=plan(s,{op='reduceStreamlineCost',value=1});local c=p.instanceChanges[1].changes
  eq(c.combatCost,v[3]);eq(c.turnCost,v[4])
 end
 local s=state();s.cardInUse=card(1,'streamline');s.cardInUse.turnCost=-1
 fails(s,{op='reduceStreamlineCost',value=1},nil,'invalid Defect engine number')
 fails(s,{op='reduceStreamlineCost',value=2},nil,'unsupported Streamline decrement')
 s.cardInUse.cardId='claw';fails(s,{op='reduceStreamlineCost',value=1},nil,'wrong Streamline instance')
end)

test('Aggregate floors both divisors including empty draw',function()
 for _,divisor in ipairs({3,4})do for _,n in ipairs({0,2,3,4,8,9})do
  local s=state();for i=1,n do s.draw[i]=card(i,'strike')end
  local p=plan(s,{op='aggregateEnergy',value=divisor});eq(p.top[1].op,'energy');eq(p.top[1].value,math.floor(n/divisor))
 end end
 fails(state(),{op='aggregateEnergy',value=2},nil,'invalid Aggregate divisor')
end)

test('Prepared blocks and Blizzard own fresh nested output',function()
 local s=state();s.player.block=99
 local p=plan(s,{op='autoShields',enabled=true,fixed=true,value=11});eq(p.top[1].value,11);eq(p.top[1].fixed,true)
 eq(#plan(s,{op='autoShields',enabled=false,fixed=true,value=-1}).top,0)
 fails(s,{op='autoShields',value=11},nil,'Auto Shields not prepared')
 fails(s,{op='autoShields',enabled=true,fixed=true,value=-1},nil,'invalid Defect engine number')
 local nested={a=7,b={value=9}};local e={op='blizzardDamage',value=4,normalAmounts=nested}
 p=plan(s,e);eq(p.top[1].op,'damageAll');eq(p.top[1].normalAmounts.b.value,9)
 assert(p.top[1].normalAmounts~=nested and p.top[1].normalAmounts.b~=nested.b)
 p.top[1].normalAmounts.b.value=100;eq(nested.b.value,9)
 fails(s,{op='blizzardDamage',value=0},nil,'Blizzard not prepared')
end)

test('Chaos preserves prepared orb order and validates preparation',function()
 local s=state();local e={op='chaosOrbs',value=4,orbs={'dark','frost','lightning','plasma'}}
 local p=plan(s,e);eq(#p.top,4)
 for i,k in ipairs(e.orbs)do eq(p.top[i].op,'channelOrb');eq(p.top[i].orb,k);eq(p.top[i].value,1)end
 eq(#plan(s,{op='chaosOrbs',value=0,orbs={}}).top,0)
 fails(s,{op='chaosOrbs',value=2,orbs={'frost'}},nil,'Chaos not prepared')
 fails(s,{op='chaosOrbs',value=1,orbs={'bad'}},nil,'invalid prepared Chaos orb')
end)

test('Chill and attack initial plans remain lazy at maximum repetition',function()
 for _,op in ipairs({'chillOrbs','randomEngineAttack','thunderStrike'})do
  for _,n in ipairs({0,1,MAX})do
   local s=state();s.cardRandomRng=nil
   local p=plan(s,{op=op,value=7,count=n,times=n})
   eq(#p.top,n==0 and 0 or 1)
   if n>0 then eq(p.top[1].remaining,n);eq(p.top[1].op,op=='chillOrbs' and 'engineChannelRounds' or 'engineRandomRounds')end
   eq(p.cardRandomRng,nil)
  end
  fails(state(),{op=op,value=7,count=-1,times=-1},nil,'invalid Defect engine number')
 end
end)

test('Random rounds select only live actors and clone real RNG',function()
 local s=state();s.player.statuses.strength=2
 s.enemies={actor('dead'),actor('half'),actor('dying'),actor('escaping'),actor('escaped'),actor('live')}
 s.enemies[1].hp=0;s.enemies[2].halfDead=true;s.enemies[3].isDying=true;s.enemies[4].isEscaping=true;s.enemies[5].escaped=true
 local expected=Random.cloneState(s.cardRandomRng);Random.randomInt(expected,0)
 local p=plan(s,{op='engineRandomRounds',value=7,remaining=MAX})
 eq(p.top[1].targetId,'live');eq(p.top[1].normalAmount,9);eq(p.top[2].remaining,MAX-1)
 assert(p.cardRandomRng~=s.cardRandomRng and p.cardRandomRng.primitive~=s.cardRandomRng.primitive)
 eq(p.cardRandomRng.counter,expected.counter);eq(s.cardRandomRng.counter,0)
 local a,b=Random.snapshot(p.cardRandomRng),Random.snapshot(expected)
 eq(a.words[1],b.words[1]);eq(a.words[2],b.words[2])
 eq(#plan(s,{op='engineRandomRounds',value=0,remaining=1}).top,1)
 s.enemies[6].hp=0;s.cardRandomRng=nil
 eq(#plan(s,{op='engineRandomRounds',value=7,remaining=2}).top,0)
 s.enemies[6].hp=1;fails(s,{op='engineRandomRounds',value=7,remaining=2},nil,'random attack requires cardRandomRng')
 fails(s,{op='engineRandomRounds',value=7,remaining=0},nil,'invalid Defect engine number')
end)

test('Sunder refund is queued at bottom only for killed matching target',function()
 local s=state();local e={op='sunderDamage',value=24,normalAmount=25}
 local p=plan(s,e,{target=s.enemies[1]});eq(p.top[1].value,24);eq(p.top[1].normalAmount,25)
 eq(p.top[2].op,'engineSunderRefund');eq(p.top[2].targetId,'a');eq(#p.bottom,0)
 for _,mode in ipairs({'alive','dead','dying','half','escaping','missing'})do
  s.enemies[1]=actor('a');local a=s.enemies[1]
  if mode=='dead'then a.hp=0 elseif mode=='dying'then a.isDying=true elseif mode=='half'then a.halfDead=true elseif mode=='escaping'then a.isEscaping=true end
  p=plan(s,{op='engineSunderRefund',value=999,targetId=mode=='missing' and 'z' or 'a'})
  eq(#p.top,0);eq(#p.bottom,(mode=='dead' or mode=='dying')and 1 or 0)
  if #p.bottom>0 then eq(p.bottom[1].op,'energy');eq(p.bottom[1].value,3)end
 end
 fails(s,e,nil,'Sunder not prepared');fails(s,{op='sunderDamage',value=24},{target=s.enemies[1]},'invalid Defect engine number')
end)

test('X plans cover zero free empty fallback and real Chemical X aliases',function()
 for _,op in ipairs({'tempestOrbs','multiCastOrb'})do
  for _,n in ipairs({0,2})do for _,bonus in ipairs({0,1})do for _,free in ipairs({false,true})do for _,orb in ipairs({false,true})do
   local s=state();if orb then s.orbs.balls={{kind='frost'}}end
   local p=plan(s,{op=op,value=bonus},{energyOnUse=n,freeToPlayOnce=free})
   local enabled=n+bonus>0 and (op=='tempestOrbs' or orb)
   eq(p.consumeAllEnergy,enabled and not free);eq(#p.top,0);eq(#p.bottom,enabled and 1 or 0)
   if enabled then eq(p.bottom[1].remaining,n+bonus);eq(p.bottom[1].op,op=='tempestOrbs' and 'engineChannelRounds' or 'engineEvokeRounds')end
  end end end end
  for _,relic in ipairs({'chemical_x','Chemical X'})do
   local s=state();s.relics={relic};s.orbs.balls={{kind='dark'}}
   eq(plan(s,{op=op,value=1},{energyOnUse=0}).bottom[1].remaining,3)
  end
  local s=state();s.orbs.balls={{kind='plasma'}}
  eq(plan(s,{op=op,value=0}).bottom[1].remaining,3)
  eq(plan(s,{op=op,value=0},{energyOnUse=-1,chemicalX=0}).bottom[1].remaining,3)
  eq(plan(s,{op=op,value=0},{energyOnUse=MAX}).bottom[1].remaining,MAX)
  fails(s,{op=op,value=1},{energyOnUse=MAX},'invalid Defect engine number')
  fails(s,{op=op,value=2},nil,'invalid X upgrade bonus')
  fails(s,{op=op,value=0},{freeToPlayOnce=1},'invalid X free flag')
  fails(s,{op=op,value=0},{chemicalX=2},'Chemical X context override unsupported')
  fails(s,{op=op,value=0},{energyOnUse=-2},'invalid Defect engine number')
 end
end)

test('Channel and evoke rounds retain exact continuation and final removal',function()
 for _,op in ipairs({'engineChannelRounds','engineEvokeRounds'})do
  for _,n in ipairs({1,2,MAX})do
   local p=plan(state(),{op=op,value=999,remaining=n,orb='dark'})
   eq(#p.top,n==1 and 1 or 2);eq(p.top[1].value,1)
   eq(p.top[1].op,op=='engineChannelRounds' and 'channelOrb' or (n==1 and 'evokeOrb' or 'evokeWithoutRemovingOrb'))
   if n>1 then eq(p.top[2].remaining,n-1);eq(p.top[2].value,1);eq(p.top[2].op,op)end
  end
  for _,n in ipairs({0,-1,1.5,2147483648.0})do fails(state(),{op=op,remaining=n,orb='dark'},nil,'invalid Defect engine number')end
 end
 fails(state(),{op='engineChannelRounds',remaining=1,orb='bad'},nil,'invalid channel repetition')
end)

test('Unknown and external nonplanner ops return exactly nil',function()
 for _,op in ipairs({'unknown','stackBlock','applyLockOn','removeBlock','damage',''})do eq(plan(state(),{op=op}),nil)end
 eq(plan(state(),{}),nil)
end)

test('Dynamic Actor Random and query method replacement retains thrown identity',function()
 local s=state();local sentinel={reason='sentinel'}
 replaced(Actors,'attackAmount',function()return 41,0 end,function()
  eq(plan(s,{op='engineRandomRounds',value=7,remaining=1}).top[1].normalAmount,41)
 end)
 replaced(Actors,'attackAmount',function()return 41,'not a minimum'end,function()
  fails(s,{op='engineRandomRounds',value=7,remaining=1},nil,'attempt to compare string with number')
 end)
 for _,dep in ipairs({{Actors,'isActive'},{Actors,'attackAmount'},{Random,'cloneState'},{Random,'randomInt'}})do
  replaced(dep[1],dep[2],function()error(sentinel)end,function()fails(s,{op='engineRandomRounds',value=7,remaining=1},nil,sentinel)end)
 end
 replaced(Queries.shop,'xBonus',function()return 5,'ignored'end,function()
  eq(plan(s,{op='tempestOrbs',value=0},{energyOnUse=0}).bottom[1].remaining,5)
 end)
 replaced(Queries.shop,'xBonus',function()error(sentinel)end,function()fails(s,{op='tempestOrbs',value=0},nil,sentinel)end)
 local replacement={shop={xBonus=function()return 6 end}}
 replaced(package.loaded,'abyss_relic_queries',replacement,function()
  eq(plan(s,{op='tempestOrbs',value=0},{energyOnUse=0}).bottom[1].remaining,6)
 end)
 observe({state=s,sentinel=sentinel},'defect-dynamic-restored')
end)
print('DEFECT_PLAN_BOUNDARIES_PASS '..ran..'/'..registered)
