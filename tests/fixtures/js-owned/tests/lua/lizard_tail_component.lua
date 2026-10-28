package.path='src/lua/?.lua;'..package.path
local found,T=pcall(require,'abyss_lizard_tail')
assert(found,'LIZARD_TAIL_COMPONENT_MISSING: fixed-source one-shot callback owner required')
local Copy,R,Snapshot=require('abyss_copy').copy,require('abyss_sts_random'),require('abyss_snapshot')
local count=0
local function test(name,fn)fn();count=count+1;print('PASS Lizard component '..count..' '..name)end
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b)
 if a==b then return end;eq(type(a),type(b));if type(a)~='table'then eq(a,b);return end
 for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil,tostring(k))end
end
local function owner(id)
 return {relics={id or 'lizard_tail'},relicCounters={lizard_tail=-1,other=7},
  miscRng=R.fromSeed('42'),potions={[2]='fairy_in_a_bottle'}}
end
local function rejects(fn,needle)
 local ok,why=pcall(fn);assert(not ok and tostring(why):find(needle,1,true),tostring(why))
end
test('ownership recognizes both exact source identities without changing owner',function()
 for _,id in ipairs({'lizard_tail','Lizard Tail'})do local o=owner(id);local before=Copy(o);assert(T.has(o));same(o,before)end
 assert(not T.has(nil)and not T.has({relics={}})and not T.has({relics={'LizardTail'}}))
end)
test('new obtain initializes once while explicit fresh reacquisition is the caller boundary',function()
 local o=owner();o.relicCounters.lizard_tail=-2
 assert(T.onObtain(o));eq(o.relicCounters.lizard_tail,-1);eq(o.relicCounters.other,7)
 o.relicCounters.lizard_tail=-2;o.relics={};eq(T.state(o),nil)
 o.relics={'Lizard Tail'};assert(T.onObtain(o));eq(T.state(o),'available')
 local absent={relics={}};rejects(function()T.onObtain(absent)end,'owner');eq(absent.relicCounters,nil)
end)
test('bind initializes missing owned counter and preserves the spent instance',function()
 local o=owner();o.relicCounters=nil;assert(T.bind(o));eq(o.relicCounters.lizard_tail,-1)
 o.relicCounters.other=9;o.relicCounters.lizard_tail=-2;local counters=o.relicCounters
 assert(T.bind(o));assert(o.relicCounters==counters);eq(T.state(o),'spent');eq(counters.other,9)
 o.relicCounters.lizard_tail=-1;assert(T.bind(o));eq(counters.lizard_tail,-1)
 local absent={relics={}};assert(not T.bind(absent));eq(absent.relicCounters,nil)
end)
test('invalid counters never silently bind or rearm',function()
 for _,value in ipairs({-3,0,1,1.5,'-1',false,0/0,math.huge,{}})do
  local o=owner();o.relicCounters.lizard_tail=value
  rejects(function()T.bind(o)end,'counter')
  if value~=value then assert(o.relicCounters.lizard_tail~=o.relicCounters.lizard_tail)else eq(o.relicCounters.lizard_tail,value)end
  rejects(function()T.state(o)end,'counter')
 end
 local o=owner();o.relicCounters={};rejects(function()T.state(o)end,'counter');eq(next(o.relicCounters),nil)
 assert(T.bind(o));eq(T.state(o),'available')
 for _,invalid in ipairs({'-1',setmetatable({},{__index={lizard_tail=-1}})})do
  o=owner();o.relicCounters=invalid
  rejects(function()T.bind(o)end,'counter');eq(o.relicCounters,invalid)
 end
end)
test('state is read-only and gives Mark block priority only to an unused Tail',function()
 for _,mark in ipairs({'mark_of_bloom','Mark of the Bloom'})do
  local o=owner();o.relics[2]=mark;local before=Copy(o)
  eq(T.state(o),'blocked_by_mark');same(o,before)
  o.relicCounters.lizard_tail=-2;before=Copy(o);eq(T.state(o),'spent');same(o,before)
 end
end)
test('integer division minimum and maximum source bounds reach one callback',function()
 for _,case in ipairs({{1,1},{2,1},{3,1},{5,2},{6,3},{81,40},{2147483647,1073741823}})do
  local o=owner();local a={hp=-1,maxHp=case[1]};local calls=0
  local rng=R.snapshot(o.miscRng)
  local used,base=T.tryRevive(o,a,function(amount)
   calls=calls+1;eq(amount,case[2]);eq(a.hp,0);eq(o.relicCounters.lizard_tail,-1)
   a.hp=math.min(a.maxHp,a.hp+amount)
  end)
  assert(used);eq(base,case[2]);eq(calls,1);eq(a.hp,case[2]);eq(T.state(o),'spent');same(R.snapshot(o.miscRng),rng)
 end
end)
test('ordinary healing policy belongs entirely to the callback',function()
 local o=owner();local a={hp=0,maxHp=6};local calls=0
 local used,base=T.tryRevive(o,a,function(amount)calls=calls+1;a.hp=math.floor(amount*1.5+.5);return false end)
 assert(used);eq(base,3);eq(a.hp,5);eq(calls,1);eq(o.relicCounters.lizard_tail,-2)
 -- Source heal is void: a normally returning callback, even nil/false, has
 -- completed its policy. It must throw to reject, leaving rollback to caller.
end)
test('Mark never calls heal consumes a bottle or spends the Tail',function()
 for _,mark in ipairs({'mark_of_bloom','Mark of the Bloom'})do
  local o=owner();o.relics[2]=mark;local before=Copy(o);local a={hp=0,maxHp=81}
  assert(not T.tryRevive(o,a,function()error('Mark must gate callback')end));same(o,before);eq(a.hp,0)
 end
end)
test('spent living and unowned paths are inert and never consume potion inventory',function()
 for _,mode in ipairs({'spent','living','unowned'})do
  local o=owner();local a={hp=mode=='living'and 1 or 0,maxHp=80}
  if mode=='spent'then o.relicCounters.lizard_tail=-2 elseif mode=='unowned'then o.relics={}end
  local before,actor=Copy(o),Copy(a)
  assert(not T.tryRevive(o,a,function()error('not a trigger')end));same(o,before);same(a,actor)
 end
 local o=owner();local inventory=Copy(o.potions);local a={hp=0,maxHp=80}
 assert(T.tryRevive(o,a,function(amount)a.hp=amount end));same(o.potions,inventory)
 -- Fairy selection is deliberately absent; coordinator must call it first.
end)
test('throw preserves unspent counter and caller snapshot restores the complete graph',function()
 local o,a=owner(),{hp=-3,maxHp=80};local root={owner=o,actor=a};local before=Copy(root)
 local counters=o.relicCounters;local restore=Snapshot.capture(root)
 rejects(function()T.tryRevive(o,a,function(amount)a.hp=amount;o.extra=true;error('LATE_HEAL_FAULT')end)end,'LATE_HEAL_FAULT')
 eq(o.relicCounters.lizard_tail,-1);eq(a.hp,40);assert(o.extra)
 restore();same(root,before);assert(root.owner==o and o.relicCounters==counters and root.actor==a)
 assert(T.tryRevive(o,a,function(amount)a.hp=amount end));eq(counters.lizard_tail,-2)
 a.hp=0;assert(not T.tryRevive(o,a,function()error('second trigger')end))
end)
test('invalid actor or callback refuses before any counter or HP write',function()
 for _,maximum in ipairs({0,-1,1.5,2147483648,'80',math.huge})do
  local o,a=owner(),{hp=-1,maxHp=maximum}
  rejects(function()T.tryRevive(o,a,function()error('invalid max')end)end,'actor')
  eq(a.hp,-1);eq(o.relicCounters.lizard_tail,-1)
 end
 local o,a=owner(),{hp=0,maxHp=80}
 rejects(function()T.tryRevive(o,a,nil)end,'callback');eq(a.hp,0);eq(o.relicCounters.lizard_tail,-1)
 o.relicCounters={};rejects(function()T.tryRevive(o,a,function()end)end,'counter');eq(next(o.relicCounters),nil)
end)
print('LIZARD_TAIL_COMPONENT_PASS '..count..' groups; callback-only, no Fairy ordering or Run/event/native admission')
