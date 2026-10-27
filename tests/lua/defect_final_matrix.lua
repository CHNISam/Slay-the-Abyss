package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,A,P,D=require('abyss_combat'),require('abyss_card_actions'),require('abyss_character_profiles'),require('abyss_data')
local data=P.prepare(D,'defect');local Capability=require('abyss_card_capability')
local text=require('abyss_character_presentation').prepare(require('abyss_presentation'),data)
local cards={};for _,c in ipairs(data.cards.cards)do if c.color=='blue'and (c.type=='skill'or c.type=='attack'or c.type=='power')then cards[#cards+1]=c end end
assert(#cards==75,'full Defect profile must contain exactly 75 playable definitions')
local played=0
for _,def in ipairs(cards)do for _,up in ipairs({false,true})do
 local owner={uid=31,cardId=def.id,upgraded=up}
 local s=C.new(data,{deck={owner},masterDeck={owner},enemies={'jaw_worm','jaw_worm'},seed=42,orbSlots=3,cardRandomSeed='17',shuffleSeed='17'})
 s.combatGeneration=1;local c=s.hand[1];assert(c and c.cardId==def.id)
 s.energy=10;s.orbs.balls={{kind='lightning'},{kind='frost'},{kind='dark',stored=6}}
 s.hand[#s.hand+1]=A.fresh(C,s,'defend_blue');s.hand[#s.hand+1]=A.fresh(C,s,'zap')
 s.draw={A.fresh(C,s,'beam_cell'),A.fresh(C,s,'defend_blue'),A.fresh(C,s,'zap'),A.fresh(C,s,'defend_blue')}
 s.discard={A.fresh(C,s,'beam_cell'),A.fresh(C,s,'defend_blue')}
 local actual=C.cardDefinition(s,c);assert(Capability.isImplemented(actual),def.id..' unsupported '..tostring(up))
 assert(text[def.id]and #text[def.id].text>0 and #text[def.id].upgradeText>0)
 assert(type(C.cardPreview(s,c,1))=='table')
 local ok,why=C.play(s,c.uid,1);assert(ok,def.id..' play failed '..tostring(why))
 local resumes=0
 while s.pendingHandChoice or s.pendingPileChoice or s.pendingChoice or s.pendingDiscard or s.pendingScry do
  resumes=resumes+1;assert(resumes<10,'unbounded choice continuation')
  if s.pendingHandChoice then local p=s.pendingHandChoice;assert(C.chooseHand(s,{p.handUids[1]},p.token))
  elseif s.pendingPileChoice then local p=s.pendingPileChoice;local chosen={};for i=1,p.count do chosen[i]=p.candidateUids[i]end;assert(C.choosePile(s,chosen,p.token,1))
  elseif s.pendingChoice then local p=s.pendingChoice;assert(C.chooseCard(s,p.token,p.uids[1]))
  elseif s.pendingDiscard then local p=s.pendingDiscard;local chosen={};for i=1,p.count do chosen[i]=p.handUids[i]end;assert(C.chooseDiscard(s,chosen,p.token))
  else assert(C.chooseScry(s,{},s.pendingScry.token))end
 end
 assert(not s.actionQueue and not s.cardInUse,def.id..' left unresolved actions')
 local seen={};for _,name in ipairs({'hand','draw','discard','exhaust'})do for _,v in ipairs(s[name])do assert(not seen[v.uid],def.id..' duplicate physical UID');seen[v.uid]=true end end
 played=played+1
end end
assert(played==150);print('DEFECT_FINAL_MATRIX_PASS 75 real definitions x base/upgraded = 150 actual plays with choices, preview, detached Chinese display and UID checks')
