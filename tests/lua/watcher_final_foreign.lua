package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,P,D,R,Run=require('abyss_combat'),require('abyss_character_profiles'),require('abyss_data'),require('abyss_sts_random'),require('abyss_run')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function combined()
 local d=P.prepare(D,'watcher');local cards,statuses={},{}
 for _,c in ipairs(d.cards.cards)do cards[c.id]=true end;for _,s in ipairs(d.statuses.statuses)do statuses[s.id]=true end
 for _,other in ipairs({D,(P.prepare(D,'silent')),(P.prepare(D,'defect'))})do
  for _,c in ipairs(other.cards.cards)do if not cards[c.id]then d.cards.cards[#d.cards.cards+1]=C.copy(c);cards[c.id]=true end end
  for _,s in ipairs(other.statuses.statuses)do if not statuses[s.id]then d.statuses.statuses[#d.statuses.statuses+1]=C.copy(s);statuses[s.id]=true end end
 end
 return d
end
for _,up in ipairs({false,true})do
 local s=C.new(combined(),{seed=1,cardRandomSeed='1',cardSeed='1',shuffleSeed='1',enableStances=true,deck={{cardId='foreign_influence',upgraded=up}},enemies={'cultist'}})
 local before=s.nextUid;assert(C.play(s,s.hand[1].uid));local p=assert(s.pendingChoice)
 -- Independent Python64 oracle supplied from fixed source, not this helper.
 local expected={'melter','immolate','compile_driver'}
 for i,id in ipairs(expected)do eq(p.cards[i].cardId,id)end
 eq(R.snapshot(s.cardRandomRng).counter,6);eq(R.snapshot(s.cardRng).counter,3)
 assert(C.chooseCard(s,p.token,1));eq(s.hand[1].cardId,'melter');eq(s.hand[1].uid,before);eq(s.hand[1].deckUid,nil)
 eq(C.cardDefinition(s,s.hand[1]).cost,up and 0 or 1)
 -- Foreign retrieval does not regenerate Discovery's unused second group.
 eq(R.snapshot(s.cardRandomRng).counter,6);eq(R.snapshot(s.cardRng).counter,3)
end
local missing=C.new(P.prepare(D,'watcher'),{seed=1,cardRandomSeed='1',cardSeed='1',shuffleSeed='1',enableStances=true,deck={'foreign_influence'},enemies={'cultist'}})
local original=missing.hand[1];local energy,nextUid=missing.energy,missing.nextUid
local ok,why=pcall(C.play,missing,original.uid);eq(ok,false);assert(tostring(why):find('missing Foreign Influence definition: Melter',1,true))
eq(missing.hand[1],original);eq(missing.energy,energy);eq(missing.nextUid,nextUid);eq(R.snapshot(missing.cardRandomRng).counter,0);eq(R.snapshot(missing.cardRng).counter,0)
local r=Run.new(D,1);r.deck={{uid=31,cardId='defend'}};r.relics={};assert(Run.startCombat(r,'cultist_solo'))
local old=r.cardRng.counter;R.randomInt(r.combat.cardRng,0);assert(not Run.play(r,999));eq(r.cardRng.counter,old)
assert(Run.play(r,r.combat.hand[1].uid));eq(r.cardRng.counter,old+1);assert(r.cardRng~=r.combat.cardRng)
print('WATCHER_FINAL_FOREIGN fixed independent choices/counters, two versions, missing-definition rollback and persistent boundary passed')
