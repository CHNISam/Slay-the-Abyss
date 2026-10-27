package.path='src/lua/?.lua;build/lua/?.lua;tests/lua/helpers/?.lua;'..package.path
local H=require('run_catalog');local Run,C=H.Run,H.C
do
 local r,s=H.new({'master_reality','blade_dance','alpha','white_noise'})
 H.play(r,'master_reality');H.play(r,'blade_dance')
 for _,c in ipairs(s.hand)do if c.cardId=='shiv'then assert(c.upgraded and not c.deckUid)end end
 H.play(r,'alpha');assert(s.draw[1].cardId=='beta'and s.draw[1].upgraded and not s.draw[1].deckUid)
 local counter=s.cardRandomRng.counter;H.play(r,'white_noise')
 local generated=s.hand[#s.hand];assert(s.catalog.cards[generated.cardId].type=='power'and generated.upgraded and generated.costForTurn==0 and not generated.deckUid)
 assert(s.cardRandomRng.counter>counter,'foreign generation must consume its actual source RNG')
end
do
 local r,s=H.new({'vigilance','empty_fist','capacitor','zap'})
 H.play(r,'vigilance');assert(s.player.stance=='Calm'and s.energy==18)
 H.play(r,'empty_fist',1);assert(s.player.stance=='Neutral'and s.energy==19,'foreign Calm exit grants source2 energy')
 H.play(r,'capacitor');assert(s.orbs.slots==2 and #s.orbs.balls==0)
 H.play(r,'zap');assert(s.orbs.slots==2 and #s.orbs.balls==1 and s.orbs.balls[1].kind=='lightning')
end
local function freeze(root)
 local saved,work={}, {root}
 while #work>0 do local t=table.remove(work);if not saved[t]then
  local entries={};saved[t]=entries
  for k,v in pairs(t)do entries[k]=v;if type(v)=='table'then work[#work+1]=v end end
 end end
 return function()for t,entries in pairs(saved)do
  for k,v in pairs(entries)do assert(t[k]==v,'rollback changed '..tostring(k))end
  for k,v in pairs(t)do assert(entries[k]==v,'rollback added '..tostring(k))end
 end end
end
do
 local r,s=H.new({'master_reality','white_noise'},'silent');H.play(r,'master_reality')
 local held=H.held(s,'white_noise');local unchanged=freeze(r)
 local original=C.upgrade;local sentinel={}
 C.upgrade=function(...)original(...);error(sentinel,0)end
 local ok,err=pcall(Run.play,r,held.uid);C.upgrade=original
 assert(not ok and err==sentinel,'actual generated-card upgrade error must propagate')
 unchanged()
 assert(Run.play(r,held.uid),'the restored command must still succeed')
 assert(s.hand[1].upgraded and s.hand[1].costForTurn==0)
end
print('RUN_CARD_CATALOG_CREATION_PASS actual cross-color MR hand/draw generation, zero-slot acquisition, Calm exit and full owner/RNG/UID rollback')
