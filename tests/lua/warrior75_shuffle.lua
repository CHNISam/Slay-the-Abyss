-- Independent expected ordering: repository oracle sts1_combat_shuffle.py
-- (source 319009d), room seed 42 + floor 1; not PC binary/platform evidence.
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,Run,R=require('abyss_combat'),require('abyss_run'),require('abyss_sts_random')
local data=require('abyss_data')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function uids(cards)local ids={};for _,c in ipairs(cards)do ids[#ids+1]=c.uid end;return table.concat(ids,',')end
local deck={};for _=1,10 do deck[#deck+1]='strike' end
local s=C.new(data,{deck=deck,seed=101,shuffleSeed='43',enemies={'cultist'}})
eq(uids(s.hand),'8,3,9,2,5');eq(uids(s.draw),'4,7,6,1,10');eq(s.shuffleRng.counter,1)
local run=Run.new(data,42);assert(Run.startCombat(run,'cultist_solo'))
eq(uids(run.combat.hand),'8,3,9,2,5');eq(run.combat.shuffleRng.counter,1);eq(run.combat.cardRandomRng.counter,0)
for _,size in ipairs({0,1})do
 local d={};if size==1 then d={'strike'}end
 local b=C.new(data,{deck=d,shuffleSeed='43',enemies={'cultist'}})
 eq(b.shuffleRng.counter,size==0 and 1 or 2);eq(#b.hand,size)
end
local b=C.new(data,{deck={},shuffleSeed='43',enemies={'cultist'}})
b.draw={{uid=21,cardId='strike'},{uid=22,cardId='strike'}};b.hand={};b.discard={};local n=b.shuffleRng.counter
C.draw(b,5);eq(uids(b.hand),'22,21');eq(b.shuffleRng.counter,n+1)
C.draw(b,5);eq(b.shuffleRng.counter,n+1) -- wholly empty skips
b.discard={{uid=23,cardId='strike'}};b.player.noDraw=true;C.draw(b,1);eq(b.shuffleRng.counter,n+1)
b.player.noDraw=false;while #b.hand<10 do b.hand[#b.hand+1]={uid=30+#b.hand,cardId='strike'}end
C.draw(b,1);eq(#b.discard,1);eq(b.shuffleRng.counter,n+1)
-- A failed card that shuffles must restore the exact old RNG/pile objects.
b.hand={{uid=1,cardId='shrug_it_off'}};b.draw={};b.discard={{uid=2,cardId='strike'}};b.energy=3
b.catalog.cards.shrug_it_off.effects={{op='draw',value=1},{op='gainStatus',status='missing_test_status',value=1}}
local rng,primitive,pile=b.shuffleRng,b.shuffleRng.primitive,b.discard;local before=R.cloneState(rng)
eq(pcall(C.play,b,1),false);eq(b.shuffleRng,rng);eq(rng.primitive,primitive);eq(rng.counter,before.counter);eq(b.discard,pile);eq(#pile,1)
local innate={};for _=1,7 do innate[#innate+1]={cardId='brutality',upgraded=true}end
local opening=C.new(data,{deck=innate,shuffleSeed='43',enemies={'cultist'}})
eq(#opening.hand,7);eq(#opening.draw,0);eq(opening.openingInnateExtra,nil)
print('Warrior75 shuffle: source vector, split draw, empty/full/locked, rollback and seven-Innate opening passed.')
