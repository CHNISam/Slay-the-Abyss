local Run,C,R,P,Data=require('abyss_run'),require('abyss_combat'),require('abyss_sts_random'),require('abyss_potion_rewards'),require('abyss_data')
local count=0
local function eq(a,b,label)assert(a==b,(label or 'value')..': '..tostring(a)..' ~= '..tostring(b))end
local function same(a,b,path)
 path=path or 'state';eq(type(a),type(b),path)
 if type(a)~='table'then eq(a,b,path);return end
 for k,v in pairs(a)do same(v,b[k],path..'.'..tostring(k))end
 for k in pairs(b)do assert(a[k]~=nil,path..' missing '..tostring(k))end
end
local function unchanged(root)
 local saved={}
 local function visit(t)
  if type(t)~='table' or saved[t]then return end
  local fields={};saved[t]=fields;for k,v in pairs(t)do fields[k]=v;visit(v)end
 end
 visit(root)
 return function()for t,fields in pairs(saved)do for k,v in pairs(fields)do eq(t[k],v,'original reference '..tostring(k))end;for k in pairs(t)do assert(fields[k]~=nil,'added key '..tostring(k))end end end
end
local function test(name,fn)fn();count=count+1;print('ok combat gold '..count..' - '..name)end
local function terminal(tier,seed)
 local run=Run.new(Data,seed or '42');run.floor=tier=='boss' and 16 or tier=='elite' and 7 or 1
 assert(Run.startRoomCombat(run,tier or 'normal'))
 for _,e in ipairs(run.combat.enemies)do e.hp=0 end
 return run
end

test('formal victory generates a random offer and only an explicit click grants gold',function()
 local run=terminal('normal','0');local before=run.gold
 assert(Run.finishCombat(run));eq(run.gold,before);assert(run.rewards.gold>=10 and run.rewards.gold<=20)
 eq(run.treasureRng.counter,1);eq(run.rewards.goldClaimed,false)
 assert(Run.claimGoldReward(run));eq(run.gold,before+run.rewards.gold)
 local old=C.copy(run);assert(not Run.claimGoldReward(run));same(run,old)
end)

test('all eleven exact source outcomes include both endpoints and select only the correct stream',function()
 local G=require('abyss_gold_rewards')
 for _,tier in ipairs({'normal','elite','boss'})do for value=0,10 do
  -- Actual XS128 state: a=0,b=value<2^26 yields nextLong=2*value;
  -- bounded nextLong>>1 is value. This is a controlled boundary, not a seed run.
  local rng=R.restore({words={'0000000000000000',string.format('%016x',value)},counter=0})
  local streams={treasureRng=R.cloneState(rng),miscRng=R.cloneState(rng)};local old=C.copy(streams)
  local amount,key,nextRng=G.prepare(tier,streams,{allEscaped=false})
  eq(amount,(tier=='normal' and 10 or tier=='elite' and 25 or 95)+value)
  eq(key,tier=='boss' and 'miscRng' or 'treasureRng');eq(nextRng.counter,1);same(streams,old)
 end end
end)

test('normal all-escaped skips treasury while mixed defeat and escape retains the roll',function()
 local G=require('abyss_gold_rewards')
 local amount,key,nextRng=G.prepare('normal',{}, {allEscaped=true})
 eq(amount,0);eq(key,nil);eq(nextRng,nil)
 local run=terminal('normal');for _,e in ipairs(run.combat.enemies)do e.escaped=true end
 local before=C.copy(run.treasureRng);assert(Run.finishCombat(run));eq(run.rewards.gold,0);eq(run.rewards.goldClaimed,true);same(run.treasureRng,before)
 local mixed
 for seed=1,30 do
  local candidate=terminal('normal',tostring(seed))
  if #candidate.combat.enemies>1 then mixed=candidate;break end
 end
 assert(mixed,'source multi-enemy fixture unavailable');mixed.combat.enemies[1].escaped=true
 assert(Run.finishCombat(mixed));assert(not mixed.lastResult.allEnemiesEscaped and mixed.rewards.gold>=10);eq(mixed.treasureRng.counter,1)
end)

test('elite and Boss branches precede the normal escape gate',function()
 for _,tier in ipairs({'elite','boss'})do
  local run=terminal(tier);for _,e in ipairs(run.combat.enemies)do e.escaped=true end
  assert(Run.finishCombat(run));assert(run.rewards.gold>0)
  eq(run.treasureRng.counter,tier=='elite' and 1 or 0)
 end
end)

test('new run has raw-seed treasury state and floor changes never reinitialize it',function()
 local a,b=Run.new(Data,'1'),Run.new(Data,'65537')
 eq(a.seed,b.seed);assert(R.snapshot(a.treasureRng).words[1]~=R.snapshot(b.treasureRng).words[1])
 local original=R.snapshot(a.treasureRng)
 a.floor=7;assert(Run.startRoomCombat(a,'elite'));same(R.snapshot(a.treasureRng),original)
 for _,e in ipairs(a.combat.enemies)do e.hp=0 end;assert(Run.finishCombat(a));eq(a.treasureRng.counter,1)
 a.phase='map';a.floor=11;assert(Run.startRoomCombat(a,'normal'));eq(a.treasureRng.counter,1)
 same(R.snapshot(Run.new(Data,'1').treasureRng),original)
end)

test('unfinished and lost battles do not consume either gold stream',function()
 local run=Run.new(Data,'42');assert(Run.startRoomCombat(run,'normal'))
 local before=C.copy(run);assert(not Run.finishCombat(run));same(run,before)
 run.combat.player.hp=0;local treasury,misc=C.copy(run.treasureRng),C.copy(run.miscRng)
 assert(Run.finishCombat(run));eq(run.phase,'defeat');eq(run.rewards,nil);same(run.treasureRng,treasury);same(run.miscRng,misc)
end)

test('invalid source stream refuses reward preparation without changing terminal run or objects',function()
 for _,tier in ipairs({'normal','boss'})do
  local run=terminal(tier);local key=tier=='boss' and 'miscRng' or 'treasureRng'
  run[key].counter=0.5;local before,check=C.copy(run),unchanged(run)
  local ok=pcall(Run.finishCombat,run);eq(ok,false);same(run,before);check()
 end
end)

test('failure after gold prepare and potion commit leaves the full terminal reward transaction private',function()
 for _,tier in ipairs({'normal','boss'})do
  local run=terminal(tier);local before,check=C.copy(run),unchanged(run)
  local commit=P.commit;P.commit=function(...)commit(...);error('after-gold-and-potion')end
  local ok=pcall(Run.finishCombat,run);P.commit=commit
  eq(ok,false);same(run,before);check()
  assert(Run.finishCombat(run));eq(run.treasureRng.counter,tier=='normal' and 1 or 0)
 end
end)

test('existing shared potion stream and continuous treasury survive a later reward failure by identity',function()
 for _,tier in ipairs({'normal','boss'})do
  local run=terminal('normal');assert(Run.finishCombat(run));assert(Run.leaveCombatRewards(run))
  run.floor=tier=='boss' and 16 or 4;assert(Run.startRoomCombat(run,tier))
  for _,e in ipairs(run.combat.enemies)do e.hp=0 end
  local counter=run.treasureRng.counter;local before,check=C.copy(run),unchanged(run)
  local commit=P.commit;P.commit=function(...)commit(...);error('after-existing-stream-commit')end
  local ok=pcall(Run.finishCombat,run);P.commit=commit
  eq(ok,false);same(run,before);check()
  assert(Run.finishCombat(run));eq(run.treasureRng.counter,counter+(tier=='normal' and 1 or 0))
 end
end)

test('post-reward lethal potion failure or rejection preserves both source gold stream owners',function()
 for _,tier in ipairs({'normal','boss'})do for _,mode in ipairs({'throw','reject'})do
  local run=terminal(tier);run.combat.enemies[1].hp=1;assert(Run.obtainPotion(run,'fire_potion'))
  local before,check=C.copy(run),unchanged(run);local finish=Run.finishCombat
  Run.finishCombat=function(candidate)
   assert(finish(candidate));if mode=='throw'then error('post-reward gold')end;return false,'post-reward gold'
  end
  local called,ok,reason=pcall(Run.usePotion,run,1,1);Run.finishCombat=finish
  assert(called and not ok and reason=='potion_effect_failed');same(run,before);check()
  assert(Run.usePotion(run,1,1));eq(run.phase,'reward');eq(run.treasureRng.counter,tier=='normal' and 1 or 0)
 end end
end)

test('overflow and bad gold offer rejects preserve RNG and leave the offer claimable',function()
 local run=terminal('normal');assert(Run.finishCombat(run));local valid=run.rewards.gold
 for _,amount in ipairs({-1,0,0.5,2147483648})do
  run.rewards.gold=amount;local before=C.copy(run);assert(not Run.claimGoldReward(run));same(run,before)
 end
 run.rewards.gold=valid;run.gold=2147483647;local before=C.copy(run);assert(not Run.claimGoldReward(run));same(run,before)
 run.gold=0;assert(Run.claimGoldReward(run));eq(run.gold,valid)
end)

test('parked rewards and independent stolen gold never redraw or multiply the rolled amount',function()
 local run=terminal('normal');run.combat.stolenGoldReward=30;assert(Run.finishCombat(run))
 local amount=run.rewards.gold;local rng,misc=C.copy(run.treasureRng),C.copy(run.miscRng)
 assert(Run.leaveCombatRewards(run));assert(Run.reopenCombatRewards(run));assert(Run.claimStolenGoldReward(run));eq(run.gold,129)
 assert(Run.claimGoldReward(run));eq(run.gold,129+amount);assert(not Run.claimStolenGoldReward(run))
 same(run.treasureRng,rng);same(run.miscRng,misc)
end)

test('legacy explicit-ID fixture retains fixed amounts without a source-parity claim',function()
 local run=Run.new(Data,'42');assert(Run.startCombat(run,'cultist_solo'))
 for _,e in ipairs(run.combat.enemies)do e.hp=0 end
 local before=C.copy(run.treasureRng);assert(Run.finishCombat(run));eq(run.rewards.gold,15);eq(run.combat.roomSeed,nil)
 same(run.treasureRng,before)
end)

print('COMBAT_GOLD_PASS '..count)
