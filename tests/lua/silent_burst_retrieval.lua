package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C=require('abyss_combat');local P=require('abyss_character_profiles')
local data=require('abyss_retrieval_cards').withCards(P.prepare(require('abyss_data'),'silent'),'defect')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
for _,up in ipairs({false,true})do
 local s=C.new(data,{deck={'burst','hologram','defend_green','strike_green','slice','deflect'},enemies={'jaw_worm'},seed=42,experimental=true,enableStances=true})
 local all={};for _,pile in ipairs({'hand','draw','discard','exhaust'})do for _,c in ipairs(s[pile])do all[#all+1]=c end;s[pile]={}end
 local burst,hologram
 for _,c in ipairs(all)do
  if c.cardId=='burst'then burst=c;s.hand[#s.hand+1]=c
  elseif c.cardId=='hologram'then hologram=c;c.upgraded=up;c.deckUid=77;s.hand[#s.hand+1]=c
  else s.discard[#s.discard+1]=c end
 end
 s.energy=2;s.enemies[1].hp=300;s.enemies[1].maxHp=300
 assert(C.play(s,burst.uid));local nextUid=s.nextUid
 assert(C.play(s,hologram.uid));eq(s.energy,0)
 for pass=1,2 do
  local choice=assert(s.pendingPileChoice,'missing real Hologram selection '..pass)
  local physical=s.cardInUse.uid
  if pass==1 then eq(physical,hologram.uid)
  else assert(physical~=hologram.uid);eq(s.cardInUse.uuid,hologram.uuid or hologram.uid);eq(s.cardInUse.deckUid,77)end
  assert(C.choosePile(s,{choice.candidateUids[1]},choice.token,choice.generation))
 end
 eq(s.energy,0);eq(s.player.block,up and 10 or 6);eq(s.nextUid,nextUid+1)
 eq(s.pendingPlay,nil);eq(s.actionQueue,nil);eq(s.pendingPileChoice,nil);eq(s.cardActions,nil)
 local seen,physicalCopies={},0
 for _,pile in ipairs({'hand','draw','discard','exhaust'})do for _,c in ipairs(s[pile])do
  assert(not seen[c.uid],'duplicate physical UID');seen[c.uid]=true
  if c.cardId=='hologram'then physicalCopies=physicalCopies+1;eq(c.uid,hologram.uid);eq(c.deckUid,77)end
 end end
 eq(physicalCopies,1);eq(#s.exhaust,up and 0 or 1)
 print('ok Burst Hologram '..(up and 'upgraded' or 'basic')..' two real choices, unique physical UID, shared UUID/owner, one payment and purge disposal')
end
