-- Component-only callbacks and real Actor arithmetic; no Act4 admission claim.
assert(package.searchpath('abyss_spire_pair',package.path),'missing fixed-source Spire pair component')
local P=require('abyss_spire_pair')
local Copy=require('abyss_copy').copy
local R=require('abyss_sts_random')
local A=require('abyss_actor')
local E=require('abyss_events')
local count=0
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b)
 eq(type(a),type(b));if type(a)~='table'then eq(a,b);return end
 for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end
end
local function test(name,fn)fn();count=count+1;print('PASS spire pair '..count..' '..name)end
local function status(id,kind)return{id=id,name=id,description=id,kind=kind or 'buff',stack='intensity',decay='none'}end
local function fixture(seed,slots)
 local catalog={enemies={},statuses={artifact=status('artifact'),strength=status('strength'),focus=status('focus')}}
 P.register(catalog,Copy)
 local s={catalog=catalog,player={id='player',hp=100,maxHp=100,block=0,statuses={}},enemies={},
  hand={},draw={},discard={},exhaust={},events={},phase='player',turn=1,energy=3,
  rules={combat={weakPercent=75,vulnerablePercent=150}},aiRng=R.fromSeed(seed or '1')}
 if slots then s.orbs={slots=slots,balls={},focus=0}end
 for i,definition in ipairs(P.enemies)do
  local e=Copy(definition);e.id,e.definitionId,e.maxHp,e.block,e.statuses=definition.id..'_'..i,definition.id,e.hp,0,{}
  A.bindStatuses(e,catalog.statuses);s.enemies[i]=e
 end
 A.bindStatuses(s.player,catalog.statuses)
 return s,s.enemies[1],s.enemies[2]
end
local api={applyPower=A.applyPower,isActive=A.isActive}
function api.removePower(s,target,id)
 local before=target.statuses[id];if before==nil then return false end
 target.statuses[id]=nil;require('abyss_power_schedule').remove(s,target,id)
 local order={};for _,old in ipairs(target.powerOrder or {})do if old~=id then order[#order+1]=old end end;target.powerOrder=order
 E.emit(s,'status_removed',{target=target.id,status=id,amount=-before});return true
end
local function random(s,n)return R.randomInt(s.aiRng,n-1)+1 end
local function intent(e)return e.intents[e.intentIndex]end
local function pre(s)for _,e in ipairs(s.enemies)do P.preBattle(api,s,e)end end
local function ordinary(s,e,base)return A.attackAmount(s,e,s.player,base)end
local function force(e,id)for i,move in ipairs(e.intents)do if move.id==id then e.intentIndex=i;return end end;error(id)end

test('A0 definitions, registration isolation and explicit elite resolver',function()
 local s,shield,spear=fixture();eq(shield.hp,110);eq(spear.hp,160)
 eq(shield.tier,'elite');eq(spear.tier,'elite');eq(shield.ai.noHpRoll,nil);eq(spear.ai.noHpRoll,nil)
 eq(shield.sourcePosition.x,-1000);eq(spear.sourcePosition.x,70)
 local route=P.resolve('Shield and Spear','elite');same(route.enemies,{'spire_shield','spire_spear'})
 assert(not P.resolve('Shield and Spear','normal'));assert(not P.resolve('The Heart','boss'))
 assert(P.owns(shield)and P.owns(spear)and not P.owns(s.player))
 s.catalog.enemies.spire_shield.hp=1;eq(P.enemies[1].hp,110)
 assert(not pcall(P.register,s.catalog,Copy),'duplicate catalog must refuse')
end)

test('independent shared stream vectors include empty slots and exact continuations',function()
 for _,v in ipairs(dofile('tests/fixtures/spire-pair-vectors.lua'))do
  local s,shield,spear=fixture(v.seed,v.orbSlots)
  P.initialize(s,shield,random);P.initialize(s,spear,random)
  same(R.snapshot(s.aiRng),v.openingAfter)
  for _,step in ipairs(v.steps)do
   eq(intent(shield).id,step.shield);eq(intent(spear).id,step.spear)
   local shieldMove,spearMove=Copy(intent(shield)),Copy(intent(spear))
   local actions=P.takeTurn(s,shield,random,ordinary)
   if shieldMove.id=='bash'then eq(actions[2].status,step.bashPower)end
   P.afterAction(s,shield,random,shieldMove)
   P.takeTurn(s,spear,random,ordinary);P.afterAction(s,spear,random,spearMove)
   same(R.snapshot(s.aiRng),step.after)
  end
  same(R.snapshot(s.aiRng),v.after)
 end
end)

test('preBattle applies source powers, initial left back attack and stable repeated refresh',function()
 local s,shield,spear=fixture();pre(s)
 eq(s.player.statuses.surrounded,1);eq(shield.statuses.artifact,1);eq(spear.statuses.artifact,1)
 eq(shield.statuses.back_attack,1);eq(spear.statuses.back_attack or 0,0)
 assert(P.backAttack(s,shield)and not P.backAttack(s,spear))
 local events=#s.events;P.refreshFacing(api,s);eq(#s.events,events)
end)

test('explicit target admission changes facing; nonpair or dead targets refuse without mutation',function()
 local s,shield,spear=fixture();pre(s)
 assert(P.faceTarget(api,s,shield));assert(not P.backAttack(s,shield));assert(P.backAttack(s,spear))
 eq(shield.statuses.back_attack or 0,0);eq(spear.statuses.back_attack,1)
 assert(P.faceTarget(api,s,spear));assert(P.backAttack(s,shield))
 local old=Copy(s.spirePair);assert(not P.faceTarget(api,s,s.player));same(s.spirePair,old)
 shield.hp=0;assert(not P.faceTarget(api,s,shield));same(s.spirePair,old)
end)

test('actual and intent back attack preserve their distinct integer boundaries',function()
 local s,shield,spear=fixture();pre(s)
 eq(P.actualDamage(s,shield,12),18);eq(P.actualDamage(s,spear,5),5)
 shield.statuses.weak=1;s.player.statuses.vulnerable=1
 local normal=ordinary(s,shield,12);eq(normal,13);eq(P.actualDamage(s,shield,normal),19)
 eq(P.intentDamage(s,shield,13.5,function(n)return n end),20)
 eq(P.intentDamage(s,shield,13.5,function(n)return math.min(n,1)end),1)
 assert(P.faceTarget(api,s,shield));eq(P.actualDamage(s,shield,normal),13)
 assert(not pcall(P.actualDamage,s,shield,1.5))
end)

test('Bash freezes slot-aware debuff before damage and avoids zero-slot boolean draw',function()
 for _,slots in ipairs({0,3})do
  local s,shield=fixture('1',slots);force(shield,'bash');local before=s.aiRng.counter
  local actions=P.takeTurn(s,shield,random,ordinary)
  eq(s.aiRng.counter,before+(slots>0 and 1 or 0));eq(actions[1].kind,'damage')
  eq(actions[2].kind,'power');eq(actions[2].targetId,'player');eq(actions[2].value,-1)
  eq(actions[#actions].kind,'roll');s.orbs.slots=0
  assert(actions[2].status=='focus'or actions[2].status=='strength')
 end
 local s,shield=fixture('1',3);s.aiRng=nil;force(shield,'bash')
 local calls=0;local actions=P.takeTurn(s,shield,function(_,n)eq(n,2);calls=calls+1;return 2 end,ordinary)
 eq(calls,1);eq(actions[2].status,'focus');s.orbs.balls={};eq(actions[2].status,'focus')
end)

test('Smash freezes post-modifier output as Block rather than lost HP or base damage',function()
 local s,shield=fixture();pre(s);force(shield,'smash');shield.statuses.strength=2;s.player.block=99
 local actions=P.takeTurn(s,shield,random,ordinary)
 eq(actions[1].normalAmount,54);eq(actions[2].kind,'block');eq(actions[2].value,54)
 shield.statuses.strength=100;eq(actions[2].value,54);eq(actions[3].kind,'roll')
end)

test('Fortify/Piercer target source order and Burn Strike preserves separate hits then discard',function()
 local s,shield,spear=fixture();force(shield,'fortify')
 local block=P.takeTurn(s,shield,random,ordinary)
 eq(block[1].targetId,shield.id);eq(block[2].targetId,spear.id);eq(block[1].value,30);eq(block[3].kind,'roll')
 force(spear,'piercer');local powers=P.takeTurn(s,spear,random,ordinary)
 eq(powers[1].targetId,shield.id);eq(powers[2].targetId,spear.id);eq(powers[1].status,'strength');eq(powers[1].value,2)
 force(spear,'burn_strike');local burn=P.takeTurn(s,spear,random,ordinary)
 eq(#burn,4);eq(burn[1].normalAmount,5);eq(burn[2].normalAmount,5)
 eq(burn[3].kind,'discard');eq(burn[3].card,'burn');eq(burn[3].value,2);eq(burn[4].kind,'roll')
 force(spear,'skewer');local skew=P.takeTurn(s,spear,random,ordinary)
 eq(#skew,4);for i=1,3 do eq(skew[i].normalAmount,10)end
end)

test('death immediately faces survivor and queues removals once without inventing instant drains',function()
 for deadIndex=1,2 do
  local s,shield,spear=fixture();pre(s);P.faceTarget(api,s,s.enemies[deadIndex])
  local dead=s.enemies[deadIndex];local survivor=s.enemies[3-deadIndex];dead.hp=0
  local queued={};local function enqueue(effect)queued[#queued+1]=effect end
  assert(P.died(s,dead,enqueue));assert(not P.died(s,dead,enqueue))
  eq(s.spirePair.facingLeft,deadIndex==2);eq(#queued,2)
  eq(queued[1].targetId,'player');eq(queued[1].status,'surrounded')
  eq(queued[2].targetId,survivor.id);eq(queued[2].status,'back_attack')
  eq(s.player.statuses.surrounded,1,'removal remains queued until shared executor runs')
  for _,effect in ipairs(queued)do api.removePower(s,effect.targetId=='player'and s.player or survivor,effect.status)end
  assert(not P.backAttack(s,survivor));eq(survivor.statuses.back_attack or 0,0)
 end
end)

test('captured RollMove survives source death while generic damage/block execution remains external',function()
 local s,shield,spear=fixture();P.initialize(s,shield,random);P.initialize(s,spear,random)
 local captured=Copy(intent(shield));shield.hp=0;local before=s.aiRng.counter
 P.afterAction(s,shield,random,captured);eq(s.aiRng.counter,before+1)
 local plain={id='foreign',hp=1,statuses={}};local snapshot=Copy(s)
 assert(not P.died(s,plain,function()error('foreign death enqueued')end));same(s,snapshot)
end)
eq(count,10);print('SPIRE_PAIR_COMPONENT_PASS '..count)
