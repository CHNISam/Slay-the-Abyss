package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,A,Run,Data=require('abyss_combat'),require('abyss_card_actions'),require('abyss_run'),require('abyss_data')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local r=Run.new(Data,42);r.deck={{uid=31,cardId='thinking_ahead'},{uid=32,cardId='defend'},{uid=33,cardId='defend'},{uid=34,cardId='defend'}}
assert(Run.obtainPotion(r,'duplication_potion'));assert(Run.startCombat(r,'cultist_solo'));assert(Run.usePotion(r,1))
local s=r.combat;local original
for _,card in ipairs(s.hand)do if card.cardId=='thinking_ahead'then original=card end end
assert(Run.play(r,original.uid));assert(s.pendingChoice and #s.queuedCards==1)
local duplicate=s.queuedCards[1].card
assert(duplicate.uid~=original.uid,'SameInstance auto copy needs a fresh physical UID')
eq(duplicate.uuid,original.uuid);eq(duplicate.deckUid,31)
local choices=0
while s.pendingChoice do
 choices=choices+1;assert(choices<=3)
 local seen={}
 for _,pile in ipairs({s.hand,s.draw,s.discard,s.exhaust})do for _,card in ipairs(pile)do assert(not seen[card.uid]);seen[card.uid]=true end end
 if s.cardInUse then assert(not seen[s.cardInUse.uid],'in-use physical UID collides with a pile')end
 assert(Run.chooseCard(r,s.pendingChoice.token,s.pendingChoice.uids[1]))
end
eq(#s.exhaust,1);eq(s.exhaust[1],original)
-- Real source definition; this portion checks construction/identity only.
s=C.new(Data,{deck={},enemies={'jaw_worm'},seed=1})
s.catalog.cards.genetic_algorithm={id='genetic_algorithm',sourceId='Genetic Algorithm',type='skill',cost=1,misc=1,
 effects={{op='increaseGeneticMisc',value=2},{op='block',value=1}},upgrade={effects={{op='increaseGeneticMisc',value=3},{op='block',value=1}}}}
for _,permanent in ipairs({false,true})do
 local prototype=A.fresh(C,s,'genetic_algorithm');prototype.misc=7;prototype.expungerHits=5
 if permanent then prototype.deckUid=91 end
 local one,two=A.sameInstance(C,s,prototype),A.sameInstance(C,s,prototype)
 assert(one.uid~=two.uid and one.uid~=prototype.uid and two.uid~=prototype.uid)
 eq(one.uuid,prototype.uuid);eq(two.uuid,prototype.uuid);eq(one.misc,7);eq(two.expungerHits,5)
 eq(one.deckUid,permanent and 91 or nil)
 local equivalent=A.fresh(C,s,'genetic_algorithm',prototype)
 assert(equivalent.uuid~=prototype.uuid and equivalent.uuid==equivalent.uid and equivalent.deckUid==nil)
end
for _,permanent in ipairs({false,true})do
 s=C.new(Data,{deck={},enemies={'jaw_worm','jaw_worm'},seed=1})
 local dagger=A.fresh(C,s,'ritual_dagger');dagger.misc=15
 if permanent then dagger.deckUid=91 end
 local same=A.sameInstance(C,s,dagger)
 local equivalent=A.fresh(C,s,'ritual_dagger',dagger)
 s.hand={dagger};s.draw={same,equivalent};s.enemies[1].hp=1;s.enemies[1].block=0
 assert(C.play(s,dagger.uid,1));eq(dagger.misc,18);eq(same.misc,18);eq(equivalent.misc,15)
 eq((s.ritualDaggerGrowth or {})[91],permanent and 3 or nil)
end
print('AUTO_IDENTITY_PASS fresh physical UID, logical uuid, permanent owner, choice and stat-equivalent isolation')
