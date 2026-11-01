local H=dofile('tests/lua/support/nemesis_fixture.lua')
local C,R,AI,A,N,Run,Q,eq,same=H.C,H.R,H.AI,H.A,H.N,H.Run,H.Q,H.eq,H.same
local count,failed=0,0
local function test(name,fn)local ok,why=pcall(fn);count=count+1;if not ok then failed=failed+1 end
 print((ok and 'PASS 'or 'FAIL ')..name..(ok and ''or ': '..tostring(why)))end
test('real source queue opens Nemesis as ordinary elite without pool edits',function()
 local r=H.room();local queue=r.encounters;local before=C.copy(r.data)
 assert(Run.startRoomCombat(r,'elite'));eq(r.encounterSource,'Nemesis');eq(r.encounterTier,'elite')
 eq(r.combat.enemies[1].definitionId,'nemesis');eq(r.combat.monsterHpRng.counter,1)
 eq(#r.encounters.elite,9);eq(#queue.elite,10);same(r.data,before)
 local resolve=require('abyss_act3_enemies').resolve
 local e,why=resolve('Nemesis','normal');eq(e,nil);eq(why,'encounter_tier_mismatch')
 e,why=resolve('Reptomancer','elite');assert(e);eq(e.source,'Reptomancer');eq(e.tier,'elite')
 e,why=resolve('Reptomancer','normal');eq(e,nil);eq(why,'encounter_tier_mismatch')
end)
test('Intangible alternates only after payload and lasts through all ally moves until group end',function()
 local s=H.battle('1',{}, {'nemesis','cultist'});local e=H.force(s,'fire')
 eq(e.statuses.nemesis_intangible,nil);assert(C.endTurn(s));eq(e.statuses.nemesis_intangible,1)
 eq(e.nemesisIntangibleJustApplied,false);eq(e.powerScheduleOrder[1].priority,75)
 local hp=e.hp;C.damage(s,s.player,e,45);eq(e.hp,hp-1)
 -- Calling the existing per-owner boundary must not expire monster Intangible.
 A.endTurn(s,e);eq(e.statuses.nemesis_intangible,1)
 assert(C.endTurn(s));eq(e.statuses.nemesis_intangible,nil);eq(#e.powerScheduleOrder,0)
 hp=e.hp;C.damage(s,s.player,e,45);eq(e.hp,hp-45)
 assert(C.endTurn(s));eq(e.statuses.nemesis_intangible,1)
end)
test('Intangible caps before block for normal THORNS HP loss poison and fixed damage but Boot acts later',function()
 local s=H.battle('1',{}, {'nemesis','cultist'});local e=s.enemies[1];local ally=s.enemies[2]
 A.applyPower(s,e,'nemesis_intangible',1,e)
 local hp=e.hp;e.block=2;C.damage(s,s.player,e,45);eq(e.hp,hp);eq(e.block,1)
 A.retaliate(s,s.player,e,50);eq(e.hp,hp);eq(e.block,0)
 A.retaliate(s,s.player,e,50);eq(e.hp,hp-1)
 A.loseHp(s,e,50);eq(e.hp,hp-2)
 C.damage(s,s.player,e,50,true);eq(e.hp,hp-3)
 A.applyPower(s,e,'poison',20,s.player);A.startTurnEffects(s,e);eq(e.hp,hp-4);eq(e.statuses.poison,19)
 local other=ally.hp;C.damage(s,s.player,ally,7);eq(ally.hp,other-7)
 s.relics={'boot'};C.damage(s,s.player,e,9);eq(e.hp,hp-9)
 -- Zero-amount source Power still exists until its explicit owner-end removal.
 e.statuses.nemesis_intangible=0;C.damage(s,s.player,e,9,true);eq(e.hp,hp-10)
 N.ownerEnd(A,s,e);eq(e.statuses.nemesis_intangible,0)
 N.ownerEnd(A,s,e);eq(e.statuses.nemesis_intangible,nil)
end)
test('Burn inserts exactly three distinct unupgraded discard cards with no gameplay RNG or Artifact',function()
 local s=H.battle();local e,fx=H.force(s,'burn');A.applyPower(s,s.player,'artifact',2,s.player)
 local uid=s.nextUid;local a,b,c=s.cardRandomRng.counter,s.aiRng.counter,s.shuffleRng.counter
 C.applyEffects(s,fx,e,s.player);eq(#s.discard,3);eq(#s.draw,0);eq(#s.hand,0);eq(s.nextUid,uid+3)
 for i,card in ipairs(s.discard)do eq(card.uid,uid+i-1);eq(card.cardId,'burn');eq(card.upgraded,false);eq(card.deckUid,nil)end
 assert(s.discard[1]~=s.discard[2]and s.discard[2]~=s.discard[3]);eq(s.player.statuses.artifact,2)
 eq(s.cardRandomRng.counter,a);eq(s.aiRng.counter,b);eq(s.shuffleRng.counter,c)
 eq(s.events[#s.events].detail.amount,3);eq(s.events[#s.events].detail.pile,'discard')
end)
test('real queued Burn draws then burns for six through ordinary source card lifecycle',function()
 local s=H.battle();local e=H.force(s,'burn');assert(C.endTurn(s));eq(#s.hand,3)
 for _,card in ipairs(s.hand)do eq(card.cardId,'burn');eq(card.upgraded,false)end
 H.force(s,'scythe');local hp=s.player.hp;assert(C.endTurn(s));eq(s.player.hp,hp-6-45)
 eq(e.statuses.nemesis_intangible,nil)
end)
test('late Intangible application failure rolls both dispatchers back in place after Burn UID creation',function()
 for _,prepared in ipairs({false,true})do
  local data=prepared and require('abyss_character_profiles').prepare(H.D,'ironclad')or H.D
  local s=H.battle('1',{},nil,data);H.force(s,'burn')
  local before=C.copy(s);local e,hand,discard,rng=s.enemies[1],s.hand,s.discard,s.aiRng
  local original=A.applyPower;local fired=false
  A.applyPower=function(state,actor,id,...)
   local value=original(state,actor,id,...)
   if id=='nemesis_intangible'then fired=true;error('INJECTED_NEMESIS_POWER')end
   return value
  end
  local ok,why=pcall(C.endTurn,s);A.applyPower=original
  assert(not ok and fired and tostring(why):find('INJECTED_NEMESIS_POWER',1,true));same(s,before)
  eq(s.enemies[1],e);eq(s.hand,hand);eq(s.discard,discard);eq(s.aiRng,rng)
 end
end)
test('late conditional Boolean failure restores piles HP Intangible and full original RNG identity',function()
 local s=H.battle();local e=H.force(s,'burn');e.nemesisLast='scythe';e.nemesisCooldown=2
 local before=C.copy(s);local rng,discard=s.aiRng,s.discard;local original=R.randomBoolean;local fired=false
 R.randomBoolean=function(stream,...)
  local value=original(stream,...)
  if stream==rng then fired=true;error('INJECTED_NEMESIS_BOOLEAN')end
  return value
 end
 local ok,why=pcall(C.endTurn,s);R.randomBoolean=original
 assert(not ok and fired and tostring(why):find('INJECTED_NEMESIS_BOOLEAN',1,true))
 same(s,before);eq(s.enemies[1],e);eq(s.aiRng,rng);eq(s.discard,discard)
end)
test('invalid Burn UIDs and late room setup refuse atomically without source queue publication',function()
 local s=H.battle();H.force(s,'burn');s.nextUid=9007199254740992
 local before=C.copy(s);assert(not pcall(C.endTurn,s));same(s,before)
 local r=H.room();before=C.copy(r);local q,misc=r.encounters,r.miscRng;local original=C.new
 C.new=function(data,options)original(data,options);error('INJECTED_NEMESIS_ROOM')end
 local ok,result,why=pcall(Run.startRoomCombat,r,'elite');C.new=original
 assert(ok);eq(result,false);eq(why,'combat_unavailable');same(r,before);eq(r.encounters,q);eq(r.miscRng,misc)
end)
test('controlled elite victory uses existing source reward channels once without auto-claiming',function()
 local r=H.room();assert(Run.startRoomCombat(r,'elite'))
 local s=r.combat;C.damage(s,s.player,s.enemies[1],185,true);eq(C.outcome(s),'victory')
 assert(Run.finishCombat(r));eq(r.phase,'reward');eq(r.victories,1)
 assert(r.rewards.gold>=25 and r.rewards.gold<=35);eq(r.rewards.goldClaimed,false)
 eq(#r.rewards.relics,1);assert(not r.rewards.relics[1].claimed);eq(#r.rewards.cards,3)
 local before=C.copy(r);local ok,why=Run.finishCombat(r);eq(ok,false);eq(why,'not_in_combat');same(r,before)
end)
print('NEMESIS_RUNTIME '..count..' groups; '..failed..' failed');assert(failed==0)
