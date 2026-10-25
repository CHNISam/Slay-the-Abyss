package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,A,R,Data=require('abyss_run'),require('abyss_combat'),require('abyss_actor'),require('abyss_sts_random'),require('abyss_data')
local passed,failed=0,0
local function test(name,fn)local ok,why=pcall(fn);if ok then passed=passed+1;print('PASS '..name)else failed=failed+1;print('FAIL '..name..': '..tostring(why))end end
local function same(a,b)
 assert(type(a)==type(b));if type(a)~='table' then assert(a==b);return end
 for k,v in pairs(a) do same(v,b[k]) end;for k in pairs(b) do assert(a[k]~=nil) end
end
local function battle()
 local r=Run.new(Data,42);assert(Run.obtainPotion(r,'distilled_chaos'));assert(Run.startCombat(r,'cultist_solo'))
 local s=r.combat;s.hand={};s.draw={};s.discard={};s.enemies[1].hp=1000;s.enemies[1].maxHp=1000
 return r,s
end
test('Chaos uses top cards FIFO for free without Havoc exhaust and consumes all three target draws up front',function()
 local r,s=battle();s.draw={{cardId='inflame',uid=3003},{cardId='strike',uid=3002},{cardId='defend',uid=3001}}
 local rng=R.cloneState(s.cardRandomRng);for i=1,3 do R.randomInt(rng,0) end
 local start=#s.events;assert(Run.usePotion(r,1));local played={}
 for i=start+1,#s.events do local e=s.events[i];if e.kind=='play' then played[#played+1]=e.detail.uid end end
 same(played,{3001,3002,3003});assert(s.energy==3 and s.player.block==5 and s.player.statuses.strength==2)
 assert(s.enemies[1].hp==994 and #s.discard==2 and #s.exhaust==0 and #s.draw==0 and not s.cardActions)
 same(R.snapshot(s.cardRandomRng),R.snapshot(rng))
end)
test('Chaos preserves original invalid-card disposal instead of forcing Burn Dazed or blocked Clash to exhaust',function()
 local r,s=battle();s.hand={{cardId='defend',uid=3100}}
 s.draw={{cardId='clash',uid=3103},{cardId='dazed',uid=3102},{cardId='burn',uid=3101}}
 assert(Run.usePotion(r,1));assert(#s.exhaust==0 and #s.discard==3 and #s.hand==1 and s.energy==3)
 for _,e in ipairs(s.events) do assert(e.kind~='play','rejected cards must not dispatch play hooks') end
end)
test('Chaos snapshots energyOnUse before earlier queued cards gain energy',function()
 local r,s=battle();s.draw={{cardId='whirlwind',uid=3202},{cardId='bloodletting',uid=3201}}
 assert(Run.usePotion(r,1));assert(s.energy==5 and s.enemies[1].hp==985,'Whirlwind uses original three energy without spending it')
end)
test('Chaos empty-pile shuffle happens during top-card actions before any queued card disposes',function()
 local r,s=battle();s.discard={{cardId='defend',uid=3301}}
 assert(Run.usePotion(r,1));assert(#s.discard==1 and s.player.block==5 and #s.exhaust==0)
end)
test('Chaos triggered victory clears remaining queued cards but preserves target RNG consumption',function()
 local r,s=battle();s.enemies[1].hp=1;s.draw={{cardId='inflame',uid=3403},{cardId='defend',uid=3402},{cardId='strike',uid=3401}}
 local rng=R.cloneState(s.cardRandomRng);for i=1,3 do R.randomInt(rng,0) end
 assert(Run.usePotion(r,1));assert(r.phase=='reward' and not s.cardActions and not s.queuedCards)
 assert((s.player.statuses.strength or 0)==0 and s.player.block==0);same(R.snapshot(s.cardRandomRng),R.snapshot(rng))
end)
test('Chaos late queue failure discards the staged battle and preserves bottle and live references',function()
 local r,s=battle();s.draw={{cardId='invalid_queue_fixture',uid=3502},{cardId='defend',uid=3501}}
 local before=C.copy(r);local hand,draw,events,potions=s.hand,s.draw,s.events,r.potions
 local ok,why=Run.usePotion(r,1);assert(not ok and why=='potion_effect_failed');same(r,before)
 assert(r.combat==s and s.hand==hand and s.draw==draw and s.events==events and r.potions==potions)
end)
test('Chaos attack counters survive immediate Smoke and rebuild in the next battle',function()
 local r=Run.new(Data,42)
 assert(Run.obtainRelic(r,'pen_nib'));assert(Run.obtainRelic(r,'nunchaku'))
 r.relicCounters.pen_nib=8;r.relicCounters.nunchaku=8
 assert(Run.obtainPotion(r,'distilled_chaos'));assert(Run.obtainPotion(r,'smoke_bomb'))
 assert(Run.startCombat(r,'cultist_solo'))
 r.combat.hand={};r.combat.draw={{cardId='strike',uid=3603},{cardId='strike',uid=3602},{cardId='strike',uid=3601}};r.combat.discard={}
 assert(Run.usePotion(r,1));assert(r.phase=='combat','normal Cultist survives the three attacks')
 assert(r.combat.relicCounters.pen_nib==1 and r.combat.relicCounters.nunchaku==1)
 assert(r.relicCounters.pen_nib==1 and r.relicCounters.nunchaku==1,'automatic attacks must commit persistent counters')
 assert(Run.usePotion(r,2));assert(r.phase=='map' and r.lastResult.outcome=='escaped')
 assert(Run.startCombat(r,'cultist_solo'))
 assert(r.combat.relicCounters.pen_nib==1 and r.combat.relicCounters.nunchaku==1,'next encounter must retain automatic attacks')
end)
print('LUA_POTION_CHAOS '..passed..' passed '..failed..' failed');assert(failed==0)
