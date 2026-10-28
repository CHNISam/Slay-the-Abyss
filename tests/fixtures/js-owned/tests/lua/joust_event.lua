local J=require('abyss_joust_event')
local Run=require('abyss_run')
local R=require('abyss_sts_random')
local C=require('abyss_combat')
local Data=require('abyss_data')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b)
 if type(a)~='table'then eq(a,b);return end
 eq(type(b),'table');for k,v in pairs(a)do same(v,b[k])end
 for k in pairs(b)do assert(a[k]~=nil,tostring(k))end
end
local function fixture(seed)
 local r=Run.new(Data,'42');r.phase='node';r.gold=100
 r.miscRng=R.fromSeed(tostring(seed or 0));r.nodeFlow={type='event',event={id='joust'}}
 J.prepare(r,r.nodeFlow.event);return r
end
local function snapshot(r)return C.copy(r,{[r.data]=r.data})end
local function choose(r,choice,uid)
 return Run.transaction(r,function(s)return J.choose(s,s.nodeFlow,choice,uid)end)
end
local function reject(r,choice,uid)
 local before=snapshot(r);local flow,event=r.nodeFlow,r.nodeFlow.event
 local ok,why=choose(r,choice,uid);eq(ok,false);eq(why,'invalid_event_choice');same(r,before)
 eq(r.nodeFlow,flow);eq(r.nodeFlow.event,event)
end
local n=0
local function test(name,fn)fn();n=n+1;print('PASS joust '..n..' '..name)end
test('five source screens retain confirmation, payment, draw and payout timing',function()
 local r=fixture();local original=R.snapshot(r.miscRng)
 eq(r.nodeFlow.event.stage,'halt');eq(#J.options(r,r.nodeFlow.event),1)
 reject(r,'bet_against');reject(r,'leave');reject(r,'continue',1)
 assert(choose(r,'continue'));eq(r.nodeFlow.event.stage,'explanation');eq(r.gold,100);same(R.snapshot(r.miscRng),original)
 local options=J.options(r,r.nodeFlow.event);eq(options[1].choice,'bet_against');eq(options[2].choice,'bet_for')
 assert(choose(r,'bet_against'));eq(r.nodeFlow.event.stage,'pre_joust');eq(r.gold,50);same(R.snapshot(r.miscRng),original)
 reject(r,'bet_against');reject(r,'leave')
 assert(choose(r,'continue'));eq(r.nodeFlow.event.stage,'joust');eq(r.gold,50);eq(r.miscRng.counter,1)
 assert(choose(r,'continue'));eq(r.nodeFlow.event.stage,'complete');eq(r.miscRng.counter,1)
 eq(r.gold,50+r.nodeFlow.event.goldGained);eq(J.options(r,r.nodeFlow.event)[1].choice,'leave')
 reject(r,'continue');reject(r,'bet_for');local before=snapshot(r)
 local ok,status=choose(r,'leave');assert(ok);eq(status,'complete');same(r,before)
end)
test('source boolean chance uses binary32 0.3f once for either bet over real seeds',function()
 local wins,losses=0,0
 for seed=0,31 do
  for _,bet in ipairs({'bet_against','bet_for'})do
   local r=fixture(seed);local oracle=R.cloneState(r.miscRng)
   local expected=R.randomFloat(oracle)<0.30000001192092896
   assert(choose(r,'continue'));assert(choose(r,bet));assert(choose(r,'continue'))
   eq(r.nodeFlow.event.ownerWins,expected);same(R.snapshot(r.miscRng),R.snapshot(oracle))
   assert(choose(r,'continue'));local won=(bet=='bet_for')==expected
   eq(r.nodeFlow.event.won,won);eq(r.nodeFlow.event.payout,won and (bet=='bet_for' and 250 or 100)or 0)
   eq(r.gold,50+(won and (bet=='bet_for' and 250 or 100)or 0));eq(r.miscRng.counter,1)
   if expected then wins=wins+1 else losses=losses+1 end
  end
 end
 assert(wins>0 and losses>0)
end)
test('stale funds use source clamp and event payment does not spend-shop Maw Bank',function()
 for _,gold in ipairs({0,1,49,50,100})do
  local r=fixture();assert(choose(r,'continue'));r.gold=gold
  r.relics={'maw_bank'};r.relicCounters={maw_bank=0}
  local before=R.snapshot(r.miscRng);assert(choose(r,'bet_for'))
  eq(r.gold,math.max(0,gold-50));eq(r.nodeFlow.event.goldPaid,math.min(gold,50))
  eq(r.relicCounters.maw_bank,0);same(R.snapshot(r.miscRng),before)
 end
end)
test('outcome invokes permanent gold rules and Ectoplasm blocks payout without reroll',function()
 local observed=0
 for seed=0,15 do
  local r=fixture(seed);r.relics={'ectoplasm'}
  assert(choose(r,'continue'));assert(choose(r,'bet_against'));assert(choose(r,'continue'));assert(choose(r,'continue'))
  eq(r.gold,50);eq(r.nodeFlow.event.goldGained,0);eq(r.miscRng.counter,1)
  if r.nodeFlow.event.won then eq(r.nodeFlow.event.payout,100);observed=observed+1 end
 end
 assert(observed>0)
end)
test('fault after payout mutation rolls back and retries same already-drawn winner',function()
 local r=fixture(0);local oracle=R.cloneState(r.miscRng)
 local ownerWins=R.randomFloat(oracle)<0.30000001192092896
 assert(choose(r,'continue'));assert(choose(r,ownerWins and 'bet_for' or 'bet_against'));assert(choose(r,'continue'))
 eq(r.nodeFlow.event.ownerWins,ownerWins);local original=Run.gainGold;local before=snapshot(r)
 Run.gainGold=function(staged,value)original(staged,value);R.randomInt(staged.miscRng,99);error('joust payout failure')end
 local ok,why=choose(r,'continue');eq(ok,false);eq(why,'transaction_failed');same(r,before)
 Run.gainGold=original;assert(choose(r,'continue'));eq(r.gold,50+(ownerWins and 250 or 100));eq(r.miscRng.counter,1)
end)
test('view construction never writes owner and malformed stage/choice/UID never advances',function()
 local r=fixture();local before=snapshot(r);local options=J.options(r,r.nodeFlow.event)
 options[1].choice='leave';same(r,before);reject(r,'');reject(r,nil);reject(r,1)
 r.nodeFlow.event.stage='unknown';same(J.options(r,r.nodeFlow.event),{});reject(r,'continue')
end)
print('JOUST_EVENT '..n..' passed')
