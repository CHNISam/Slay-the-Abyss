package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,P,D,A,R,Capability=require('abyss_combat'),require('abyss_character_profiles'),require('abyss_data'),require('abyss_card_actions'),require('abyss_sts_random'),require('abyss_card_capability')
local data=P.prepare(D,'watcher');local normal,seen,statuses={},{},{}
for _,c in ipairs(data.cards.cards)do
 seen[c.id]=true
 if c.color=='purple' and (c.rarity=='basic' or c.rarity=='common' or c.rarity=='uncommon' or c.rarity=='rare')then normal[#normal+1]=c end
end
for _,s in ipairs(data.statuses.statuses)do statuses[s.id]=true end
assert(#normal==75,'Watcher source normal-card count must be75, got '..#normal)
for _,other in ipairs({D,(P.prepare(D,'silent')),(P.prepare(D,'defect'))})do
 for _,c in ipairs(other.cards.cards)do if not seen[c.id]then data.cards.cards[#data.cards.cards+1]=C.copy(c);seen[c.id]=true end end
 for _,s in ipairs(other.statuses.statuses)do if not statuses[s.id]then data.statuses.statuses[#data.statuses.statuses+1]=C.copy(s);statuses[s.id]=true end end
end
table.sort(normal,function(a,b)return a.id<b.id end)
local function resolve(s)
 for _=1,20 do
  if s.pendingPileChoice then local p=s.pendingPileChoice;local ids={};for i=1,p.count do ids[i]=p.candidateUids[i]end;assert(C.choosePile(s,ids,p.token,p.generation))
  elseif s.pendingScry then assert(C.chooseScry(s,{},s.pendingScry.token))
  elseif s.pendingHandChoice then local p=s.pendingHandChoice;assert(C.chooseHand(s,{p.handUids[1]},p.token))
  elseif s.pendingChoice then assert(C.chooseCard(s,s.pendingChoice.token,s.pendingChoice.uids[1]))
  elseif s.pendingDiscard then local p=s.pendingDiscard;local ids={};for i=1,p.count do ids[i]=p.handUids[i]end;assert(C.chooseDiscard(s,ids,p.token))
  else return end
 end
 error('selection did not settle')
end
local count=0
for _,card in ipairs(normal)do for _,up in ipairs({false,true})do
 local ok,why=pcall(function()
  assert(Capability.isImplemented(card),'card is not implemented')
  local s=C.new(data,{seed=1,cardRandomSeed='1',cardSeed='1',shuffleSeed='1',miscRng=R.fromSeed('1'),enableStances=true,
   masterDeck={{uid=71,cardId='empty_fist',upgraded=false}},deck={{cardId=card.id,upgraded=up}},enemies={'cultist'}})
  s.enemies[1].hp=10000;s.enemies[1].maxHp=10000;s.enemies[1].ai=nil;s.enemies[1].intents={{id='wait',effects={}}};s.enemies[1].intentIndex=1;s.energy=20
  if card.id=='deus_ex_machina' then
   assert(#s.exhaust==1 and #s.hand==(up and 3 or 2),'true drawn Deus lifecycle missing')
  else
   local instance=s.hand[1]
   for _=1,2 do s.hand[#s.hand+1]=A.fresh(C,s,card.id=='signature_move' and 'empty_body' or 'empty_fist')end
   for _=1,3 do s.draw[#s.draw+1]=A.fresh(C,s,'empty_body')end
   for _=1,2 do s.discard[#s.discard+1]=A.fresh(C,s,'empty_fist')end
   if card.id=='judgment' or card.id=='lesson_learned' then s.enemies[1].hp=9 end
   local accepted,reason=C.play(s,instance.uid,1);assert(accepted,reason);resolve(s)
   assert(not s.pendingPlay and not s.actionQueue,'card continuation did not complete')
   if card.id=='lesson_learned'then assert(s.masterDeckChanges[71].upgraded,'missing real permanent upgrade')end
  end
 end)
 assert(ok,card.id..(up and '+' or '')..': '..tostring(why));count=count+1
end end
assert(count==150)
print('WATCHER_FINAL_75_MATRIX_PASS 75 genuine cards x basic/upgraded =150 real executions; merged catalog component evidence only')
