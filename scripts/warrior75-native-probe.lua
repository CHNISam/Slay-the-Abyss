-- TEST CANDIDATE ONLY. Explicit inventory/navigation fixtures. Never install in
-- the production manifest or count these as natural acquisition / a normal run.
local R,M,N,C=require('abyss_run'),require('abyss_map'),require('abyss_nodes'),require('abyss_combat')
local data=require('abyss_data')
local P={}
local step,fixture=0,nil
local checks,channelCards,channelIndex
local function attach(view,run,map)
 view.run,view.map=run,map
 view.battleUI.run=run;view.mapUI.map=map;view.nodeUI.run,view.nodeUI.map=run,map
 view.prologueSeen=true;view:refresh()
end
function P.start(view)
 checks=require('abyss_warrior75_checks');checks.core()
 channelCards={};channelIndex=1
 for _,c in ipairs(data.cards.cards)do if c.type~='status'and c.type~='curse'then channelCards[#channelCards+1]=c end end
 assert(#channelCards==75)
end
function P.tick(view)
 if step==0 then
  local c=channelCards[channelIndex]
  if c then
   checks.channel(c.id,c.rarity=='basic'and'common'or c.rarity)
   channelIndex=channelIndex+1;return
  end
  print('ABYSS_W75_NATIVE_CHANNELS all75 acquisition/camp/next-battle fixtures passed; navigation/funding are explicit')
 local run,map=R.new(data,42),M.generate(data,42)
 run.phase='reward';run.rewards={gold=0,goldClaimed=true,manualContinue=true,cardResolved=false,
  cards={'perfected_strike','wild_strike','pommel_strike'}}
 attach(view,run,map);fixture=run;step=1
 print('ABYSS_W75_FIXTURE reward: explicit cards, not natural acquisition')
 end
 if step==1 and view.battleUI.rewardScreen=='cards' and not P.printedTitles then
  P.printedTitles=true
  for i=1,3 do
   local title=view.root:GetChild('battlePanel'):GetChild('card'..i):GetChild('name')
   print('ABYSS_W75_TEXT_DIAG slot='..i..' text='..title.text:gsub('\n','<NL>')..' font='..tostring(title.fontSize))
  end
 end
 if step==1 and fixture.phase=='map'then
  local run,map=R.new(data,42),M.generate(data,42)
  run.deck={{uid=1,cardId='searing_blow',upgraded=true,upgrades=2}};run.nextDeckUid=2
  while not run.nodeFlow do
   local choices=M.available(map);local entered=false
   for _,node in ipairs(choices)do if node.type=='camp'then assert(N.enter(run,map,node.id));entered=true;break end end
   if not entered then assert(M.choose(map,choices[1].id))end
  end
  attach(view,run,map);fixture=run;step=2
  print('ABYSS_W75_FIXTURE camp: explicit Searing Blow+2, expect 21 -> 27')
 elseif step==2 and fixture.phase=='map'then
  assert(fixture.deck[1].upgrades==3,'Searing Blow fixture must actually upgrade before continuing')
  print('ABYSS_W75_NATIVE_UI searing_blow+3 permanent upgrade committed')
  local run,map=R.new(data,42),M.generate(data,42);assert(R.startCombat(run,'cultist_solo'))
  local s=run.combat;s.hand={{uid=101,cardId='burning_pact'},{uid=102,cardId='sentinel',upgraded=true},{uid=103,cardId='defend'}}
  s.draw={};for i=104,111 do s.draw[#s.draw+1]={uid=i,cardId='strike'}end
  s.discard={};s.exhaust={};s.nextUid=112;s.events={}
  C.addStatus(s.player,'corruption',1);C.addStatus(s.player,'dark_embrace',1);C.addStatus(s.player,'feel_no_pain',4)
  attach(view,run,map);fixture=run;step=3
  print('ABYSS_W75_FIXTURE combat: play Burning Pact, choose Sentinel+; explicit hand/powers')
 elseif step==3 and #fixture.combat.exhaust==2 and not fixture.combat.pendingChoice then
  local s=fixture.combat
  assert(s.energy==6 and s.player.block==8 and #s.hand==5,'native exhaust/energy/draw/block order mismatch')
  assert(s.exhaust[1].uid==102 and s.exhaust[2].uid==101,'native exhaust UID order mismatch')
  step=4;print('ABYSS_W75_NATIVE_UI exhaust choice passed: Sentinel+ then Pact, energy6 block8 hand5')
 elseif step==4 and fixture.combat.turn>1 then
  local run,map=R.new(data,42),M.generate(data,42);assert(R.startCombat(run,'cultist_solo'))
  local s=run.combat
  s.hand={{uid=201,cardId='dual_wield',upgraded=true},{uid=202,cardId='rampage',upgraded=true,damageBonus=8,costForTurn=0},{uid=203,cardId='defend'},{uid=204,cardId='anger'}}
  s.draw={};s.discard={};s.exhaust={};s.nextUid=205;s.events={}
  attach(view,run,map);fixture=run;step=5
  print('ABYSS_W75_FIXTURE copy: play Dual Wield+, choose modified Rampage+; explicit hand')
 elseif step==5 and #fixture.combat.hand==5 and not fixture.combat.pendingChoice then
  local s=fixture.combat;assert(s.energy==2 and #s.discard==1,'native copy payment/disposal mismatch')
  assert(s.hand[1].uid==204 and s.hand[2].uid==203,'native selected-copy return order mismatch')
  for i=3,5 do
   local c=s.hand[i];assert(c.uid~=202 and c.cardId=='rampage' and c.upgraded and c.damageBonus==8 and c.costForTurn==0,'native selected-copy stat/identity mismatch')
  end
  step=6;print('ABYSS_W75_NATIVE_UI selected copy passed: three fresh Rampage+ cost0 damage16, original UID202 removed')
 end
end
return P
