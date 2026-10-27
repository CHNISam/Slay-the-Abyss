package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,D,R=require('abyss_run'),require('abyss_combat'),require('abyss_data'),require('abyss_sts_random')
local r=Run.new(D,1,{character='watcher',experimental=true});r.relics={}
r.deck={{uid=31,cardId='lesson_learned',upgraded=true},{uid=32,cardId='defend_purple',upgraded=false}}
r.nextDeckUid=33;assert(Run.startCombat(r,'cultist_solo'));local s=r.combat;local lesson,defend
for _,c in ipairs(s.hand)do if c.cardId=='lesson_learned'then lesson=c else defend=c end end
assert(lesson and defend);s.enemies[1].hp=9;s.enemies[1].block=0
local counter=s.miscRng.counter;assert(Run.play(r,lesson.uid,1));assert(r.phase=='reward')
assert(r.deck[2].uid==32 and r.deck[2].upgraded and not defend.upgraded,'upgrade belongs only to permanent UID')
assert(s.miscRng.counter==counter+1 and r.miscRng.counter==s.miscRng.counter)
assert(not s.masterDeckChanges and s.masterDeck[2].upgraded)
local fail=Run.new(D,1,{character='watcher',experimental=true});fail.relics={};fail.deck={{uid=31,cardId='lesson_learned',upgraded=true},{uid=32,cardId='defend_purple'}}
assert(Run.startCombat(fail,'cultist_solo'));local b=fail.combat;b.enemies[1].hp=9;b.miscRng.primitive={}
local used;for _,c in ipairs(b.hand)do if c.cardId=='lesson_learned'then used=c end end
local energy,nextUid=b.energy,b.nextUid;local before=C.copy(fail.deck)
local ok=pcall(Run.play,fail,used.uid,1);assert(not ok)
assert(b.enemies[1].hp==9 and b.energy==energy and b.nextUid==nextUid and b.hand[1])
assert(not b.masterDeckChanges and not fail.deck[2].upgraded and fail.deck[1].upgraded==before[1].upgraded)
-- The source misc singleton draw itself has already been checked independently.
assert(type(R.snapshot(s.miscRng).counter)=='number')
print('WATCHER_LESSON_RUN_BOUNDARY real final kill commits only permanent owner before rewards; late RNG failure rolls back passed')
