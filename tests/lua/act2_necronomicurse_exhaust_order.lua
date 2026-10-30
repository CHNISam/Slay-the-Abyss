-- CardGroup.moveToExhaustPile source319009d5: relics -> Powers -> card.
local H=dofile('tests/helpers/act2_event_relics.lua')
for _,queued in ipairs({false,true})do
 local r,s=H.battle({'Necronomicon','Dead Branch'},{'true_grit'})
 if queued then H.C.applyEffects(s,{{op='gainExhaustPower',status='feel_no_pain',value=3},{op='gainExhaustPower',status='dark_embrace',value=1}},s.player,s.player)end
 local nextUid=s.nextUid
 assert(H.play(r,'true_grit'))
 local branch,curse
 for _,c in ipairs(s.hand)do
  if c.uid==nextUid then branch=c end
  if c.uid==nextUid+1 then curse=c end
 end
 assert(branch and branch.cardId~='necronomicurse','Dead Branch must create before card exhaust hook')
 assert(curse and curse.cardId=='necronomicurse','Necronomicurse must be created after relic and Power hooks')
 H.eq(s.nextUid,nextUid+2)
 H.eq(s.player.block,queued and 10 or 7)
end
-- Native CardActions owner independently, without queued TrueGrit dispatch.
do
 local r,s=H.battle({'Necronomicon','Dead Branch'},{'true_grit'})
 local actions=require('abyss_card_actions');local uid=s.nextUid
 assert(actions.exhaust(H.C,s,H.card(r,'necronomicurse'),s.hand))
 actions.drain(H.C,s)
 local first,second
 for _,c in ipairs(s.hand)do if c.uid==uid then first=c elseif c.uid==uid+1 then second=c end end
 assert(first and first.cardId~='necronomicurse','native Dead Branch must create before card exhaust hook')
 assert(second and second.cardId=='necronomicurse','native Necronomicurse must follow relic hooks')
end
print('ACT2_NECRONOMICURSE_EXHAUST_ORDER 3 passed')
