local Run,C,R,D=require('abyss_run'),require('abyss_combat'),require('abyss_sts_random'),require('abyss_data')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b)
 eq(a.counter,b.counter);eq(a.words[1],b.words[1]);eq(a.words[2],b.words[2])
end
do
 local run=Run.new(D,'0');local room=Run.roomStreams(run,2)
 local boundary={misc={
  boolean=function()return R.randomBoolean(room.miscRng)end,
  integer=function(lo,hi)return R.randomIntBetween(room.miscRng,lo,hi)end},
  visualFloat=function(lo,hi)return R.randomFloatBetween(room.visualRng,lo,hi)end}
 local options={seed=42,roomSeed=room.seed,roomStreams=room,
  sourceEncounter='Small Slimes',encounterBoundary=boundary}
 local battle=assert(C.new(run.data,options))
 eq(room.miscRng.counter,1)
 same(R.snapshot(battle.miscRng),R.snapshot(room.miscRng))
 assert(battle.miscRng~=room.miscRng)
 eq(options.enableStances,nil);eq(options.orbSlots,nil)
 eq(options.roomStreams,room);eq(options.encounterBoundary,boundary)
 local before=R.snapshot(room.miscRng);R.randomInt(battle.miscRng,99)
 same(R.snapshot(room.miscRng),before)
 print('PASS source formation callbacks share the room owner; battle adopts its completed cursor privately without changing caller defaults')
end
do
 local run=Run.new(D,'0');run.floor=16
 assert(Run.startRoomCombat(run,'boss'))
 eq(run.combat.miscRng.counter,0)
 for _,enemy in ipairs(run.combat.enemies)do enemy.hp=0 end
 -- Terminal reward boundary, not a natural Guardian victory. Expected words
 -- are the existing independent seed0/floor16 combat-gold vector, unchanged.
 assert(Run.finishCombat(run));eq(run.rewards.gold,99)
 same(R.snapshot(run.miscRng),{counter=1,words={'ccb954bc7af860a2','2ab98db97070fe1b'}})
 eq(run.combat.miscRng.counter,0)
 local before=R.snapshot(run.miscRng);assert(not Run.finishCombat(run))
 same(R.snapshot(run.miscRng),before)
 local gold=run.gold;assert(Run.claimGoldReward(run));eq(run.gold,gold+99)
 assert(not Run.claimGoldReward(run));same(R.snapshot(run.miscRng),before)
 print('PASS the Boss reward commits its independent gold cursor once without rewinding to the battle cursor')
end
print('RUN_ROOM_MISC_OWNERSHIP_PASS 2')
