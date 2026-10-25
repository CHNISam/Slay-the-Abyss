package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,R,Data=require('abyss_run'),require('abyss_combat'),require('abyss_sts_random'),require('abyss_data')
local run=Run.new(Data,42);assert(Run.obtainPotion(run,'snecko_oil'));assert(Run.startCombat(run,'cultist_solo'))
local s=run.combat;s.player.noDraw=true
s.hand={{cardId='bash',uid=1000,costForTurn=0},{cardId='burn',uid=1001},{cardId='whirlwind',uid=1002},
 {cardId='defend',uid=1003},{cardId='blood_for_blood',uid=1004,costReduction=2}}
local rng=R.cloneState(s.cardRandomRng);local rolls={R.randomInt(rng,3),R.randomInt(rng,3),R.randomInt(rng,3)}
local base={2,1,2};assert(Run.usePotion(run,1))
for n,i in ipairs({1,4,5}) do
 local card=s.hand[i];local expected=rolls[n]==base[n] and (i==1 and 0 or base[n]) or rolls[n]
 assert(C.cardDefinition(s,card).cost==expected)
end
assert(s.hand[2].costForTurn==nil and s.hand[3].costForTurn==nil)
assert(R.snapshot(s.cardRandomRng).counter==R.snapshot(rng).counter)
local saved=C.cardDefinition(s,s.hand[4]).cost;s.hand[4].costForTurn=nil;assert(C.cardDefinition(s,s.hand[4]).cost==saved)
local original=s.hand[1];local pre=C.cardDefinition(s,original).cost;C.upgrade(s,original)
assert(C.cardDefinition(s,original).cost==(pre==0 and 0 or 1))
local discounted={cardId='blood_for_blood',uid=1900,costOverride=2,costForTurn=2,costReduction=0}
assert(C.upgrade(s,discounted));assert(C.cardDefinition(s,discounted).cost==1,'upgrade reduces actual randomized BloodForBlood cost by one')
assert(run.deck[1].costOverride==nil)
local drawn=Run.new(Data,43);assert(Run.obtainPotion(drawn,'snecko_oil'));assert(Run.startCombat(drawn,'cultist_solo'))
local ds=drawn.combat;ds.hand={{cardId='defend',uid=2000}};ds.draw={}
for i=1,5 do ds.draw[i]={cardId='defend',uid=2000+i} end
ds.discard={};local expect=R.cloneState(ds.cardRandomRng);local costs={}
for i=1,6 do costs[i]=R.randomInt(expect,3) end
assert(Run.usePotion(drawn,1));assert(#ds.hand==6 and #ds.draw==0)
for i,c in ipairs(ds.hand) do assert(C.cardDefinition(ds,c).cost==costs[i]) end
assert(R.snapshot(ds.cardRandomRng).counter==R.snapshot(expect).counter)
print('LUA_POTION_SNECKO_PASS 2')
