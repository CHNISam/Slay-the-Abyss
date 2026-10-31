-- Real command collection; expected facts come from fixed source semantics, not wallet/victories.
local Run,C,D,A,H=require('abyss_run'),require('abyss_combat'),require('abyss_data'),require('abyss_actor'),require('abyss_relic_hooks')
local function eq(a,b,label)assert(a==b,(label or 'value')..': '..tostring(a)..' ~= '..tostring(b))end
local n=0
local function test(name,fn)fn();n=n+1;print('PASS score collection '..n..' '..name)end
local function battle(tier,seed)
 local r=Run.new(D,seed or '42');r.floor=tier=='elite'and 7 or tier=='boss'and 16 or 1
 assert(Run.startRoomCombat(r,tier or 'normal'));return r,r.combat
end
local function win(r)for _,e in ipairs(r.combat.enemies)do e.hp=0 end;assert(Run.finishCombat(r))end

test('new run owns complete history independent of wallet and battle',function()
 local r,b=battle('normal');assert(r.scoreStats,'new run must collect scoring history')
 eq(r.scoreStats.version,1);eq(r.scoreStats.goldGained,0);eq(r.scoreStats.startingMaxHp,D.rules.player.maxHp)
 assert(b.scoreStats and b.scoreStats~=r.scoreStats)
end)
test('reward collection once, spending and Ectoplasm do not fabricate income',function()
 local r=battle('normal');win(r);eq(r.scoreStats.goldGained,0)
 local gold=r.rewards.gold;assert(Run.claimGoldReward(r));eq(r.scoreStats.goldGained,gold)
 assert(not Run.claimGoldReward(r));eq(r.scoreStats.goldGained,gold)
 r.gold=0;eq(r.scoreStats.goldGained,gold);r.relics={'ectoplasm'};H.gainGold(r,20);eq(r.scoreStats.goldGained,gold)
end)
test('room wins count once, mixed escapes count and all escapes do not',function()
 local r=battle('normal');win(r);eq(r.scoreStats.normalWins,1);assert(not Run.finishCombat(r));eq(r.scoreStats.normalWins,1)
 r=battle('normal');for _,e in ipairs(r.combat.enemies)do e.escaped=true end;assert(Run.finishCombat(r));eq(r.scoreStats.normalWins,0)
 for seed=0,30 do r=battle('normal',tostring(seed));if #r.combat.enemies>1 then break end end;assert(#r.combat.enemies>1);r.combat.enemies[1].escaped=true;win(r);eq(r.scoreStats.normalWins,1)
end)
test('HP_LOSS excluded but actual normal damage survives healing',function()
 local r,b=battle('elite');A.loseHp(b,b.player,5);win(r);eq(r.scoreStats.champion,1);eq(r.scoreStats.eliteWins[1],1)
 r,b=battle('elite');b.player.block=0;C.damage(b,b.enemies[1],b.player,1,true);b.player.hp=b.player.maxHp;win(r);eq(r.scoreStats.champion,0)
end)
test('overkill uses single final damage before remaining HP truncation',function()
 local r,b=battle('normal');local e=b.enemies[1];e.hp=1;e.block=0;C.damage(b,b.player,e,99,true);assert(b.scoreStats.overkill)
 r,b=battle('normal');e=b.enemies[1];e.hp=500;e.block=2;C.damage(b,b.player,e,100,true);eq(b.scoreStats.overkill,false)
 C.damage(b,b.player,e,50,true);C.damage(b,b.player,e,49,true);eq(b.scoreStats.overkill,false)
end)
test('defeat publishes flags and staged income, not victory',function()
 local r,b=battle('normal');b.scoreStats.goldGained=20;b.scoreStats.combo=true;b.scoreStats.overkill=true;b.player.hp=0
 assert(Run.finishCombat(r));eq(r.scoreStats.goldGained,20);assert(r.scoreStats.combo and r.scoreStats.overkill);eq(r.scoreStats.normalWins,0)
end)
test('failed reward generation restores every scoring fact and battle ownership',function()
 local r,b=battle('normal');for _,e in ipairs(b.enemies)do e.hp=0 end;b.scoreStats.goldGained=20;b.scoreStats.combo=true
 r.treasureRng.counter=.5;local stats=r.scoreStats;assert(not pcall(Run.finishCombat,r));eq(r.scoreStats,stats);eq(stats.normalWins,0);eq(stats.goldGained,0);eq(stats.combo,false);eq(b.scoreStats.merged,nil)
end)
print('run score collection '..n..' passed')
